#!/usr/bin/env bash
set -Eeuo pipefail

BASHRC="${BASHRC:-${HOME:-/root}/.bashrc}"
ALIAS_START='# >>> scriptomatic-aliases >>>'
ALIAS_END='# <<< scriptomatic-aliases <<<'
FUNCTION_START='# >>> scriptomatic-utils >>>'
FUNCTION_END='# <<< scriptomatic-utils <<<'

fatal() {
  printf 'alias-maker: %s\n' "$*" >&2
  exit 1
}

managed_replace() {
  local start_marker="$1" end_marker="$2" content="$3"
  local dir tmp mode uid gid
  dir="$(dirname -- "$BASHRC")"
  mkdir -p -- "$dir"
  [[ -e "$BASHRC" ]] || : > "$BASHRC"
  [[ -f "$BASHRC" ]] || fatal "$BASHRC is not a regular file"

  mode="$(stat -c '%a' "$BASHRC")"
  uid="$(stat -c '%u' "$BASHRC")"
  gid="$(stat -c '%g' "$BASHRC")"
  tmp="$(mktemp "${dir}/.scriptomatic-bashrc.XXXXXX")"

  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skip=1; next }
    skip && $0 == end { skip=0; next }
    !skip { print }
  ' "$BASHRC" > "$tmp"

  # Normalize excessive trailing blank lines before appending our owned block.
  awk 'BEGIN { blank=0 } { lines[NR]=$0 } END { last=NR; while (last>0 && lines[last] == "") last--; for (i=1;i<=last;i++) print lines[i] }' "$tmp" > "${tmp}.normalized"
  mv -f -- "${tmp}.normalized" "$tmp"
  printf '\n%s\n' "$content" >> "$tmp"
  chmod "$mode" "$tmp"
  if [[ $EUID -eq 0 ]]; then
    chown "$uid:$gid" "$tmp"
  fi
  mv -f -- "$tmp" "$BASHRC"
}

if command -v lsd >/dev/null 2>&1; then
  LIST_ALIASES=$(cat <<'EOF_LSD'
alias l="lsd -l"
alias la="lsd -A"
alias lla="lsd -lA"
alias lt="lsd --tree"
alias ll="lsd -AlF"
EOF_LSD
)
else
  LIST_ALIASES=$(cat <<'EOF_LS'
alias l="ls -l"
alias la="ls -A"
alias lla="ls -lA"
alias lt="find . -maxdepth 2 -print"
alias ll="ls -AlF"
EOF_LS
)
fi

ALIAS_BLOCK=$(cat <<EOF_ALIASES
${ALIAS_START}
${LIST_ALIASES}
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias cls="clear"
alias h="history"
alias reload="source ~/.bashrc"
alias g="git"
alias ga="git add"
alias gb="git branch"
alias gc="git commit"
alias gca="git commit --amend"
alias gco="git checkout"
alias gsw="git switch"
alias gd="git diff"
alias gfiles="git diff --name-only"
alias gds="git diff --staged"
alias gconflicts="git diff --name-only --diff-filter=U"
alias glog="git log --oneline --graph --decorate -20"
alias gl="git pull --rebase"
alias gsync="git fetch --all --prune && git pull --rebase"
alias gpf="git push --force-with-lease"
alias gp="git push"
alias gs="git status -sb"
alias gunstage="git restore --staged"
alias gwip="git add -A && git commit -m \"wip\""
alias gundo="git reset --soft HEAD~1"
alias gcleanbranches="git_clean_merged_branches"
alias gscoff="git config --local core.safecrlf false"
alias d2u="git_fix_eol"
alias d2utree="convert_tree_eol"
alias nrd="npm run dev"
alias nrt="npm run test"
alias cda="composer dump-autoload -o"
alias art="php artisan"
${ALIAS_END}
EOF_ALIASES
)

FUNCTION_BLOCK=$(cat <<'EOF_FUNCTIONS'
# >>> scriptomatic-utils >>>
cleanup_dos2unix_tmp() {
  local file="$1" dir
  dir="$(dirname -- "$file")"
  find "$dir" -maxdepth 1 -type f -name 'd2utmp*' -exec rm -f -- {} + >/dev/null 2>&1 || true
}

dos2unix_file() {
  local file="$1"
  if [[ -w "$file" ]]; then
    dos2unix -- "$file" >/dev/null 2>&1 && return 0
  elif command -v sudo >/dev/null 2>&1; then
    sudo -- dos2unix -- "$file" >/dev/null 2>&1 && return 0
  else
    return 1
  fi
  cleanup_dos2unix_tmp "$file"
  return 1
}

git_fix_eol() {
  command -v dos2unix >/dev/null 2>&1 || { echo "dos2unix is not installed." >&2; return 1; }
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a git repository." >&2; return 1; }

  local -a files=()
  local -A seen=()
  local file converted=0 failed=0
  while IFS= read -r -d '' file; do
    [[ -n "$file" && -f "$file" ]] || continue
    if [[ -z "${seen[$file]+x}" ]]; then
      files+=("$file")
      seen["$file"]=1
    fi
  done < <(git diff --name-only -z; git diff --cached --name-only -z)

  if (( ${#files[@]} == 0 )); then
    echo "No staged or unstaged files to convert."
    return 0
  fi

  for file in "${files[@]}"; do
    if dos2unix_file "$file"; then
      ((converted+=1))
    else
      echo "Failed to convert: $file" >&2
      failed=1
    fi
  done
  echo "Converted $converted file(s)."
  (( failed == 0 ))
}

convert_tree_eol() {
  command -v dos2unix >/dev/null 2>&1 || { echo "dos2unix is not installed." >&2; return 1; }
  local pattern="${1:-*.php}" file converted=0 failed=0
  while IFS= read -r -d '' file; do
    if dos2unix_file "$file"; then
      ((converted+=1))
    else
      echo "Failed to convert: $file" >&2
      failed=1
    fi
  done < <(find . \( -type d \( -name vendor -o -name node_modules -o \( -name '.*' ! -path . \) \) \) -prune -o -name "$pattern" -type f -print0)
  echo "Converted $converted file(s) (skipped vendor/node_modules and hidden dirs)."
  (( failed == 0 ))
}

git_clean_merged_branches() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "Not inside a git repository." >&2; return 1; }
  local branch deleted=0
  while IFS= read -r branch; do
    [[ -n "$branch" ]] || continue
    case "$branch" in main|master|develop) continue ;; esac
    if git branch -d -- "$branch"; then
      deleted=1
    fi
  done < <(git for-each-ref --format='%(refname:short)' --merged HEAD refs/heads/)
  (( deleted == 1 )) || echo "No merged branches to delete."
}

mkcd() {
  [[ $# -eq 1 ]] || { echo "Usage: mkcd <dir>" >&2; return 1; }
  mkdir -p -- "$1" && cd -- "$1"
}
# <<< scriptomatic-utils <<<
EOF_FUNCTIONS
)

managed_replace "$ALIAS_START" "$ALIAS_END" "$ALIAS_BLOCK"
managed_replace "$FUNCTION_START" "$FUNCTION_END" "$FUNCTION_BLOCK"
printf 'Common aliases applied.\n'
