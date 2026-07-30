if [ -t 1 ]; then
  B=$'\033[1m'
  DIM=$'\033[2m'
  R=$'\033[0m'
  GREEN=$'\033[32m'
  RED=$'\033[31m'
  YELLOW=$'\033[33m'
  CYAN=$'\033[36m'
else
  B=""
  DIM=""
  R=""
  GREEN=""
  RED=""
  YELLOW=""
  CYAN=""
fi

width() {
  local w
  w=$(tput cols 2> /dev/null || echo 80)
  [ "$w" -gt 76 ] && echo 76 || echo "$w"
}

rule() { printf "%s%s%s\n" "$DIM" "$(printf '%*s' "$(width)" '' | tr ' ' '=')" "$R"; }

ok() { printf "  %s✓%s %s\n" "$GREEN" "$R" "$1"; }

warn() { printf "  %s!%s %s\n" "$YELLOW" "$R" "$1"; }

die() {
  printf "\n  %s✗ %s%s\n\n" "$RED" "$1" "$R"
  exit 1
}

pad() {
  local text=$1 want=$2 have=${#1}
  printf "%s" "$text"
  [ "$want" -gt "$have" ] && printf "%*s" $((want - have)) "" || true
}

human() {
  awk -v bytes="$1" 'BEGIN {
    split("B KB MB GB", unit, " "); i = 1
    while (bytes >= 1024 && i < 4) { bytes /= 1024; i++ }
    printf("%.1f %s", bytes, unit[i])
  }'
}

bar() {
  local percent=$1 w=30 filled
  [ "$percent" -gt 100 ] && percent=100
  filled=$((percent * w / 100))
  printf "["
  printf "%${filled}s" "" | tr ' ' '#'
  printf "%$((w - filled))s" "" | tr ' ' '.'
  printf "] %3d%%" "$percent"
}

size_of() { stat -f%z "$1" 2> /dev/null || stat -c%s "$1"; }
