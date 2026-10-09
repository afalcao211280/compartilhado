#!/usr/bin/env bash

# Statusline script para Claude Code
# Mostra: ícone animado do Claude digitando, modelo, effort, pasta, branch git e % contexto

# ── Caractere ESC real (printf NÃO interpreta \e dentro de argumentos %s) ──
ESC=$'\033'

# ── Animação de digitação (estrela piscando; frame baseado em centésimos de segundo) ──
SPINNERS=(✦ ✶ ✷ ✵ ✴ ✳)
FRAME=$(( 10#$(date +%N | cut -c1-2) % 6 ))
SPINNER="${SPINNERS[$FRAME]}"

# ── Lê JSON do stdin ──
INPUT=$(cat)

# ── Extrai campos via jq ──
MODEL_NAME=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
EFFORT=$(echo "$INPUT" | jq -r '.effort.level // empty')
CWD=$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // empty')
USED_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // empty')

# ── Pasta: full path do cwd (equivalente ao \w do PS1) ──
if [ -z "$CWD" ]; then
    CWD=$(pwd)
fi
DIR_SHORT=$(basename "$CWD")
DIR_FULL="$CWD"

# ── Branch git ──
GIT_BRANCH=""
GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null)
if [ -n "$GIT_DIR" ]; then
    BRANCH=$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null)
    NF_BRANCH=$''

    STAGED=$(git -C "$CWD" diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
    MODIFIED=$(git -C "$CWD" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    UNTRACKED=$(git -C "$CWD" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

    GIT_STATS=""
    [ "$STAGED" -gt 0 ]    && GIT_STATS+="${ESC}[32m+${STAGED}${ESC}[0m"
    [ "$MODIFIED" -gt 0 ]  && GIT_STATS+="${ESC}[33m~${MODIFIED}${ESC}[0m"
    [ "$UNTRACKED" -gt 0 ] && GIT_STATS+="${ESC}[36m?${UNTRACKED}${ESC}[0m"

    [ -n "$BRANCH" ] && GIT_BRANCH=" ${ESC}[0m${NF_BRANCH} ${ESC}[32m${BRANCH} ${ESC}[90m${ESC}[0m${GIT_STATS}"
fi

# ── Barra de progresso do contexto ──
BAR=""
if [ -n "$USED_PCT" ]; then
    PCT=$(printf "%.0f" "$USED_PCT")
    WIDTH=12

    # Precisão em oitavos de bloco para refletir uso mesmo em % baixo
    PARTIALS=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
    EIGHTHS=$(( PCT * WIDTH * 8 / 100 ))
    FULL=$(( EIGHTHS / 8 ))
    REM=$(( EIGHTHS % 8 ))
    [ "$FULL" -gt "$WIDTH" ] && { FULL=$WIDTH; REM=0; }
    PART="${PARTIALS[$REM]}"
    EMPTY=$(( WIDTH - FULL ))
    [ -n "$PART" ] && EMPTY=$(( EMPTY - 1 ))
    [ "$EMPTY" -lt 0 ] && EMPTY=0

    # Cor da barra: verde → amarelo → vermelho conforme uso
    if [ "$PCT" -lt 45 ]; then
        BAR_COLOR="${ESC}[32m"   # verde
    elif [ "$PCT" -lt 65 ]; then
        BAR_COLOR="${ESC}[33m"   # amarelo
    else
        BAR_COLOR="${ESC}[31m"   # vermelho
    fi

    # Repetição via concatenação (tr quebra UTF-8 multibyte byte a byte)
    FULL_STR=""; for ((i=0; i<FULL; i++)); do FULL_STR+="█"; done
    EMPTY_STR=""; for ((i=0; i<EMPTY; i++)); do EMPTY_STR+="░"; done
    BAR=" ${ESC}[90m| 🧠 ${BAR_COLOR}[${FULL_STR}${PART}${EMPTY_STR}]${ESC}[0m ${ESC}[90m${PCT}%${ESC}[0m"
fi

# ── Uso do plano (rate limits) ──
PLAN_STR=""
FIVE_H=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESETS_AT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty')
WEEK=$(echo "$INPUT"  | jq -r '.rate_limits.seven_day.used_percentage // empty')
WEEK_RESETS_AT=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Calcula segundos até reset (timestamp_reset - agora)
NOW=$(date +%s)
if [ -n "$FIVE_H_RESETS_AT" ] && [ "$FIVE_H_RESETS_AT" -gt "$NOW" ]; then
    FIVE_H_RESET=$(( FIVE_H_RESETS_AT - NOW ))
else
    FIVE_H_RESET=""
fi
if [ -n "$WEEK_RESETS_AT" ] && [ "$WEEK_RESETS_AT" -gt "$NOW" ]; then
    WEEK_RESET=$(( WEEK_RESETS_AT - NOW ))
else
    WEEK_RESET=""
fi

_pct_color() {
    local pct=$1
    if   [ "$pct" -lt 50 ]; then echo "${ESC}[32m"  # verde
    elif [ "$pct" -lt 80 ]; then echo "${ESC}[33m"  # amarelo
    else                         echo "${ESC}[31m"  # vermelho
    fi
}

_format_time() {
    local secs=$1
    local show_days=${2:-0}
    if [ -z "$secs" ] || [ "$secs" -le 0 ]; then
        echo "soon"
        return
    fi

    if [ "$show_days" -eq 1 ]; then
        local d=$(( secs / 86400 ))
        local h=$(( (secs % 86400) / 3600 ))
        if [ "$d" -gt 0 ]; then
            printf "%dd%dh" "$d" "$h"
        else
            local m=$(( (secs % 3600) / 60 ))
            if [ "$h" -gt 0 ]; then
                printf "%dh%02dm" "$h" "$m"
            else
                printf "%dm" "$m"
            fi
        fi
    else
        local h=$(( secs / 3600 ))
        local m=$(( (secs % 3600) / 60 ))
        if [ "$h" -gt 0 ]; then
            printf "%dh%02dm" "$h" "$m"
        else
            printf "%dm" "$m"
        fi
    fi
}

if [ -n "$FIVE_H" ] || [ -n "$WEEK" ]; then
    PLAN_STR=" ${ESC}[90m|${ESC}[0m"
    if [ -n "$FIVE_H" ]; then
        P=$(printf "%.0f" "$FIVE_H")
        C=$(_pct_color "$P")
        RESET_TIME=$(_format_time "$FIVE_H_RESET" 0)
        PLAN_STR+=" ${ESC}[90m⏱️ ${ESC}[0m5H: ${C}${P}%${ESC}[0m ${ESC}[90m↻ ${RESET_TIME}${ESC}[0m"
    fi
    if [ -n "$WEEK" ]; then
        P=$(printf "%.0f" "$WEEK")
        C=$(_pct_color "$P")
        RESET_TIME=$(_format_time "$WEEK_RESET" 1)
        PLAN_STR+=" ${ESC}[90m📅 ${ESC}[0m1W: ${C}${P}%${ESC}[0m ${ESC}[90m↻ ${RESET_TIME}${ESC}[0m"
    fi
fi

# ── Caveman mode ──
CAVEMAN_STR=""
CAVEMAN_FILE="$HOME/.claude/.caveman-active"
if [ -f "$CAVEMAN_FILE" ]; then
    CAVEMAN_LEVEL=$(cat "$CAVEMAN_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$CAVEMAN_LEVEL" ] && [ "$CAVEMAN_LEVEL" != "off" ]; then
        case "$CAVEMAN_LEVEL" in
            lite)  CAVEMAN_STR=" ${ESC}[90m|${ESC}[0m 💀 ${ESC}[33mlite${ESC}[0m" ;;
            full)  CAVEMAN_STR=" ${ESC}[90m|${ESC}[0m 💀 ${ESC}[31mfull${ESC}[0m" ;;
            ultra) CAVEMAN_STR=" ${ESC}[90m|${ESC}[0m 💀 ${ESC}[35multra${ESC}[0m" ;;
            *)     CAVEMAN_STR=" ${ESC}[90m|${ESC}[0m 💀 ${ESC}[31m${CAVEMAN_LEVEL}${ESC}[0m" ;;
        esac
    fi
fi

# ── Effort: ícone por nível ──
EFFORT_STR=""
if [ -n "$EFFORT" ]; then
    case "$EFFORT" in
        low)    EFFORT_STR=" ${ESC}[90m|${ESC}[0m 🐢${ESC}[36mlow${ESC}[0m" ;;
        medium) EFFORT_STR=" ${ESC}[90m|${ESC}[0m ⚡${ESC}[33mmed${ESC}[0m" ;;
        high)   EFFORT_STR=" ${ESC}[90m|${ESC}[0m 🔥${ESC}[91mhigh${ESC}[0m" ;;
        xhigh)  EFFORT_STR=" ${ESC}[90m|${ESC}[0m 🚀${ESC}[31mxhigh${ESC}[0m" ;;
        max)    EFFORT_STR=" ${ESC}[90m|${ESC}[0m 💥${ESC}[35mmax${ESC}[0m" ;;
        *)      EFFORT_STR=" ${ESC}[90m|${ESC}[0m ${EFFORT}" ;;
    esac
fi

# ── Monta e imprime a statusline ──
# Formato: spinner model effort | 📁 /full/path (🌿 branch) | 🧠 [context bar]
printf "${ESC}[35m%s${ESC}[0m  ${ESC}[1m%s${ESC}[0m%s%s ${ESC}[90m|${ESC}[0m 📁 ${ESC}[01;34m%s${ESC}[00m%s${ESC}[90m${ESC}[0m%s%s" \
    "$SPINNER" \
    "$MODEL_NAME" \
    "$EFFORT_STR" \
    "$CAVEMAN_STR" \
    "$DIR_SHORT" \
    "$GIT_BRANCH" \
    "$PLAN_STR" \
    "$BAR"
