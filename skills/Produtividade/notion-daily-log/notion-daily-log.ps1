<#
.SYNOPSIS
    Notion Daily Logger - logs completed tasks to a daily page in Notion.
.DESCRIPTION
    1. Filters out noise/trivial tasks (tool updates, installs, meta-config)
    2. Finds the "Daily" page in Notion workspace
    3. Calculates the next business day (next weekday)
    4. Checks if a sub-page for that day already exists
    5. If not, creates it as a child of "Daily"
    6. Reads existing content to avoid duplicates
    7. Groups related tasks under a topic heading (if -Topic provided)
    8. Appends the new task entry
.PARAMETER Task
    The task description to log (what was done).
.PARAMETER AiName
    Name of the AI that completed the task (for attribution).
.PARAMETER Detail
    Optional additional detail/context about the task.
.PARAMETER Topic
    Optional grouping key. When provided, tasks with the same Topic are
    grouped under a heading with that name. Use for multi-step work
    (e.g., investigation + fix + PR for the same issue).
    Example: -Topic "US-4040 normalizar pontuacao"
.PARAMETER Force
    Bypass the noise filter. Use only when explicitly logging config/meta tasks.
.EXAMPLE
    .\notion-daily-log.ps1 -Task "Refactored auth module" -AiName "Claude"
    .\notion-daily-log.ps1 -Task "Fixed bug #1234" -AiName "Crush" -Topic "bug-1234 auth" -Detail "Changed null check in line 45"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Task,

    [string]$AiName = 'AI',

    [string]$Detail = '',

    [string]$Topic = '',

    [switch]$Force,

    [string]$DailyPageId = '',

    [string]$Token = ''
)

$ErrorActionPreference = 'Stop'

# --- Config ---
if (-not $Token) {
    $Token = [Environment]::GetEnvironmentVariable('NOTION_PAT', 'User')
    if (-not $Token) {
        $Token = [Environment]::GetEnvironmentVariable('NOTION_API', 'User')
    }
}
if (-not $Token) {
    Write-Error 'No Notion token found. Set NOTION_PAT or NOTION_API env var.'
    exit 1
}

$NotionVersion = '2022-06-28'
$BaseUrl = 'https://api.notion.com/v1'

# --- Noise filter ---
# Patterns that indicate trivial/meta tasks that should NOT be logged
$NoisePatterns = @(
    'update.{0,10}grok',
    'update.{0,10}cli',
    'update.{0,10}cursor',
    'update.{0,10}crush',
    'instal(a|ou|ando).{0,15}(grok|cursor|cli|crush|node|npm|bun)',
    'auto.?load.{0,15}SessionStart',
    'SessionStart.{0,15}hook',
    'notion-daily-log.{0,10}(hook|config|activate|skill|auto)',
    'broadcast.?skills',
    'skill.{0,10}(instalada|instalou|recarregar|reload)',
    'hook.{0,10}(activate|config|grok|notion)',
    '(ajustar|ajustando|criar|criando|refinar).{0,15}hook',
    'reload.{0,10}skills',
    'recarregar.{0,10}skills',
    'statusline.{0,10}config',
    'config.{0,10}statusline',
    'agents\.md.{0,10}atualiz',
    'config\.toml.{0,10}atualiz',
    'settings\.json.{0,10}atualiz',
    'completar config',
    'configuracao inicial',
    'setup inicial',
    'verificar.{0,15}(task|broadcast|funcion)',
    'diagnostico.{0,15}notion',
    'teste.{0,15}notion.{0,15}log'
)

function Test-IsNoise {
    param([string]$TaskText)

    foreach ($pattern in $NoisePatterns) {
        if ($TaskText -match $pattern) {
            return $true
        }
    }
    return $false
}

# --- Noise filter check ---
if (-not $Force) {
    $isNoise = Test-IsNoise -TaskText $Task
    if ($isNoise) {
        Write-Host "[notion-daily-log] FILTERED (noise): $Task"
        Write-Host "[notion-daily-log] Use -Force to override if this is intentional."
        exit 0
    }
}

function Invoke-NotionApi {
    param(
        [string]$Endpoint,
        [string]$Method = 'GET',
        [string]$Body = ''
    )
    $headers = @{
        'Authorization' = "Bearer $Token"
        'Notion-Version' = $NotionVersion
        'Content-Type' = 'application/json'
    }
    $uri = "$BaseUrl$Endpoint"
    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Uri $uri -Method GET -Headers $headers
    }
    else {
        return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -Body $Body
    }
}

function Get-DailyPageId {
    if ($script:DailyPageId) { return $script:DailyPageId }

    $body = @{ query = 'Daily'; page_size = 30 } | ConvertTo-Json -Compress
    $resp = Invoke-NotionApi -Endpoint '/search' -Method 'POST' -Body $body

    $candidates = @()
    foreach ($result in $resp.results) {
        if ($result.object -eq 'page') {
            $title = ''
            if ($result.properties -and $result.properties.title -and $result.properties.title.title) {
                $title = ($result.properties.title.title | ForEach-Object { $_.plain_text }) -join ''
            }
            if ($title -match 'Daily' -or $result.url -match 'Daily') {
                $candidates += @{ id = $result.id; title = $title; parentType = $result.parent.type; url = $result.url }
            }
        }
    }

    foreach ($c in $candidates) {
        if ($c.parentType -eq 'workspace') {
            return $c.id
        }
    }

    if ($candidates.Count -gt 0) {
        return $candidates[0].id
    }
    return $null
}

function Get-NextBusinessDay {
    $today = Get-Date
    $next = $today.AddDays(1)
    while ($next.DayOfWeek -eq 'Saturday' -or $next.DayOfWeek -eq 'Sunday') {
        $next = $next.AddDays(1)
    }
    return $next
}

function Format-DateBR {
    param([DateTime]$Date)
    return $Date.ToString('dd/MM/yyyy')
}

function Format-DateISO {
    param([DateTime]$Date)
    return $Date.ToString('yyyy-MM-dd')
}

function Get-DailyChildPage {
    param([string]$ParentId, [string]$DateTitle)

    $children = Invoke-NotionApi -Endpoint "/blocks/$ParentId/children?page_size=100" -Method 'GET'
    foreach ($block in $children.results) {
        if ($block.type -eq 'child_page' -and $block.child_page.title -match [regex]::Escape($DateTitle)) {
            return $block
        }
    }

    $searchBody = @{
        query = $DateTitle
        filter = @{ property = 'object'; value = 'page' }
        page_size = 10
    } | ConvertTo-Json -Compress
    $searchResp = Invoke-NotionApi -Endpoint '/search' -Method 'POST' -Body $searchBody
    foreach ($result in $searchResp.results) {
        $title = ''
        if ($result.properties -and $result.properties.title -and $result.properties.title.title) {
            $title = ($result.properties.title.title | ForEach-Object { $_.plain_text }) -join ''
        }
        if ($title -match [regex]::Escape($DateTitle)) {
            if ($result.parent -and $result.parent.page_id -eq $ParentId) {
                return @{
                    id = $result.id
                    type = 'child_page'
                    child_page = @{ title = $title }
                }
            }
        }
    }

    return $null
}

function New-DailyChildPage {
    param([string]$ParentId, [string]$Title, [string]$DateISO)

    $body = @{
        parent = @{ page_id = $ParentId }
        properties = @{
            title = @(
                @{
                    text = @{ content = $Title }
                }
            )
        }
        children = @(
            @{
                type = 'heading_1'
                heading_1 = @{
                    rich_text = @(
                        @{ type = 'text'; text = @{ content = "Daily - $Title" } }
                    )
                }
            },
            @{
                type = 'paragraph'
                paragraph = @{
                    rich_text = @(
                        @{ type = 'text'; text = @{ content = "Data: $DateISO" }; annotations = @{ italic = $true; color = 'gray' } }
                    )
                }
            },
            @{
                type = 'heading_2'
                heading_2 = @{
                    rich_text = @(
                        @{ type = 'text'; text = @{ content = 'Tarefas Concluidas' } }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    $resp = Invoke-NotionApi -Endpoint '/pages' -Method 'POST' -Body $body
    return $resp
}

function Get-ExistingTaskTexts {
    param([string]$PageId)

    $texts = @()
    $children = Invoke-NotionApi -Endpoint "/blocks/$PageId/children?page_size=100" -Method 'GET'
    foreach ($block in $children.results) {
        $richText = $null
        $blockData = $block.$($block.type)
        if ($blockData -and $blockData.rich_text) {
            $richText = ($blockData.rich_text | ForEach-Object { $_.plain_text }) -join ''
        }
        if ($richText) {
            $texts += $richText
        }
    }
    return $texts
}

function Get-AllBlocks {
    param([string]$PageId)

    $children = Invoke-NotionApi -Endpoint "/blocks/$PageId/children?page_size=100" -Method 'GET'
    return $children.results
}

function Find-TopicHeading {
    param(
        [array]$Blocks,
        [string]$TopicName
    )

    $topicPattern = [regex]::Escape($TopicName)
    for ($i = 0; $i -lt $Blocks.Count; $i++) {
        $block = $Blocks[$i]
        if ($block.type -match 'heading_3|heading_2') {
            $blockData = $block.$($block.type)
            if ($blockData -and $blockData.rich_text) {
                $headingText = ($blockData.rich_text | ForEach-Object { $_.plain_text }) -join ''
                if ($headingText -match $topicPattern) {
                    return @{ index = $i; block = $block }
                }
            }
        }
    }
    return $null
}

function Find-TopicBulletRange {
    param(
        [array]$Blocks,
        [int]$HeadingIndex
    )

    # Find the range of bulleted_list_item blocks after the heading
    # (until the next heading or end of blocks)
    $startIndex = -1
    $endIndex = -1

    for ($i = $headingIndex + 1; $i -lt $Blocks.Count; $i++) {
        $block = $Blocks[$i]
        if ($block.type -eq 'bulleted_list_item') {
            if ($startIndex -eq -1) { $startIndex = $i }
            $endIndex = $i
        }
        elseif ($block.type -match 'heading_') {
            break
        }
    }

    return @{ startIndex = $startIndex; endIndex = $endIndex }
}

function Add-TopicHeading {
    param(
        [string]$PageId,
        [string]$TopicName
    )

    $body = @{
        children = @(
            @{
                type = 'heading_3'
                heading_3 = @{
                    rich_text = @(
                        @{ type = 'text'; text = @{ content = $TopicName } }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    Invoke-NotionApi -Endpoint "/blocks/$PageId/children" -Method 'PATCH' -Body $body | Out-Null
}

function Add-TaskToDaily {
    param(
        [string]$PageId,
        [string]$TaskText,
        [string]$AiName,
        [string]$Detail
    )

    $timestamp = Get-Date -Format 'HH:mm'
    $fullText = "[$timestamp] [$AiName] $TaskText"
    if ($Detail) {
        $fullText += " - $Detail"
    }

    $body = @{
        children = @(
            @{
                type = 'bulleted_list_item'
                bulleted_list_item = @{
                    rich_text = @(
                        @{ type = 'text'; text = @{ content = $fullText } }
                    )
                }
            }
        )
    } | ConvertTo-Json -Depth 10

    Invoke-NotionApi -Endpoint "/blocks/$PageId/children" -Method 'PATCH' -Body $body | Out-Null
    return $fullText
}

function Add-TaskUnderTopic {
    param(
        [string]$PageId,
        [string]$TopicName,
        [string]$TaskText,
        [string]$AiName,
        [string]$Detail
    )

    # Get all blocks to find where to insert
    $blocks = Get-AllBlocks -PageId $PageId

    # Find the topic heading
    $headingInfo = Find-TopicHeading -Blocks $blocks -TopicName $TopicName

    if ($headingInfo) {
        # Topic heading exists — find the last bullet under it
        $range = Find-TopicBulletRange -Blocks $blocks -HeadingIndex $headingInfo.index

        if ($range.endIndex -ge 0) {
            # Insert after the last bullet in this topic group
            $lastBulletBlock = $blocks[$range.endIndex]
            $afterId = $lastBulletBlock.id
        }
        else {
            # No bullets yet under this heading — insert right after the heading
            $afterId = $blocks[$headingInfo.index].id
        }

        $timestamp = Get-Date -Format 'HH:mm'
        $fullText = "[$timestamp] [$AiName] $TaskText"
        if ($Detail) {
            $fullText += " - $Detail"
        }

        $body = @{
            after = $afterId
            children = @(
                @{
                    type = 'bulleted_list_item'
                    bulleted_list_item = @{
                        rich_text = @(
                            @{ type = 'text'; text = @{ content = $fullText } }
                        )
                    }
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-NotionApi -Endpoint "/blocks/$PageId/children" -Method 'PATCH' -Body $body | Out-Null
        return $fullText
    }
    else {
        # Topic heading doesn't exist — create it then add the bullet
        Add-TopicHeading -PageId $PageId -TopicName $TopicName
        Start-Sleep -Seconds 1

        $timestamp = Get-Date -Format 'HH:mm'
        $fullText = "[$timestamp] [$AiName] $TaskText"
        if ($Detail) {
            $fullText += " - $Detail"
        }

        # Get updated blocks to find the new heading
        $blocks = Get-AllBlocks -PageId $PageId
        $headingInfo = Find-TopicHeading -Blocks $blocks -TopicName $TopicName

        if ($headingInfo) {
            $afterId = $blocks[$headingInfo.index].id
            $body = @{
                after = $afterId
                children = @(
                    @{
                        type = 'bulleted_list_item'
                        bulleted_list_item = @{
                            rich_text = @(
                                @{ type = 'text'; text = @{ content = $fullText } }
                            )
                        }
                    }
                )
            } | ConvertTo-Json -Depth 10

            Invoke-NotionApi -Endpoint "/blocks/$PageId/children" -Method 'PATCH' -Body $body | Out-Null
        }
        else {
            # Fallback: just append at the end
            Add-TaskToDaily -PageId $PageId -TaskText $TaskText -AiName $AiName -Detail $Detail | Out-Null
        }

        return $fullText
    }
}

# --- Main ---

Write-Host "[notion-daily-log] Starting..."

# 1. Find Daily page
$dailyId = Get-DailyPageId
if (-not $dailyId) {
    Write-Error 'Could not find "Daily" page in Notion workspace.'
    exit 1
}
Write-Host "[notion-daily-log] Daily page found: $dailyId"

# 2. Calculate next business day
$nextDay = Get-NextBusinessDay
$dateBR = Format-DateBR -Date $nextDay
$dateISO = Format-DateISO -Date $nextDay
$dailyTitle = "Daily $dateBR"
Write-Host "[notion-daily-log] Target daily: $dailyTitle ($dateISO)"

# 3. Check if child page exists
$childPage = Get-DailyChildPage -ParentId $dailyId -DateTitle $dateBR
if ($childPage) {
    Write-Host "[notion-daily-log] Daily page already exists: $($childPage.id)"
    $targetPageId = $childPage.id
} else {
    Write-Host "[notion-daily-log] Creating new daily page: $dailyTitle"
    $newPage = New-DailyChildPage -ParentId $dailyId -Title $dailyTitle -DateISO $dateISO
    $targetPageId = $newPage.id
    Write-Host "[notion-daily-log] Created: $targetPageId"
    Start-Sleep -Seconds 2
}

# 4. Check for duplicates
$existingTexts = Get-ExistingTaskTexts -PageId $targetPageId
$taskExists = $false
foreach ($existing in $existingTexts) {
    if ($existing -match [regex]::Escape($Task)) {
        $taskExists = $true
        break
    }
}

if ($taskExists) {
    Write-Host "[notion-daily-log] Task already logged, skipping: $Task"
    exit 0
}

# 5. Add task (with topic grouping if -Topic provided)
if ($Topic) {
    Write-Host "[notion-daily-log] Topic: $Topic"
    $loggedText = Add-TaskUnderTopic -PageId $targetPageId -TopicName $Topic -TaskText $Task -AiName $AiName -Detail $Detail
} else {
    $loggedText = Add-TaskToDaily -PageId $targetPageId -TaskText $Task -AiName $AiName -Detail $Detail
}

Write-Host "[notion-daily-log] Task logged: $loggedText"
Write-Host "[notion-daily-log] Done."
