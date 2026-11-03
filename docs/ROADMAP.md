# Roadmap

Где проект сейчас и что дальше. Когда появятся GitHub Issues и milestones,
крупные пункты переедут туда, а здесь останутся ссылки.

## Запуск проекта

- [x] **1. Идея и границы** — `docs/VISION.md`.
- [ ] **2. Каркас репозитория** — папка аддона, `CLAUDE.md`, `CHANGELOG.md`,
  `docs/DEVELOPMENT.md`.
  - [ ] Подключить аддон к Retail и Forever (junction, см. `docs/DEVELOPMENT.md`)
    и проверить, что `/retis` печатает версию.
  - [ ] Сверить `## Interface` в `.toc` с `/dump select(4, GetBuildInfo())`
    в каждом клиенте.
- [ ] **3. Бэклог в GitHub Issues** — метки `bug`, `feature`, `idea`,
  `needs-ingame-test`; milestone `v0.1.0`; задачи из VISION.md.
  Для работы из Claude нужен GitHub CLI (`gh`).
- [ ] **4. Архитектура ядра** — модули эффектов, события, SavedVariables
  с версией схемы и миграциями.
- [ ] **5. Первая функция целиком** — код, проверка в игре, тег, релиз.
  Дальше по той же схеме: одна функция — одна ветка и PR — запись в CHANGELOG.

## Инструменты (по мере надобности)

- [ ] Lua 5.1, luacheck, StyLua, GitHub CLI (`gh`).
- [ ] VS Code: расширения Lua (sumneko) и WoW API (Ketho).
- [ ] GitHub Actions: luacheck на каждый push; BigWigs packager для CurseForge.
- [ ] Лицензия — до публикации на CurseForge.

## Версия 0.1.0

Состав и критерии готовности — в `docs/VISION.md`.
