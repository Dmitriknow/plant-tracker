#!/bin/sh
# Скиллы живут в трёх папках – по одной на семейство агентов:
#   .claude/skills/   – Claude Code и источник истины
#   .agents/skills/   – Codex, Cursor, Antigravity (открытый стандарт Agent Skills)
#   .opencode/skill/  – opencode
# Скрипт копирует каждый скилл из .claude/skills в две другие папки (одноимённую папку заменяет целиком).
# Скиллы, которые есть только в .agents/skills или .opencode/skill (ты ставил их своему агенту), не трогает.
# --check – сверка для разработки набора: расхождения и лишние скиллы.
# Использование: sh checks/sync-skills.sh [--check]
set -e
cd "$(dirname "$0")/.."
check=0
[ "$1" = "--check" ] && check=1
fail=0
count=0

for src in .claude/skills/*/SKILL.md; do
  [ -f "$src" ] || continue
  count=$((count + 1))
  name=$(basename "$(dirname "$src")")
  for dest in ".agents/skills/$name" ".opencode/skill/$name"; do
    if [ "$check" = 1 ]; then
      if ! diff -r ".claude/skills/$name" "$dest" >/dev/null 2>&1; then
        echo "расходится: $dest"
        fail=1
      fi
    else
      rm -rf "$dest"
      mkdir -p "$dest"
      cp -R ".claude/skills/$name/." "$dest/"
    fi
  done
done

if [ "$count" = 0 ]; then
  echo "нечего сверять: .claude/skills пуст или отсутствует"
  exit 1
fi

for root in .agents/skills .opencode/skill; do
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    name=${d%/}
    name=${name##*/}
    if [ ! -f ".claude/skills/$name/SKILL.md" ]; then
      if [ "$check" = 1 ]; then
        echo "лишний скилл: ${d%/}"
        fail=1
      else
        echo "есть только в ${d%/} – не трогаю"
      fi
    fi
  done
done

if [ "$check" = 1 ]; then
  [ "$fail" = 0 ] && echo "скиллы синхронны"
  exit "$fail"
fi
echo "скиллы синхронизированы в .agents/skills и .opencode/skill"
