#!/bin/sh
# Кладёт ключ в project/.env так, чтобы его не увидел никто: ни агент, ни экран, ни история команд.
# Запускает человек сам, в отдельном окне Терминала; агент даёт команду с полным путём:
#   sh "/путь/к/папке набора/checks/put-key.sh" OPENAI_API_KEY
# Ввод скрыт. Строка с этим именем в project/.env заменяется (или добавляется), права – только тебе.
# Печатает только имя и длину ключа.

name="$1"
case "$name" in
  ''|*[!A-Za-z0-9_]*) echo "Укажи имя ключа латиницей, например: sh checks/put-key.sh OPENAI_API_KEY"; exit 1 ;;
esac

# только руками человека: из трубы или из окна агента ключ попал бы в историю команд
if [ ! -t 0 ]; then
  echo "Запусти эту команду сам, в окне Терминала, и вставь ключ туда."
  exit 1
fi

cd "$(dirname "$0")/.." || exit 1
mkdir -p project
env=project/.env
tmp=project/.env.tmp.$$

old=$(stty -g)
trap 'stty "$old"; rm -f "$tmp"; echo; echo "Отменено – ничего не записал."; exit 130' INT TERM HUP
printf 'Вставь %s и нажми Enter (на экране ничего не появится): ' "$name"
stty -echo
IFS= read -r val
stty "$old"
echo

# пробелы по краям и кавычки, если ключ скопировали вместе с ними
val=$(printf '%s' "$val" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^["'\'']//' -e 's/["'\'']$//')
if [ -z "$val" ]; then
  echo "Пусто – ничего не записал. Скопируй ключ ещё раз и повтори."
  exit 1
fi

if [ -s "$env" ] && ! grep -Iq . "$env"; then
  echo "project/.env не похож на текстовый файл – не трогаю его. Скажи агенту, он разберётся."
  exit 1
fi

umask 077
if [ -f "$env" ]; then grep -av "^$name=" "$env" > "$tmp" || true; else : > "$tmp"; fi
# у последней строки может не быть перевода строки – иначе ключ приклеится к ней
if [ -s "$tmp" ] && [ "$(tail -c1 "$tmp")" != "" ]; then echo >> "$tmp"; fi
printf '%s=%s\n' "$name" "$val" >> "$tmp"
mv "$tmp" "$env"
chmod 600 "$env"
trap - INT TERM HUP

# .env не должен уехать в git проекта; в подключённом проекте его файлы не правим
if [ -L project ]; then
  if ! git -C project check-ignore -q .env 2>/dev/null; then
    echo "В .gitignore твоего проекта нет .env – скажи агенту, добавлять или нет."
  fi
elif [ -f project/.gitignore ] && ! grep -qx '.env' project/.gitignore; then
  if [ -s project/.gitignore ] && [ "$(tail -c1 project/.gitignore)" != "" ]; then echo >> project/.gitignore; fi
  printf '.env\n' >> project/.gitignore
fi

echo "$name записан в project/.env, длина – ${#val}. Скажи агенту: «положил ключ»."
