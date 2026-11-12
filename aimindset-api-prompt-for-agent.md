# Промпт для подключения агента к порталу AI Mindset Lab (F26 Fall Lab)

> Замени `__AIM_API_KEY__` на реальный ключ и скорми этот промпт агенту. Всё остальное агент сделает сам.

---

Ты подключаешься к порталу AI Mindset Lab (Fall '26) через REST API. Читай данные лаборатории: сессии, транскрипты и чаты.

## Данные для подключения

- **API URL:** `https://learn.aimindset.org/api/v1`
- **API ключ:** `__AIM_API_KEY__`
- **Срок действия ключа:** до 2027-02-07
- **Права:** sessions:read, transcripts:read, chats:read (только лаборатория f26)

## Как делать запросы

Добавляй заголовок:
```
Authorization: Bearer __AIM_API_KEY__
Accept: application/json
```

Python (urllib, без доп библиотек):
```python
import urllib.request, json

KEY = "__AIM_API_KEY__"
BASE = "https://learn.aimindset.org/api/v1"
HEADERS = {"Authorization": f"Bearer {KEY}", "Accept": "application/json"}

def get(path):
    req = urllib.request.Request(BASE + path, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode())
```

curl:
```bash
curl -H "Authorization: Bearer __AIM_API_KEY__" \
  https://learn.aimindset.org/api/v1/sessions
```

## Эндпоинты

| Метод | Путь | Что возвращает |
|-------|------|---------------|
| GET | `/me` | Инфо токена: user_id, scopes, effective_labs, expires_at |
| GET | `/sessions` | Все сессии лаборатории |
| GET | `/sessions/{id}` | Деталь сессии: id, title, date, type, speaker, summary |
| GET | `/sessions/{id}/transcript` | Транскрипт с таймкодами (ключ `transcript_md`) |
| GET | `/sessions/{id}/chat` | Чат сессии (ключ `chat_md`) |

## Формат данных

**Сессия:** только дата (без времени). summary — не у всех. Типы:
- `workshops` — воркшопы (пн) · `cowork` — коворкинг (вт) · `track` — трек (ср)
- `guest` — гость (пт) · `office-hours` — разбор (сб) · `demo-day` — финал

**Транскрипт:** `transcript_md` — текст с таймкодами `[MM:SS]` от начала записи, ~70K символов

**Чат:** `chat_md` — строки `таймстамп\tИмя:\tСообщение`, таймстампы от начала записи

## Типовой сценарий

1. `GET /me` — проверь, что ключ работает и видны права
2. `GET /sessions` — получи всё расписание
3. `GET /sessions/{id}/transcript` — транскрипт конкретной сессии
4. `GET /sessions/{id}/chat` — чат к ней

## Важно
- API отдаёт только дату, без времени сессий.
- Публичная страница портала за Cloudflare JS — не парсь, используй REST API.
- Ключ — чувствительные данные: не выводи в ответы, не сохраняй в логи, не отправляй третьим лицам. Используй переменную окружения или файл с ограниченным доступом.