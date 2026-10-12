# shellcheck shell=bash
# lib/prompt.sh: interactive prompts.
#
# Every prompt reads from file descriptor 3, which install.sh opens on
# /dev/tty. That keeps `curl ... | sudo bash` working (stdin is the script
# itself there) and lets tests feed answers with VPI_INPUT=<file>.
#
# Menus take entries as "id=Label". An entry whose id is "-" is a heading:
# printed, not numbered, not selectable.

prompt_init() {
  if [ -n "${VPI_INPUT:-}" ]; then
    exec 3<"$VPI_INPUT"
  elif [ -r /dev/tty ] && { : </dev/tty; } 2>/dev/null; then
    exec 3</dev/tty
  else
    exec 3<&0
  fi
}

# _readline VAR PROMPT: read one line from fd 3. EOF counts as "accept default".
_readline() {
  local __var="$1" __prompt="$2" __line=""
  printf '%s' "$__prompt"
  if ! IFS= read -r -u 3 __line; then
    __line=""
    printf '\n'
  elif [ -n "${VPI_INPUT:-}" ]; then
    printf '%s\n' "$__line"            # echo scripted answers so test logs read naturally
  fi
  printf -v "$__var" '%s' "$__line"
}

# ask_yn "Question" [y|n]: returns 0 for yes
ask_yn() {
  local q="$1" def="${2:-n}" hint a
  [ "$def" = y ] && hint="Y/n" || hint="y/N"
  while :; do
    _readline a "$q [$hint]: "
    a="${a:-$def}"
    case "${a,,}" in
      y|yes|j|ja) return 0 ;;
      n|no|nein)  return 1 ;;
    esac
    warn "Please answer y or n."
  done
}

# ask_text VAR "Question" [default]
ask_text() {
  local __v="$1" q="$2" def="${3:-}" a
  if [ -n "$def" ]; then _readline a "$q [$def]: "; else _readline a "$q: "; fi
  printf -v "$__v" '%s' "${a:-$def}"
}

# _menu_print ENTRIES...: prints numbered list; fills _MENU_IDS (index -> id)
_menu_print() {
  local e id label n=0
  _MENU_IDS=()
  for e in "$@"; do
    id="${e%%=*}" label="${e#*=}"
    if [ "$id" = "-" ]; then
      printf '   %s%s%s\n' "$C_B" "$label" "$C_RST"
      continue
    fi
    n=$((n + 1))
    _MENU_IDS[n]="$id"
    printf '   %2d) %s\n' "$n" "$label"
  done
}

# _menu_ids_to_nums "id id": converts ids to the numbers shown (for hints)
_menu_ids_to_nums() {
  local want=" $1 " i out=()
  for i in "${!_MENU_IDS[@]}"; do
    case "$want" in *" ${_MENU_IDS[i]} "*) out+=("$i") ;; esac
  done
  printf '%s' "${out[*]}"
}

# menu_one VAR "Title" DEFAULT_ID ENTRIES...
menu_one() {
  local -n __out="$1"; local title="$2" def="$3"; shift 3
  local sel defnum
  printf '\n%s\n' "$title"
  _menu_print "$@"
  defnum="$(_menu_ids_to_nums "$def")"
  while :; do
    _readline sel "  Choice${defnum:+ [$defnum]}: "
    sel="${sel:-$defnum}"
    if [[ "$sel" =~ ^[0-9]+$ ]] && [ -n "${_MENU_IDS[sel]:-}" ]; then
      __out="${_MENU_IDS[sel]}"
      return 0
    fi
    warn "Pick one number from the list."
  done
}

# menu_many ARRAYVAR "Title" "DEFAULT IDS" ENTRIES...
#   input: "1 3 5", ranges "2-6", "a" = all, "-" = none, Enter = defaults
menu_many() {
  local -n __arr="$1"; local title="$2" defs="$3"; shift 3
  local sel tok a b i ok defnums
  local -A seen
  printf '\n%s\n' "$title"
  _menu_print "$@"
  defnums="$(_menu_ids_to_nums "$defs")"
  printf '   %s(numbers/ranges like "1 3 5-7", a = all, - = none, Enter = %s)%s\n' \
    "$C_D" "${defnums:-none}" "$C_RST"
  while :; do
    _readline sel "  Selection: "
    [ -z "$sel" ] && sel="${defnums:--}"
    __arr=() ; seen=() ; ok=1
    case "$sel" in
      a|A|all) for i in "${!_MENU_IDS[@]}"; do __arr+=("${_MENU_IDS[i]}"); done; return 0 ;;
      -|none)  return 0 ;;
    esac
    for tok in ${sel//,/ }; do
      if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        a=${BASH_REMATCH[1]} b=${BASH_REMATCH[2]}
      elif [[ "$tok" =~ ^[0-9]+$ ]]; then
        a=$tok b=$tok
      else
        ok=0; break
      fi
      for ((i = a; i <= b; i++)); do
        if [ -z "${_MENU_IDS[i]:-}" ]; then ok=0; break 2; fi
        [ -n "${seen[$i]:-}" ] && continue
        seen[$i]=1
        __arr+=("${_MENU_IDS[i]}")
      done
    done
    [ "$ok" = 1 ] && return 0
    warn "Invalid selection, try again."
  done
}
