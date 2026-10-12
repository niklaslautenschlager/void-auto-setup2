# shellcheck shell=bash
# lib/common.sh: logging, error handling, dry-run aware execution, file helpers.
#
# Globals provided:
#   R        target root prefix ("" on a real system; a temp dir in tests)
#   DRY_RUN  1 = print what would be done, change nothing
#   LOG      log file path

: "${R:=}"
: "${DRY_RUN:=0}"
: "${LOG:=$R/var/log/void-postinstall.log}"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_RST=$'\033[0m' C_B=$'\033[1m' C_G=$'\033[1;32m' C_Bl=$'\033[1;34m'
  C_Y=$'\033[1;33m' C_R=$'\033[1;31m' C_D=$'\033[2m'
else
  C_RST='' C_B='' C_G='' C_Bl='' C_Y='' C_R='' C_D=''
fi

_log() { [ -n "${LOG_READY:-}" ] && printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; return 0; }
msg()  { printf '\n%s==>%s %s%s%s\n' "$C_G" "$C_RST" "$C_B" "$*" "$C_RST"; _log "==> $*"; }
info() { printf '%s  ->%s %s\n' "$C_Bl" "$C_RST" "$*"; _log "  -> $*"; }
warn() { printf '%s  !!%s %s\n' "$C_Y" "$C_RST" "$*" >&2; _log "  !! $*"; WARNINGS+=("$*"); }
die()  { printf '%sERROR:%s %s\n' "$C_R" "$C_RST" "$*" >&2; _log "ERROR: $*"; exit 1; }
dim()  { printf '%s%s%s\n' "$C_D" "$*" "$C_RST"; }

WARNINGS=()

log_init() {
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$(dirname "$LOG")"
  : >>"$LOG"
  LOG_READY=1
  _log "---- void-postinstall started (pid $$) ----"
}

# Unexpected failures: say where, keep the log, don't leave the user guessing.
on_err() {
  local rc=$? line=${1:-?} cmd=${2:-?}
  printf '\n%sFAILED%s (exit %s) at line %s: %s\n' "$C_R" "$C_RST" "$rc" "$line" "$cmd" >&2
  [ -n "${LOG_READY:-}" ] && printf 'Full log: %s\n' "$LOG" >&2
  _log "FAILED rc=$rc line=$line cmd=$cmd"
  exit "$rc"
}

# ---------------------------------------------------------------------------
# Execution
# ---------------------------------------------------------------------------
# run CMD...: execute (or print in dry-run). Output is mirrored into the log.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s  [dry-run]%s %s\n' "$C_D" "$C_RST" "$*"
    return 0
  fi
  _log "+ $*"
  if [ -n "${LOG_READY:-}" ]; then
    "$@" 2>&1 | tee -a "$LOG"
    return "${PIPESTATUS[0]}"
  fi
  "$@"
}

# ---------------------------------------------------------------------------
# Files (all paths are absolute, R is prepended here, not by callers)
# ---------------------------------------------------------------------------
# write_file PATH [MODE] < content
write_file() {
  local path="$R$1" mode="${2:-0644}"
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s  [dry-run]%s write %s (%s)\n' "$C_D" "$C_RST" "$1" "$mode"
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  cat >"$path.vpi-tmp"
  chmod "$mode" "$path.vpi-tmp"
  mv -f "$path.vpi-tmp" "$path"
  _log "wrote $1"
}

# install_file SRC DEST [MODE]: copy a file from the project into the system
install_file() {
  local src="$1" dest="$R$2" mode="${3:-0644}"
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s  [dry-run]%s install %s -> %s\n' "$C_D" "$C_RST" "${src#"$ROOT_DIR"/}" "$2"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  install -m "$mode" "$src" "$dest"
  _log "installed $2"
}

# symlink TARGET LINK: idempotent, replaces dangling or wrong links
symlink() {
  local target="$1" link="$R$2"
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s  [dry-run]%s ln -sfn %s %s\n' "$C_D" "$C_RST" "$target" "$2"
    return 0
  fi
  mkdir -p "$(dirname "$link")"
  ln -sfn "$target" "$link"
  _log "link $2 -> $target"
}

# remove_path PATH: rm -f a file or link (never directories)
remove_path() {
  local p="$R$1"
  [ -e "$p" ] || [ -L "$p" ] || return 0
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s  [dry-run]%s rm %s\n' "$C_D" "$C_RST" "$1"
    return 0
  fi
  rm -f "$p"
  _log "removed $1"
}

# in_list NEEDLE ITEM...: membership test
in_list() {
  local n="$1" x; shift
  for x in "$@"; do [ "$x" = "$n" ] && return 0; done
  return 1
}
