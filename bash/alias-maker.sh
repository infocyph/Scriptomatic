#!/usr/bin/env bash
set -euo pipefail

BASHRC="${HOME:-/root}/.bashrc"

line_in_file() { grep -qF "$1" "$2" 2>/dev/null; }
append_if_missing() {
  local line="$1"
  line_in_file "$line" "$BASHRC" || echo "$line" >>"$BASHRC"
}
block_in_file() { grep -qF "$1" "$BASHRC" 2>/dev/null; }
append_block_if_missing() {
  local marker="$1"
  local content="$2"
  block_in_file "$marker" || printf "\n%s\n" "$content" >>"$BASHRC"
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
  'alias gfixeol="d2u"'
  'alias d2u="git diff --name-only -z | xargs -0 dos2unix"'
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
FUNCTION_BLOCK_CONTENT=$'# >>> scriptomatic-utils >>>\n# Convert line endings of changed files in current git repo.\ngit_fix_eol() {\n  command -v dos2unix >/dev/null 2>&1 || {\n    echo "dos2unix is not installed."\n    return 1\n  }\n\n  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {\n    echo "Not inside a git repository."\n    return 1\n  }\n\n  local files\n  files="$(git diff --name-only)"\n  if [[ -z "$files" ]]; then\n    echo "No changed files to convert."\n    return 0\n  fi\n\n  git diff --name-only -z | xargs -0 dos2unix\n}\n\n# Delete merged local branches except protected ones.\ngit_clean_merged_branches() {\n  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {\n    echo "Not inside a git repository."\n    return 1\n  }\n\n  local deleted=0\n  local branch\n  while IFS= read -r branch; do\n    [[ -z "$branch" ]] && continue\n    case "$branch" in\n      main|master|develop) continue ;;\n    esac\n\n    if git branch -d "$branch"; then\n      deleted=1\n    fi\n  done < <(git branch --merged | sed \'s/^[* ]*//\')\n\n  [[ "$deleted" -eq 1 ]] || echo "No merged branches to delete."\n}\n\n# Create a directory and cd into it.\nmkcd() {\n  [[ $# -eq 1 ]] || {\n    echo "Usage: mkcd <dir>"\n    return 1\n  }\n\n  mkdir -p "$1" && cd "$1"\n}\n# <<< scriptomatic-utils <<<'
append_block_if_missing "$FUNCTION_BLOCK_MARKER" "$FUNCTION_BLOCK_CONTENT"

echo "Common aliases applied."
