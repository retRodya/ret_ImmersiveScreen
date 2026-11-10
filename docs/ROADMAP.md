# Roadmap

Где проект сейчас и что дальше. Когда появятся GitHub Issues и milestones,
крупные пункты переедут туда, а здесь останутся ссылки.

## Запуск проекта

- [x] **1. Идея и границы** — `docs/VISION.md`.
- [ ] **2. Каркас репозитория** — папка аддона, `CLAUDE.md`, `CHANGELOG.md`,
  `docs/DEVELOPMENT.md`.
  - [x] Подключить аддон к Retail и Forever (junction, см. `docs/DEVELOPMENT.md`).
  - [x] Проверить в игре, что аддон загружается и `/retis` открывает окно (Forever).
  - [ ] Сверить `## Interface` в `.toc` с `/dump select(4, GetBuildInfo())`
    в каждом клиенте.
- [ ] **3. Бэклог в GitHub Issues** — метки `bug`, `feature`, `idea`,
  `needs-ingame-test`; milestone `v0.1.0`; задачи из VISION.md.
  Для работы из Claude нужен GitHub CLI (`gh`).
- [ ] **4. Архитектура ядра** — модули эффектов, события, SavedVariables
  с версией схемы и миграциями. Описание — `docs/ARCHITECTURE.md`.
  - [x] Окно настроек как в ret_TweaksLite: General, Effects, Lens, LiteRP,
    заглушки CameraShift, FOV, GoOffline, GoOnline.
  - [x] Реестр модулей и страниц, настройки с откатом, схема SavedVariables.
  - [x] Клавиши эффектов и Combined Lens, General → Hide screenshot message.
  - [x] Проверка окна и клавиш в Forever.
  - [ ] Проверка окна в Retail.
- [ ] **5. Эффекты 0.1.0** — по одному, с проверкой в игре после каждого:
  - [x] HideUI: скрытие интерфейса как Alt+Z и имён по чекбоксам, пошаговая
    запись CVar, возврат после выхода и `/reload` (проверено в Forever).
  - [x] Letterbox: полосы, высота, анимация (проверено в Forever).
  - [x] Esc: первый выключает все эффекты, второй открывает меню (Forever).
  - [x] CameraShift: плавный сдвиг камеры, своя клавиша (проверено в Forever).
  - [x] FOV: плавная смена угла обзора, своя клавиша (проверено в Forever).
  - [x] GoOffline: полосы во время отсчёта выхода (проверено в Forever вне боя).
    Скрытие интерфейса, прозрачность полос и чат — позже.
  - [x] GoOnline: полосы раскрываются и исчезают после входа, кнопки Test
    и Defaults (проверено в Forever).
  - [ ] Проверка эффектов в Retail.
- [ ] **6. Первый релиз** — чек-лист, тег, архив (см. `docs/DEVELOPMENT.md`).
  Дальше по той же схеме: одна функция — одна ветка и PR — запись в CHANGELOG.

## Инструменты (по мере надобности)

- [ ] Lua 5.1, luacheck, StyLua, GitHub CLI (`gh`).
- [ ] VS Code: расширения Lua (sumneko) и WoW API (Ketho).
- [ ] GitHub Actions: luacheck на каждый push; BigWigs packager для CurseForge.
- [ ] Лицензия — до публикации на CurseForge.

## Версия 0.1.0

Состав и критерии готовности — в `docs/VISION.md`.
