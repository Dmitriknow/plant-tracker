#!/bin/sh
# Проверка на ключи и пароли. Ничего не меняет: только читает и говорит.
# Использование:
#   bash checks/scan-keys.sh [папка]            – папка (по умолчанию текущая); в git – то, что git не исключает
#   bash checks/scan-keys.sh --staged [папка]   – то, что уходит в коммит; так же работает хуком pre-commit
#   bash checks/scan-keys.sh --history [папка]  – вся история git: перед выкладкой
# Выход: 0 – чисто (или проверить не удалось – об этом сказано прямо); 1 – похоже на секреты.
# Сломанная проверка не блокирует работу: любая внутренняя ошибка – это выход 0.

mode=folder
case "$1" in
  --staged) mode=staged; shift ;;
  --history) mode=history; shift ;;
esac
case "$(basename "$0")" in pre-commit) mode=staged ;; esac

dir="${1:-.}"
dir="${dir%/}"
[ -n "$dir" ] || dir=/

if [ ! -d "$dir" ]; then
  echo "Проверить не удалось: папки $dir нет. Работу это не блокирует."
  exit 0
fi

# Узнаваемые ключи: Anthropic; OpenAI (и проектные sk-proj-), OpenRouter; Stripe; ElevenLabs;
# токен Telegram-бота; AWS; Google и Google OAuth; GitHub; Slack; Groq; HuggingFace; Replicate; xAI;
# Supabase; вебхуки; Notion; Resend; адрес с паролем; пароль строкой;
# приватный ключ (PRIV[A]TE – чтобы сканер коммитов не принял сам шаблон за ключ).
keys='sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{20,}|sk-(proj|svcacct|admin|or-v1)-[A-Za-z0-9_-]{20,}'
keys="$keys"'|(sk|rk)_(live|test)_[A-Za-z0-9]{20,}|sk_[A-Za-z0-9]{40,}|(^|[^0-9])[0-9]{8,10}:[A-Za-z0-9_-]{35}'
keys="$keys"'|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|GOCSPX-[A-Za-z0-9_-]{20,}'
keys="$keys"'|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[0-9A-Za-z-]{10,}'
keys="$keys"'|gsk_[A-Za-z0-9]{40,}|hf_[A-Za-z0-9]{30,}|r8_[A-Za-z0-9]{30,}|xai-[A-Za-z0-9]{40,}'
keys="$keys"'|sb_secret_[A-Za-z0-9_-]{20,}|whsec_[A-Za-z0-9+/=]{24,}|ntn_[A-Za-z0-9]{40,}|re_[A-Za-z0-9]{8}_[A-Za-z0-9]{20,}'
keys="$keys""|[a-z][a-z0-9+.-]*://[^:/ \"'@]*:[^@/ \"'\$<{}*]{3,}@"
keys="$keys""|[Pp][Aa][Ss][Ss][Ww][Oo]?[Rr]?[Dd][\"']?[[:space:]]*[:=][[:space:]]*[\"'][^\"'\$<{}*[:space:]]{6,}[\"']"
keys="$keys"'|-----BEGIN [A-Z ]*PRIV[A]TE KEY'
# Заглушки и примеры из документации: xxxx, ***, EXAMPLE, USER:PASSWORD@; пароль без единой цифры – подпись в интерфейсе.
fake="[xX]{4,}|[*]{3,}|EXAMPLE|:(PASSWORD|PASS|[Pp]ass|[Pp]assword|[Yy]our[-_A-Za-z]*|changeme|secret)@|[Pp][Aa][Ss][Ss][Ww][Oo]?[Rr]?[Dd][\"']?[[:space:]]*[:=][[:space:]]*[\"'][^0-9]*[\"']\$"

# stdin – текст файла; stdout – до трёх номеров строк с похожим на настоящий ключ, через запятую
real_lines() {
  grep -nEI "$keys" 2>/dev/null | while IFS= read -r l; do
    if printf '%s\n' "${l#*:}" | grep -oE "$keys" | grep -vqE "$fake"; then
      printf '%s\n' "${l%%:*}"
    fi
  done | head -3 | tr '\n' ',' | sed 's/,$//'
}

skip_binary() {
  case "$1" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.pdf|*.zip|*.woff|*.woff2|*.ttf|*.otf|*.mp4|*.mov|*.mp3|*.sqlite|*.db) return 0 ;;
  esac
  return 1
}

is_env() {
  case "$(basename "$1")" in .env|.env.*) return 0 ;; esac
  return 1
}

say_hits() {  # say_hits <заголовок> <список>
  echo "$1"
  printf '%s' "$2"
  echo "Значения не показываю специально. Настоящий ключ – убери и смени его в сервисе. Это пример или заглушка – замени значение на xxxx или на имя переменной (${DB_PASSWORD})."
  echo "Ложное срабатывание – покажи человеку файл и строку без значения; обходить проверку решает он."
}

hits=""
envs=""
IFS='
'

if [ "$mode" = staged ] || [ "$mode" = history ]; then
  if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Проверить не удалось: в $dir нет git. Работу это не блокирует."
    exit 0
  fi
fi

if [ "$mode" = staged ]; then
  for f in $(git -C "$dir" -c core.quotepath=off diff --cached --name-only --diff-filter=ACMR 2>/dev/null); do
    skip_binary "$f" && continue
    if is_env "$f"; then envs="$envs$f
"; continue; fi
    n=$(git -C "$dir" show ":$f" 2>/dev/null | real_lines)
    [ -n "$n" ] && hits="$hits$f  строки: $n
"
  done
  if [ -n "$envs" ]; then
    echo "В коммит идёт файл с секретами:"
    printf '%s' "$envs"
    echo "Убери его из коммита (git rm --cached <файл>) и добавь .env и .env.* в .gitignore проекта. Значения не показываю."
    exit 1
  fi
  if [ -n "$hits" ]; then
    say_hits "В коммит идут строки, похожие на ключи и пароли:" "$hits"
    exit 1
  fi
  echo "Секретов в коммите не нашлось."
  exit 0
fi

if [ "$mode" = history ]; then
  revs=$(git -C "$dir" rev-list --all 2>/dev/null)
  if [ -z "$revs" ]; then echo "Коммитов нет – в истории чисто."; exit 0; fi
  for f in $(git -C "$dir" -c core.quotepath=off log --all --name-only --format= 2>/dev/null | sort -u); do
    is_env "$f" && envs="$envs$f
"
  done
  # коммиты – пачками по 200: все номера сразу не влезают в одну команду (Windows – уже после ~800)
  grep_batch() {
    [ -n "$batch" ] || return 0
    # shellcheck disable=SC2086
    out=$(git -C "$dir" -c core.quotepath=off grep -IlE "$keys" $batch -- 2>/dev/null)
    [ $? -gt 1 ] && return 1
    for hit in $out; do
      rev=${hit%%:*}; f=${hit#*:}
      git -C "$dir" show "$rev:$f" 2>/dev/null | real_lines | grep -q . && hits="$hits$f
"
    done
    batch=""; count=0
  }
  batch=""; count=0
  for rev in $revs; do
    batch="$batch$rev
"; count=$((count + 1))
    if [ "$count" -ge 200 ]; then
      grep_batch || { echo "Проверить историю не удалось. Работу это не блокирует – скажи человеку как есть."; exit 0; }
    fi
  done
  grep_batch || { echo "Проверить историю не удалось. Работу это не блокирует – скажи человеку как есть."; exit 0; }
  [ -n "$hits" ] && hits=$(printf '%s' "$hits" | sort | uniq -c | sed 's/^ *\([0-9]*\) \(.*\)$/\2  (в коммитах: \1)/')
  [ -n "$hits" ] && hits="$hits
"
  if [ -n "$hits" ] || [ -n "$envs" ]; then
    [ -n "$envs" ] && { echo "В истории git есть файлы с секретами:"; printf '%s' "$envs" | sort -u; }
    [ -n "$hits" ] && { echo "В истории git есть файлы со строками, похожими на ключи и пароли:"; printf '%s' "$hits"; }
    echo "Значения не показываю. Настоящий ключ – смени его в сервисе. Историю git с ним не выкладывай (GitHub, Pages): выкладывай собранную папку страницы без .git или скажи человеку – решает он."
    exit 1
  fi
  echo "В истории git секретов не нашлось."
  exit 0
fi

# папка: в git – то, что git не исключает; вне git или исключённая папка, названная прямо, – все файлы
files=""
if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  files=$(cd "$dir" && git -c core.quotepath=off ls-files -co --exclude-standard 2>/dev/null | sed "s|^|$dir/|")
fi
if [ -z "$files" ]; then
  if ! files=$(find -H "$dir" -mindepth 1 \
    \( -name .git -o -name node_modules -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o \
    -type f -print 2>/dev/null); then
    echo "Проверить не удалось: папка не обошлась целиком. Работу это не блокирует – скажи человеку как есть."
    exit 0
  fi
  ingit=no
else
  ingit=yes
fi

for f in $files; do
  [ -f "$f" ] || continue
  skip_binary "$f" && continue
  if is_env "$f"; then envs="$envs$f
"; continue; fi
  n=$(real_lines < "$f")
  [ -n "$n" ] && hits="$hits$f  строки: $n
"
done
IFS=' '

if [ -n "$hits" ]; then
  say_hits "Похоже на ключи и пароли в файлах:" "$hits"
  exit 1
fi

if [ -n "$envs" ]; then
  if [ "$ingit" = yes ]; then
    echo "Есть файлы с секретами, и git их не исключает:"
    printf '%s' "$envs"
    echo "Добавь .env и .env.* в .gitignore проекта – и повтори. Значения не показываю."
    exit 1
  fi
  echo "Есть файлы с секретами (git в папке нет – в коммит они не попадут):"
  printf '%s' "$envs"
fi
echo "Секретов не нашлось."
exit 0
