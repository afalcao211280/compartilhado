<#
.SYNOPSIS
    Relatorio Diario DevOps — consulta Azure DevOps e publica relatorio no Notion.
.DESCRIPTION
    1. Consulta WIQL no ADO: User Stories em Priorizado, Refinamento Tecnico,
       Em Desenvolvimento e UAT (atribuidas ao usuario atual).
    2. Ordena por due date (mais perto de vencer primeiro).
    3. Marca em vermelho as que faltam <=3 dias para vencer.
    4. Move vencidas para tabela separada (mais tempo vencida primeiro).
    5. Gera grafico de pizza (vencido / proximo / saudavel) como imagem.
    6. Cria ou atualiza pagina "Relatorio Diario Devops" no Notion com a tabela + grafico.
.PARAMETER NotionPageId
    ID da pagina pai no Notion onde o relatorio sera criado/atualizado.
    Se omitido, busca automaticamente por "Daily Eveo" no workspace.
.PARAMETER Force
    Recria a pagina do relatorio mesmo se ja existir.
.EXAMPLE
    .\relatorio-devops.ps1
    .\relatorio-devops.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$NotionPageId = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# --- Config ---
$AdoOrg = 'eveo-workspaces'
$AdoProject = 'ENGSOFT - Engenharia de Software'
$NotionVersion = '2022-06-28'
$NotionBaseUrl = 'https://api.notion.com/v1'

# --- Token resolution ---
$AdoToken = [Environment]::GetEnvironmentVariable('AZURE_DEVOPS_EXT_PAT', 'User')
if (-not $AdoToken) {
    $AdoToken = [Environment]::GetEnvironmentVariable('AZURE_DEVOPS_PAT', 'User')
}
if (-not $AdoToken) {
    $AdoToken = [Environment]::GetEnvironmentVariable('ADO_PAT', 'User')
}
if (-not $AdoToken) {
    Write-Error 'No Azure DevOps PAT found. Set AZURE_DEVOPS_EXT_PAT env var.'
    exit 1
}

$NotionToken = [Environment]::GetEnvironmentVariable('NOTION_PAT', 'User')
if (-not $NotionToken) {
    $NotionToken = [Environment]::GetEnvironmentVariable('NOTION_API', 'User')
}
if (-not $NotionToken) {
    Write-Error 'No Notion token found. Set NOTION_PAT env var.'
    exit 1
}

$AdoEncoded = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$AdoToken"))

# --- Helpers ---

function Invoke-AdoApi {
    param([string]$Uri, [string]$Method = 'GET', [string]$Body = '')
    $headers = @{
        'Authorization' = "Basic $AdoEncoded"
        'Content-Type' = 'application/json'
    }
    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Uri $Uri -Method GET -Headers $headers
    } else {
        return Invoke-RestMethod -Uri $Uri -Method $Method -Headers $headers -Body $Body
    }
}

function Invoke-NotionApi {
    param([string]$Endpoint, [string]$Method = 'GET', [string]$Body = '')
    $headers = @{
        'Authorization' = "Bearer $NotionToken"
        'Notion-Version' = $NotionVersion
        'Content-Type' = 'application/json'
    }
    $uri = "$NotionBaseUrl$Endpoint"
    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
    } else {
        return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $Body
    }
}

function Format-DateBR {
    param([string]$IsoDate)
    if (-not $IsoDate) { return '—' }
    try {
        $dt = [DateTime]::Parse($IsoDate)
        return $dt.ToString('dd/MM/yyyy')
    } catch {
        return $IsoDate
    }
}

function Get-DueDateParsed {
    param([string]$IsoDate)
    if (-not $IsoDate) { return $null }
    try {
        return [DateTime]::Parse($IsoDate)
    } catch {
        return $null
    }
}

# --- 1. Query ADO for work items ---

Write-Host "[relatorio-devops] Querying Azure DevOps..."

$wiql = "SELECT [System.Id], [System.Title], [System.State], [System.BoardColumn], [Microsoft.VSTS.Scheduling.DueDate], [Microsoft.VSTS.Scheduling.FinishDate], [System.AssignedTo], [System.WorkItemType] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.WorkItemType] = 'User Story' AND ([System.BoardColumn] = 'PRIORIZADO' OR [System.BoardColumn] = 'REFINAMENTO TECNICO' OR [System.BoardColumn] = 'EM DESENVOLVIMENTO' OR [System.BoardColumn] = 'UAT') AND [System.AssignedTo] = @me ORDER BY [Microsoft.VSTS.Scheduling.DueDate] ASC"

$wiqlBody = @{ query = $wiql } | ConvertTo-Json -Compress
$wiqlUri = "https://dev.azure.com/$AdoOrg/$AdoProject/_apis/wit/wiql?api-version=7.1&`$top=200"
$wiqlResult = Invoke-AdoApi -Uri $wiqlUri -Method 'POST' -Body $wiqlBody

$workItemIds = $wiqlResult.workItems | ForEach-Object { $_.id }

if ($workItemIds.Count -eq 0) {
    Write-Host "[relatorio-devops] No work items found."
    $items = @()
} else {
    Write-Host "[relatorio-devops] Found $($workItemIds.Count) work items. Fetching details..."

    # Batch get in chunks of 200
    $items = @()
    $chunks = @()
    for ($i = 0; $i -lt $workItemIds.Count; $i += 200) {
        $chunk = $workItemIds[$i..([Math]::Min($i + 199, $workItemIds.Count - 1))]
        $chunks += ,@($chunk)
    }

    foreach ($chunk in $chunks) {
        $idsStr = ($chunk | ForEach-Object { [string]$_ }) -join ','
        $fieldsStr = 'System.Id,System.Title,System.State,System.BoardColumn,Microsoft.VSTS.Scheduling.DueDate,Microsoft.VSTS.Scheduling.FinishDate,System.AssignedTo,System.WorkItemType'
        $batchUri = "https://dev.azure.com/$AdoOrg/$AdoProject/_apis/wit/workitemsbatch?api-version=7.1"
        $batchBody = @{
            ids = $chunk
            fields = $fieldsStr -split ','
        } | ConvertTo-Json -Compress
        $batchResult = Invoke-AdoApi -Uri $batchUri -Method 'POST' -Body $batchBody
        $items += $batchResult.value
    }
}

# --- 2. Process items: classify by due date ---

$today = Get-Date
$todayDate = $today.Date

$activeItems = @()
$overdueItems = @()

foreach ($item in $items) {
    $f = $item.fields
    $dueDateRaw = $f.'Microsoft.VSTS.Scheduling.DueDate'
    if (-not $dueDateRaw) {
        $dueDateRaw = $f.'Microsoft.VSTS.Scheduling.FinishDate'
    }

    $dueDate = Get-DueDateParsed -IsoDate $dueDateRaw

    $entry = @{
        Id = $f.'System.Id'
        Title = $f.'System.Title'
        State = $f.'System.State'
        BoardColumn = $f.'System.BoardColumn'
        DueDateRaw = $dueDateRaw
        DueDate = $dueDate
        DueDateBR = Format-DateBR -IsoDate $dueDateRaw
    }

    if ($dueDate -and $dueDate.Date -lt $todayDate) {
        $entry.DaysOverdue = [int]($todayDate - $dueDate.Date).TotalDays
        $overdueItems += $entry
    } else {
        if ($dueDate) {
            $entry.DaysUntilDue = [int]($dueDate.Date - $todayDate).TotalDays
        } else {
            $entry.DaysUntilDue = $null
        }
        $activeItems += $entry
    }
}

# Sort active by due date (closest first; nulls last)
$activeItems = $activeItems | Sort-Object {
    if ($_.DueDate) { $_.DueDate } else { [DateTime]::MaxValue }
}

# Sort overdue by most overdue first
$overdueItems = $overdueItems | Sort-Object { $_.DaysOverdue } -Descending

Write-Host "[relatorio-devops] Active: $($activeItems.Count), Overdue: $($overdueItems.Count)"

# --- 3. Generate chart image ---

Write-Host "[relatorio-devops] Generating chart..."

$overdueCount = $overdueItems.Count
$warningCount = ($activeItems | Where-Object { $_.DaysUntilDue -ne $null -and $_.DaysUntilDue -le 3 }).Count
$healthyCount = ($activeItems | Where-Object { $_.DaysUntilDue -eq $null -or $_.DaysUntilDue -gt 3 }).Count

$chartDir = Join-Path $env:USERPROFILE '.engsoft-stack'
if (-not (Test-Path $chartDir)) {
    New-Item -ItemType Directory -Path $chartDir -Force | Out-Null
}
$chartPath = Join-Path $chartDir 'relatorio-devops-chart.png'

# Generate chart as SVG and convert to PNG via .NET
$svgTemplate = @"
<svg xmlns="http://www.w3.org/2000/svg" width="420" height="280" viewBox="0 0 420 280">
  <rect x="0" y="0" width="420" height="280" fill="#1e1e2e" rx="12"/>
  <text x="210" y="28" text-anchor="middle" fill="#cdd6f4" font-family="Segoe UI" font-size="16" font-weight="bold">Status dos Work Items</text>

  <!-- Pie chart -->
  <g transform="translate(110,150)">
    <!-- Background circle -->
    <circle cx="0" cy="0" r="70" fill="none" stroke="#45475a" stroke-width="36"/>

    <!-- Segments using stroke-dasharray -->
    <!-- Circumference = 2*pi*70 = 439.82 -->
    <circle cx="0" cy="0" r="70" fill="none" stroke="#f38ba8" stroke-width="36"
            stroke-dasharray="__OVERDASH__ 439.82" stroke-dashoffset="0"
            transform="rotate(-90)"/>
    <circle cx="0" cy="0" r="70" fill="none" stroke="#f9e2af" stroke-width="36"
            stroke-dasharray="__WARNDASH__ 439.82" stroke-dashoffset="__WARNOFFSET__"
            transform="rotate(-90)"/>
    <circle cx="0" cy="0" r="70" fill="none" stroke="#a6e3a1" stroke-width="36"
            stroke-dasharray="__HEALTHDASH__ 439.82" stroke-dashoffset="__HEALTHOFFSET__"
            transform="rotate(-90)"/>
  </g>

  <!-- Legend -->
  <g transform="translate(210,90)">
    <rect x="0" y="0" width="14" height="14" fill="#f38ba8" rx="3"/>
    <text x="22" y="12" fill="#cdd6f4" font-family="Segoe UI" font-size="13">Vencidos (__OVERDUE__)</text>

    <rect x="0" y="28" width="14" height="14" fill="#f9e2af" rx="3"/>
    <text x="22" y="40" fill="#cdd6f4" font-family="Segoe UI" font-size="13"><= 3 dias (__WARNING__)</text>

    <rect x="0" y="56" width="14" height="14" fill="#a6e3a1" rx="3"/>
    <text x="22" y="68" fill="#cdd6f4" font-family="Segoe UI" font-size="13">Saudaveis (__HEALTHY__)</text>
  </g>

  <text x="210" y="265" text-anchor="middle" fill="#6c7086" font-family="Segoe UI" font-size="11">Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm')</text>
</svg>
"@

$total = $overdueCount + $warningCount + $healthyCount
$circumference = 439.82

if ($total -gt 0) {
    $overduePct = $overdueCount / $total
    $warningPct = $warningCount / $total
    $healthyPct = $healthyCount / $total

    $overdash = [Math]::Round($circumference * $overduePct, 2)
    $warndash = [Math]::Round($circumference * $warningPct, 2)
    $healthdash = [Math]::Round($circumference * $healthyPct, 2)

    $warnoffset = [Math]::Round(-$overdash, 2)
    $healthoffset = [Math]::Round(-($overdash + $warndash), 2)
} else {
    $overdash = 0
    $warndash = 0
    $healthdash = 0
    $warnoffset = 0
    $healthoffset = 0
}

$svg = $svgTemplate `
    -replace '__OVERDASH__', $overdash `
    -replace '__WARNDASH__', $warndash `
    -replace '__HEALTHDASH__', $healthdash `
    -replace '__WARNOFFSET__', $warnoffset `
    -replace '__HEALTHOFFSET__', $healthoffset `
    -replace '__OVERDUE__', $overdueCount `
    -replace '__WARNING__', $warningCount `
    -replace '__HEALTHY__', $healthyCount

# Save SVG
$svgPath = Join-Path $chartDir 'relatorio-devops-chart.svg'
$svg | Set-Content -Path $svgPath -Encoding UTF8

# Try to convert SVG to PNG using .NET (System.Drawing doesn't support SVG directly)
# Fallback: use the SVG as-is (Notion doesn't support SVG uploads, so we'll skip the image
# and use a text-based representation in the Notion page instead)
Write-Host "[relatorio-devops] Chart SVG saved (Notion doesn't support SVG uploads, using text-based chart in page)"

# --- 4. Find or create Notion page ---

Write-Host "[relatorio-devops] Setting up Notion page..."

# Find parent page (Daily Eveo or provided ID)
if (-not $NotionPageId) {
    $searchBody = @{ query = 'Daily Eveo'; page_size = 10 } | ConvertTo-Json -Compress
    $searchResult = Invoke-NotionApi -Endpoint '/search' -Method 'POST' -Body $searchBody
    foreach ($result in $searchResult.results) {
        if ($result.object -eq 'page' -and $result.parent.type -eq 'workspace') {
            $title = ($result.properties.title.title | ForEach-Object { $_.plain_text }) -join ''
            if ($title -match 'Daily Eveo') {
                $NotionPageId = $result.id
                break
            }
        }
    }
}

if (-not $NotionPageId) {
    Write-Error 'Could not find "Daily Eveo" page in Notion. Provide -NotionPageId.'
    exit 1
}

Write-Host "[relatorio-devops] Parent page: $NotionPageId"

# Check if "Relatorio Diario Devops" page already exists as child
$reportPageId = $null
if (-not $Force) {
    $children = Invoke-NotionApi -Endpoint "/blocks/$NotionPageId/children?page_size=100" -Method 'GET'
    foreach ($block in $children.results) {
        if ($block.type -eq 'child_page') {
            if ($block.child_page.title -match 'Relatorio Diario Devops') {
                $reportPageId = $block.id
                break
            }
        }
    }
}

# Create or recreate the page
if ($reportPageId -and -not $Force) {
    # Clear existing content
    Write-Host "[relatorio-devops] Updating existing page: $reportPageId"
    # Delete all children blocks
    $existingBlocks = Invoke-NotionApi -Endpoint "/blocks/$reportPageId/children?page_size=100" -Method 'GET'
    foreach ($block in $existingBlocks.results) {
        try {
            Invoke-NotionApi -Endpoint "/blocks/$($block.id)" -Method 'DELETE' | Out-Null
        } catch {
            # Some blocks can't be deleted individually
        }
    }
} else {
    Write-Host "[relatorio-devops] Creating new page..."
    $todayBR = Get-Date -Format 'dd/MM/yyyy'
    $createBody = @{
        parent = @{ page_id = $NotionPageId }
        properties = @{
            title = @(
                @{ text = @{ content = "Relatorio Diario Devops - $todayBR" } }
            )
        }
        children = @()
    } | ConvertTo-Json -Depth 10
    $newPage = Invoke-NotionApi -Endpoint '/pages' -Method 'POST' -Body $createBody
    $reportPageId = $newPage.id
    Start-Sleep -Seconds 2
}

Write-Host "[relatorio-devops] Report page: $reportPageId"

# --- 5. Build Notion blocks ---

function Build-TableRow {
    param(
        [string]$Id,
        [string]$Title,
        [string]$State,
        [string]$DueDateBR,
        [string]$DaysInfo,
        [bool]$IsWarning,
        [bool]$IsOverdue
    )

    $titleText = "[$Id] $Title"
    if ($titleText.Length -gt 100) { $titleText = $titleText.Substring(0, 97) + '...' }

    $titleCell = @{
        type = 'text'
        text = @{ content = $titleText }
    }
    if ($IsWarning) {
        $titleCell.annotations = @{ color = 'red' }
    }

    $stateText = $State
    if ($IsOverdue) {
        $stateText = "$State (VENCIDA)"
    }

    $cells = @(
        @($titleCell),
        @(@{ type = 'text'; text = @{ content = $stateText } }),
        @(@{ type = 'text'; text = @{ content = $DueDateBR } }),
        @(@{ type = 'text'; text = @{ content = $DaysInfo } })
    )

    return @{
        type = 'table_row'
        table_row = @{ cells = $cells }
    }
}

# Build blocks array
$blocks = @()

# Header
$blocks += @{
    type = 'heading_1'
    heading_1 = @{
        rich_text = @(@{ type = 'text'; text = @{ content = "Relatorio Diario Devops" } })
    }
}

$blocks += @{
    type = 'paragraph'
    paragraph = @{
        rich_text = @(
            @{
                type = 'text'
                text = @{ content = "Gerado em $(Get-Date -Format 'dd/MM/yyyy HH:mm') - " }
            }
            @{
                type = 'text'
                text = @{ content = "$($activeItems.Count) ativas"
                    link = $null
                }
                annotations = @{ bold = $true }
            }
            @{
                type = 'text'
                text = @{ content = " | " }
            }
            @{
                type = 'text'
                text = @{ content = "$($overdueItems.Count) vencidas" }
                annotations = @{ bold = $true; color = 'red' }
            }
        )
    }
}

# Text-based chart
$blocks += @{
    type = 'heading_3'
    heading_3 = @{
        rich_text = @(@{ type = 'text'; text = @{ content = "Status dos Work Items" } })
    }
}

$chartText = ""
$chartText += "Vencidos: $overdueCount  |  <= 3 dias: $warningCount  |  Saudaveis: $healthyCount  |  Total: $total`n`n"

# Bar chart using text
$maxBar = 30
if ($total -gt 0) {
    $overBar = [Math]::Max(1, [Math]::Round(($overdueCount / $total) * $maxBar))
    $warnBar = [Math]::Max(1, [Math]::Round(($warningCount / $total) * $maxBar))
    $healthBar = [Math]::Max(1, [Math]::Round(($healthyCount / $total) * $maxBar))
} else {
    $overBar = 0; $warnBar = 0; $healthBar = 0
}

$chartText += "Vencidos   | " + ("#" * $overBar) + " $overdueCount`n"
$chartText += "<= 3 dias  | " + ("#" * $warnBar) + " $warningCount`n"
$chartText += "Saudaveis  | " + ("#" * $healthBar) + " $healthyCount`n"

$blocks += @{
    type = 'code'
    code = @{
        rich_text = @(@{ type = 'text'; text = @{ content = $chartText } })
        caption = @(@{ type = 'text'; text = @{ content = "Grafico de status" } })
        language = 'plain text'
    }
}

# Active items table
if ($activeItems.Count -gt 0) {
    $blocks += @{
        type = 'heading_2'
        heading_2 = @{
            rich_text = @(@{ type = 'text'; text = @{ content = "Work Items Ativos (ordenados por due date)" } })
        }
    }

    # Table header
    $headerRow = @{
        type = 'table_row'
        table_row = @{
            cells = @(
                @(@{ type = 'text'; text = @{ content = 'Work Item' }; annotations = @{ bold = $true } }),
                @(@{ type = 'text'; text = @{ content = 'Estado' }; annotations = @{ bold = $true } }),
                @(@{ type = 'text'; text = @{ content = 'Due Date' }; annotations = @{ bold = $true } }),
                @(@{ type = 'text'; text = @{ content = 'Dias' }; annotations = @{ bold = $true } })
            )
        }
    }

    $tableRows = @($headerRow)
    foreach ($item in $activeItems) {
        $isWarning = ($item.DaysUntilDue -ne $null -and $item.DaysUntilDue -le 3)
        $daysInfo = if ($item.DaysUntilDue -ne $null) { "$($item.DaysUntilDue) dias" } else { 'sem data' }
        $tableRows += Build-TableRow `
            -Id $item.Id `
            -Title $item.Title `
            -State $item.State `
            -DueDateBR $item.DueDateBR `
            -DaysInfo $daysInfo `
            -IsWarning $isWarning `
            -IsOverdue $false
    }

    $blocks += @{
        type = 'table'
        table = @{
            table_width = 4
            has_column_header = $false
            has_row_header = $false
            children = $tableRows
        }
    }
}

# Overdue items table
if ($overdueItems.Count -gt 0) {
    $blocks += @{
        type = 'heading_2'
        heading_2 = @{
            rich_text = @(@{ type = 'text'; text = @{ content = "Work Items Vencidos" }; annotations = @{ color = 'red' } })
        }
    }

    $headerRow = @{
        type = 'table_row'
        table_row = @{
            cells = @(
                @(@{ type = 'text'; text = @{ content = 'Work Item' }; annotations = @{ bold = $true } }),
                @(@{ type = 'text'; text = @{ content = 'Estado' }; annotations = @{ bold = $true } }),
                @(@{ type = 'text'; text = @{ content = 'Due Date' }; annotations = @{ bold = $true } }),
                @(@{ type = 'text'; text = @{ content = 'Dias vencido' }; annotations = @{ bold = $true } })
            )
        }
    }

    $tableRows = @($headerRow)
    foreach ($item in $overdueItems) {
        $daysInfo = "$($item.DaysOverdue) dias"
        $tableRows += Build-TableRow `
            -Id $item.Id `
            -Title $item.Title `
            -State $item.State `
            -DueDateBR $item.DueDateBR `
            -DaysInfo $daysInfo `
            -IsWarning $false `
            -IsOverdue $true
    }

    $blocks += @{
        type = 'table'
        table = @{
            table_width = 4
            has_column_header = $false
            has_row_header = $false
            children = $tableRows
        }
    }
}

# No items message
if ($activeItems.Count -eq 0 -and $overdueItems.Count -eq 0) {
    $blocks += @{
        type = 'paragraph'
        paragraph = @{
            rich_text = @(@{ type = 'text'; text = @{ content = "Nenhum work item encontrado nos estados PRIORIZADO, REFINAMENTO TECNICO, EM DESENVOLVIMENTO ou UAT." } })
        }
    }
}

# --- 6. Push blocks to Notion (in chunks of 100) ---

Write-Host "[relatorio-devops] Writing to Notion..."

# Notion API allows max 100 blocks per request
$chunkSize = 100
for ($i = 0; $i -lt $blocks.Count; $i += $chunkSize) {
    $end = [Math]::Min($i + $chunkSize - 1, $blocks.Count - 1)
    $chunk = $blocks[$i..$end]

    $body = @{ children = $chunk } | ConvertTo-Json -Depth 20
    Invoke-NotionApi -Endpoint "/blocks/$reportPageId/children" -Method 'PATCH' -Body $body | Out-Null
}

Write-Host "[relatorio-devops] Done! Page: https://app.notion.com/p/$reportPageId"
