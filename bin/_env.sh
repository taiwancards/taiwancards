load_env() {
  local file="${ENV_FILE:-.env}" line key stored drift=""
  [ -f "$file" ] || return 0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in '' | '#'*) continue ;; esac
    line=${line#export }
    key=${line%%=*}
    case "$key" in '' | *[!A-Za-z0-9_]*) continue ;; esac

    if [ -n "${!key+set}" ]; then
      eval "stored=${line#*=}" 2> /dev/null || continue
      [ "${!key}" = "$stored" ] || drift="$drift $key"
      continue
    fi

    eval "export $key=${line#*=}"
  done < "$file"

  [ -z "$drift" ] && return 0

  printf '\n  !  your shell exports a different value than %s for:%s\n' "$file" "$drift" >&2
  printf '     the exported one wins. Clear it (fish: set -e NAME) to use %s.\n\n' "$file" >&2
}
