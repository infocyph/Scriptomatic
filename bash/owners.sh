#!/bin/bash

if ! test -d "./.git"; then
  echo "Error: Not a git repository!" >&2
  exit 1
fi

# git fame owner generator
for f in $(git ls-files); do
  # filename
  echo -n "$f "
  # author emails if loc distribution >= 30%
  git fame -esnwMC --incl "$f" | tr '/' '|' \
    | awk -F '|' '(NR>6 && $6>=30) {print $2}' \
    | xargs echo
done
