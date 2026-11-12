#!/bin/sh
# Ворота «план до кода»: агент не правит файлы project/, пока в PLAN.md нет строки **Утверждён:**.
# Запускается сам: Claude Code – из .claude/settings.json, Codex – из .codex/hooks.json.
# Разрешено и до плана: project/docs/, project/.aim/, project/.git/, project/.gitignore.
# Запись через команды терминала эти ворота не ловят: для них остаётся правило 2 в AGENTS.md.
# Не разобрал вход – пропускает: сломанные ворота работу не останавливают.

root=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd -P) || exit 0
grep -q '^\*\*Утверждён:\*\*' "$root/PLAN.md" 2>/dev/null && exit 0

# вход – JSON одной строкой; обратные косые Windows приводим к прямым
input=$(tr '\n' ' ' | sed 's#\\\\#/#g')
[ -n "$input" ] || exit 0

field() { printf '%s' "$input" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"; }

cwd=$(field cwd)
real=""
[ -e "$root/project" ] && real=$(cd "$root/project" 2>/dev/null && pwd -P)

paths="$(field file_path)
$(field notebook_path)"
# Codex: правки приходят патчем, пути – в строках «*** Add File: …»
patch=$(printf '%s' "$input" | grep -oE '\*\*\* ((Add|Update|Delete) File|Move to): [^\\"]*' | sed -E 's/^\*\*\* ((Add|Update|Delete) File|Move to): //')
paths="$paths
$patch"

blocked=""
old_ifs=$IFS; IFS='
'
for p in $paths; do
  [ -n "$p" ] || continue
  case "$p" in
    /*|[A-Za-z]:/*) abs=$p ;;
    *) abs="${cwd:-$root}/$p" ;;
  esac
  abs=$(printf '%s' "$abs" | sed 's#/\./#/#g')
  rel=""
  for base in "$root/project" "$cwd/project" "/private$cwd/project" "$real"; do
    [ "$base" = "/project" ] && continue
    [ -n "$base" ] || continue
    case "$abs" in
      "$base"/*) rel=${abs#"$base"/}; break ;;
    esac
  done
  [ -n "$rel" ] || continue
  case "$rel" in
    *../*) blocked=$rel ;;
    docs/*|.aim/*|.git/*|.gitignore) ;;
    *) blocked=$rel ;;
  esac
done
IFS=$old_ifs

if [ -n "$blocked" ]; then
  echo "Ворота «план до кода»: в PLAN.md нет строки **Утверждён:**, поэтому project/$blocked не правим. Сначала план (скилл make-plan) и «поехали» человека. Ворота сняты только строкой, которую ты пишешь после его слова." >&2
  exit 2
fi
exit 0
