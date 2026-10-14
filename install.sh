#!/usr/bin/env bash
# Symlink every skill in this repository into ~/.claude/skills, so a `git pull` updates them all
# and there is nothing to reinstall.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

mkdir -p "$target"

linked=0
for skill in "$repo"/skills/*/; do
  [ -f "$skill/SKILL.md" ] || { echo "skipping $(basename "$skill") — no SKILL.md" >&2; continue; }

  name="$(basename "$skill")"
  link="$target/$name"

  if [ -L "$link" ]; then
    rm "$link"
  elif [ -e "$link" ]; then
    echo "refusing to replace $link — it exists and is not a symlink" >&2
    exit 1
  fi

  ln -s "${skill%/}" "$link"
  echo "linked $name"
  linked=$((linked + 1))
done

echo
echo "$linked skill(s) linked into $target"
echo "Start a new Claude Code session to pick them up."
