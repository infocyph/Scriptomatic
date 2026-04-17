#!/usr/bin/env bash
set -euo pipefail

BASHRC="${HOME:-/root}/.bashrc"

line_in_file() { grep -qF "$1" "$2" 2>/dev/null; }
append_if_missing() {
  local line="$1"
  line_in_file "$line" "$BASHRC" || echo "$line" >>"$BASHRC"
}
block_in_file() { grep -qF "$1" "$BASHRC" 2>/dev/null; }
upsert_block() {
  local start_marker="$1"
  local end_marker="$2"
  local content="$3"
  local tmp_file

  if block_in_file "$start_marker"; then
    tmp_file="$(mktemp)" || {
      echo "Failed to create temp file."
      return 1
    }

    awk -v start="$start_marker" -v end="$end_marker" '
      $0 == start { in_block=1; next }
      in_block && $0 == end { in_block=0; next }
      !in_block { print }
    ' "$BASHRC" >"$tmp_file" && mv "$tmp_file" "$BASHRC"
  fi

  printf "\n%s\n" "$content" >>"$BASHRC"
}

mkdir -p "$(dirname "$BASHRC")"
touch "$BASHRC"

ALIASES=(
  # Navigation and listing
  'alias l="ls -CF"'
  'alias la="ls -A"'
  'alias ll="ls -alF"'
  'alias ..="cd .."'
  'alias ...="cd ../.."'
  'alias ....="cd ../../.."'
  'alias cls="clear"'
  'alias h="history"'
  'alias reload="source ~/.bashrc"'
  # Git shortcuts
  'alias g="git"'
  'alias ga="git add"'
  'alias gb="git branch"'
  'alias gc="git commit"'
  'alias gca="git commit --amend"'
  'alias gco="git checkout"'
  'alias gsw="git switch"'
  'alias gd="git diff"'
  'alias gfiles="git diff --name-only"'
  'alias gds="git diff --staged"'
  'alias gconflicts="git diff --name-only --diff-filter=U"'
  'alias glog="git log --oneline --graph --decorate -20"'
  'alias gl="git pull --rebase"'
  'alias gsync="git fetch --all --prune && git pull --rebase"'
  'alias gpf="git push --force-with-lease"'
  'alias gp="git push"'
  'alias gs="git status -sb"'
  'alias gunstage="git restore --staged"'
  'alias gwip="git add -A && git commit -m \"wip\""'
  'alias gundo="git reset --soft HEAD~1"'
  'alias gcleanbranches="git_clean_merged_branches"'
  'alias d2u="git_fix_eol"'
  'alias d2utree="convert_tree_eol"'
  # JS/PHP helpers
  'alias nrd="npm run dev"'
  'alias nrt="npm run test"'
  'alias cda="composer dump-autoload -o"'
  'alias art="php artisan"'
)

for alias_cmd in "${ALIASES[@]}"; do
  append_if_missing "$alias_cmd"
done

FUNCTION_BLOCK_MARKER='# >>> scriptomatic-utils >>>'
FUNCTION_BLOCK_END_MARKER='# <<< scriptomatic-utils <<<'
FUNCTION_BLOCK_CONTENT="$(cat <<'EOF'
# >>> scriptomatic-utils >>>
# Run dos2unix on a file, retrying with sudo when direct write is blocked.
dos2unix_maybe_sudo() {
  local file="$1"

  if [[ -w "$file" ]]; then
    dos2unix "$file" >/dev/null 2>&1
    return $?
  fi

  command -v sudo >/dev/null 2>&1 || return 1
  sudo dos2unix "$file" >/dev/null 2>&1
}

# Convert line endings of staged and unstaged files in current git repo.
git_fix_eol() {
  command -v dos2unix >/dev/null 2>&1 || {
    echo "dos2unix is not installed."
    return 1
  }

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Not inside a git repository."
    return 1
  }

  local -a files=()
  local -A seen=()
  local file

  while IFS= read -r -d '' file; do
    [[ -n "$file" && -f "$file" ]] || continue
    if [[ -z "${seen[$file]+x}" ]]; then
      files+=("$file")
      seen["$file"]=1
    fi
  done < <(
    git diff --name-only -z
    git diff --cached --name-only -z
  )

  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No staged or unstaged files to convert."
    return 0
  fi

  local converted=0
  local failed=0

  for file in "${files[@]}"; do
    if dos2unix_maybe_sudo "$file"; then
      converted=$((converted + 1))
    else
      echo "Failed to convert: $file"
      failed=1
    fi
  done

  echo "Converted $converted file(s)."
  [[ "$failed" -eq 0 ]]
}

# Convert files matching a glob pattern while skipping dependency and hidden directories.
convert_tree_eol() {
  command -v dos2unix >/dev/null 2>&1 || {
    echo "dos2unix is not installed."
    return 1
  }

  local pattern="${1:-*.php}"
  local file
  local converted=0
  local failed=0

  while IFS= read -r -d '' file; do
    if dos2unix_maybe_sudo "$file"; then
      converted=$((converted + 1))
    else
      echo "Failed to convert: $file"
      failed=1
    fi
  done < <(find . \( -type d \( -name 'vendor' -o -name 'node_modules' -o \( -name '.*' ! -path '.' \) \) \) -prune -o -name "$pattern" -type f -print0)

  echo "Converted $converted file(s) (skipped vendor/node_modules and hidden dirs)."
  [[ "$failed" -eq 0 ]]
}

# Delete merged local branches except protected ones.
git_clean_merged_branches() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Not inside a git repository."
    return 1
  }

  local deleted=0
  local branch
  while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    case "$branch" in
      main|master|develop) continue ;;
    esac

    if git branch -d "$branch"; then
      deleted=1
    fi
  done < <(git branch --merged | sed 's/^[* ]*//')

  [[ "$deleted" -eq 1 ]] || echo "No merged branches to delete."
}

# Create a directory and cd into it.
mkcd() {
  [[ $# -eq 1 ]] || {
    echo "Usage: mkcd <dir>"
    return 1
  }

  mkdir -p "$1" && cd "$1"
}
# <<< scriptomatic-utils <<<
EOF
)"
upsert_block "$FUNCTION_BLOCK_MARKER" "$FUNCTION_BLOCK_END_MARKER" "$FUNCTION_BLOCK_CONTENT"

echo "Common aliases applied."
