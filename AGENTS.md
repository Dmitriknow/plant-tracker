# AGENTS.md — Project Files

This file defines conventions for working with project files in `C:\Users\Dmitriknow_server\project\`.

## Purpose

The `project/` folder stores:
- Active project source files (code, HTML, configs)
- Scripts and tools (`project/scripts/`)
- Documentation and instructions for other agents

## Changelog rule (MANDATORY)

Every project stored here must have a corresponding wiki note at:
`Dmitriknow_brain/wiki/<domain>/<category>.<project-name>.md`

That wiki note **must** include a `## Changelog` section at the end. Each time the project file changes, add a dated entry:

```markdown
### YYYY-MM-DD — Brief title of change
- What changed
- Why
- Key technical details if relevant
```

Latest entry on top. The source file in `project/` is the primary artifact; the changelog records its evolution.

## File naming

- Use clean descriptive names, Latin alphabet
- No spaces, use hyphens: `plant-tracker.html`, `transcribe-voice.py`
- Date in filename only if versioned (rare — prefer changelog)

## Structure

```
project/
├── AGENTS.md              ← this file
├── scripts/               ← reusable scripts (vosk_transcribe.py, etc.)
├── <project-name>.html    ← project files at root level
├── <project-name>.md      ← instructions/prompts for other agents
└── ...
```

## Interaction

- User says "внеси правку в проект" → update file + update changelog in wiki note
- User says "создай новый проект" → create file + create `project.*` wiki note with changelog
- User says "что менялось в проекте" → read changelog section from wiki note

## Related

- `Dmitriknow_brain/AGENTS.md` — vault-level conventions
- `Dmitriknow_brain/_schema.md` — full naming category table