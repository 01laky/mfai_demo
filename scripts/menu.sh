#!/bin/bash

# menu.sh - Norton Commander style interactive menu for dev scripts
# Usage: ./scripts/menu.sh (from repository root)
# Controls: ↑/↓ navigate  Enter go in / run  Backspace/←/Esc go back

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"
cd "$ROOT"

if [ ! -t 0 ] || [ ! -t 1 ]; then
  echo "This script requires an interactive terminal."
  exit 1
fi

ROOT_SCRIPTS="start-all-dev.sh stop-all-dev.sh restart-all-dev.sh clear-all-dev.sh rebuild-all-dev.sh status-all.sh test-all.sh lint-all.sh"
CONTAINER_ORDER="many_faces_backend many_faces_portal many_faces_admin many_faces_ai many_faces_database many_faces_redis many_faces_logger many_faces_mobile"
CONTAINER_SCRIPTS=(
  "scripts/lint.sh scripts/start-dev.sh scripts/stop-dev.sh scripts/clear-dev.sh scripts/rebuild-dev.sh scripts/generate-diagram.sh"
  "scripts/lint.sh scripts/start-dev.sh scripts/stop-dev.sh scripts/clear-dev.sh scripts/rebuild-dev.sh scripts/fix-editor.sh"
  "scripts/lint.sh scripts/start-dev.sh scripts/stop-dev.sh scripts/clear-dev.sh scripts/rebuild-dev.sh scripts/fix-editor.sh"
  "scripts/lint.sh scripts/start-dev.sh scripts/stop-dev.sh scripts/clear-dev.sh scripts/rebuild-dev.sh scripts/generate_proto.sh"
  "scripts/start-db.sh scripts/stop-db.sh scripts/clear-db.sh scripts/create-bedemo-role.sh"
  "scripts/start-redis.sh scripts/stop-redis.sh scripts/clear-redis.sh"
  "scripts/start-dev.sh scripts/stop-dev.sh scripts/clear-dev.sh scripts/rebuild-dev.sh"
  "scripts/lint.sh scripts/verify-ci.sh scripts/test.sh scripts/typecheck.sh scripts/build.sh"
)

NORMAL=$'\033[0m'
BOLD=$'\033[1m'
REVERSE=$'\033[7m'
DIM=$'\033[2m'

term_save() {
  saved_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon min 1 time 0 2>/dev/null
  tput civis 2>/dev/null
}

term_restore() {
  tput cnorm 2>/dev/null
  stty "${saved_stty:-$(stty -g 2>/dev/null)}" 2>/dev/null
}

# Reads one key. Output: UP DOWN LEFT RIGHT ENTER ESC BACK
read_key() {
  local k
  read -rsn 1 k < /dev/tty
  if [ "$k" = $'\e' ]; then
    read -rsn 2 k < /dev/tty
    case "$k" in
      '[A') echo UP ;;
      '[B') echo DOWN ;;
      '[C') echo RIGHT ;;
      '[D') echo LEFT ;;
      *) echo ESC ;;
    esac
  elif [ "$k" = $'\x7f' ] || [ "$k" = $'\x08' ]; then
    echo BACK
  else
    case "$k" in
      ''|$'\r'|$'\n') echo ENTER ;;
      q|Q) echo ESC ;;
      *) echo OTHER ;;
    esac
  fi
}

run_script() {
  local dir=$1
  local script=$2
  term_restore
  echo ""
  echo "▶ Running $dir/$script ..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$dir" = "." ] || [ -z "$dir" ]; then
    "./$script" || true
  else
    (cd "$dir" && ./"$script") || true
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  read -p "Press Enter to continue..."
  term_save
}

# Show menu, return when user selects. Selection index in SELECTED_IDX.
# Items: "TYPE|payload"  TYPE=FOLDER|SCRIPT|BACK|EXIT
#        FOLDER|label|title  -> enter shows submenu
#        SCRIPT|dir|script   -> run
#        BACK                -> pop/return
#        EXIT                -> quit app
show_menu() {
  local title=$1
  shift
  local items=("$@")
  local n=${#items[@]}
  [ "$n" -eq 0 ] && return 1
  local sel=0

  while true; do
    clear
    printf '%s\n' "${BOLD}  $title${NORMAL}"
    printf '  %s\n' "─────────────────────────────"
    printf '\n'
    local i=0
    for item in "${items[@]}"; do
      local typ="${item%%|*}"
      local label
      case "$typ" in
        FOLDER) label="[${item#*|}"; label="${label%%|*}"; label="$label]" ;;
        SCRIPT) label="  ${item##*|}" ;;
        BACK)   label=".." ;;
        EXIT)   label="Exit" ;;
        *)      label="?" ;;
      esac
      if [ "$i" -eq "$sel" ]; then
        printf '  %s%s%s\n' "${REVERSE}" " $label " "${NORMAL}"
      else
        printf '  %s\n' "$label"
      fi
      i=$((i + 1))
    done
    printf '\n'
    printf '%s\n' "  ${DIM}↑↓ Move  Enter open/run  ←/Backspace back  Esc exit${NORMAL}"

    local key
    while true; do
      key=$(read_key)
      case "$key" in
        UP)   sel=$(((sel - 1 + n) % n)); break ;;
        DOWN) sel=$(((sel + 1) % n)); break ;;
        ENTER|RIGHT|ESC|BACK) break ;;
        LEFT) key=BACK; break ;;
        OTHER|*) : ;;
      esac
    done

    case "$key" in
      ENTER|RIGHT)
        local entry="${items[$sel]}"
        local typ="${entry%%|*}"
        case "$typ" in
          FOLDER)
            local rest="${entry#*|}"
            rest="${rest#*|}"
            SELECTED_PAYLOAD="$rest"
            SELECTED_IDX=$sel
            return 0
            ;;
          SCRIPT)
            local rest="${entry#*|}"
            local dir="${rest%%|*}"
            local script="${rest#*|}"
            run_script "$dir" "$script"
            ;;
          BACK)
            SELECTED_IDX=-1
            return 1
            ;;
          EXIT)
            term_restore
            echo "Bye."
            exit 0
            ;;
        esac
        ;;
      ESC|LEFT|BACK)
        SELECTED_IDX=-1
        return 1
        ;;
    esac
  done
}

main() {
  term_save
  trap 'term_restore; exit 0' EXIT INT TERM

  local stack=("ROOT")
  local sel=0

  while true; do
    local level="${stack[$((${#stack[@]}-1))]}"
    local items=()
    local title=""

    if [ "$level" = "ROOT" ]; then
      title="Dev Scripts"
      items+=("FOLDER|Monorepo scripts (scripts/)|.")
      local idx=0
      for c in $CONTAINER_ORDER; do
        if [ -d "$c" ]; then
          items+=("FOLDER|$c|$idx")
          idx=$((idx + 1))
        fi
      done
      items+=("EXIT|")
    elif [ "$level" = "." ]; then
      title="scripts/"
      items+=("BACK|")
      for s in $ROOT_SCRIPTS; do
        [ -f "$SCRIPTS_DIR/$s" ] && items+=("SCRIPT|.|$s")
      done
    else
      local idx=$level
      local c
      local i=0
      for d in $CONTAINER_ORDER; do
        [ "$i" -eq "$idx" ] && { c=$d; break; }
        i=$((i + 1))
      done
      title="$c"
      items+=("BACK|")
      local scripts_str
      eval "scripts_str=\"\${CONTAINER_SCRIPTS[$idx]}\""
      for s in $scripts_str; do
        [ -f "$c/$s" ] && items+=("SCRIPT|$c|$s")
      done
    fi

    if show_menu "$title" "${items[@]}"; then
      local payload="$SELECTED_PAYLOAD"
      if [ "$level" = "ROOT" ]; then
        stack+=("$payload")
      fi
    else
      if [ ${#stack[@]} -gt 1 ]; then
        stack=("${stack[@]:0:$((${#stack[@]}-1))}")
      fi
    fi
  done

  term_restore
}

main
