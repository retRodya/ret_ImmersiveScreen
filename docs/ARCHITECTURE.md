# Архитектура

Как устроено ядро и как добавить эффект или страницу. Что строим и почему —
в `docs/VISION.md`. Окно повторяет ret_TweaksLite: если меняешь общее поведение,
посмотри, как это сделано там.

## Файлы

Порядок загрузки задаёт `.toc`:

| Файл | Что делает |
| --- | --- |
| `Core.lua` | Метаданные из `.toc`, сохранённые настройки, реестр модулей и страниц, настройки с откатом, запуск после входа. |
| `CVars.lua` | Игровые настройки (CVar), которые эффект меняет на время: хранит исходные значения и возвращает их, в том числе после вылета. |
| `Widgets.lua` | Общие элементы: подсказка, кнопка отката, строка-чекбокс, строка-ползунок, кнопка клавиши. |
| `Window.lua` | Окно: список слева, страницы справа, кнопка Reload UI. |
| `Lens.lua` | Клавиши: какая клавиша включает какой эффект, Combined Lens. Обработчик для `Bindings.xml`. |
| `Bindings.xml` | Клавиши в родном «Назначении клавиш». Игра загружает файл сама, в `.toc` его нет. |
| `EntryPoints.lua` | Как открыть окно: `/retis`, `/retimmersivescreen`, Addon Compartment, страница в Settings → AddOns. |
| `Pages/<Page>.lua` | Страница списка, которая не модуль: General, Lens. |
| `Effects/<Effect>.lua` | Эффект: HideUI, Letterbox, CameraShift, FOV. |
| `LiteRP/<Feature>.lua` | Ролевая функция: GoOffline, GoOnline. |

Файлы общаются через `ns` — таблицу, которую WoW передаёт каждому файлу аддона.
Глобальные имена: `ret_ImmersiveScreenDB` (сохранённые настройки),
`RetImmersiveScreenFrame` (окно, имя нужно для закрытия по Esc),
`RetImmersiveScreen_OnAddonCompartmentClick` (имя из `.toc`),
`RetImmersiveScreen_OnBinding` (вызывают клавиши) и строки `BINDING_*`.

## Список окна

Список собирается из того, что зарегистрировано, в порядке файлов в `.toc`:
страница — отдельный пункт, модули одной `category` — группа. Внутри группы модули
тоже в порядке `.toc`. Страницы и группы жёлтые, модули белые, заглушки серые.

## Модуль

```lua
ns.RegisterModule({
    key = "Letterbox",          -- id и ключ в настройках; не менять
    category = "Effects",       -- группа в списке
    title = "Letterbox",
    description = "...",        -- подсказка и строка под заголовком страницы
    lens = true,                -- своя клавиша и место в Combined Lens
    enabledByDefault = true,
    combinedByDefault = true,
    settings = { ... },         -- см. «Настройки»
    -- section = "Stay",        -- заголовок на странице группы (LiteRP)
    -- placeholder = true,      -- заглушка: серая, ничего не делает, не сохраняет
    -- Start(module)                         один раз после входа, если включён
    -- OnSettingChanged(module, key, value)  настройка изменилась, пока он работает
    -- Activate(module), Deactivate(module)  клавиша включила или выключила эффект
})
```

- **Модуль включается и выключается только через `/reload`.** «Выбрано» —
  `ns.IsEnabled(key)`, «работает» — `ns.IsRunning(key)`. Как в ret_TweaksLite,
  страница модуля, который не работает, показывает «Check the box…» или
  «Type /reload…».
- **Настройки применяются сразу**: ядро вызывает `OnSettingChanged`.
- Модулю с `lens = true` ядро добавляет скрытую настройку `combined` —
  входит ли он в Combined Lens. Её показывает страница Lens.

## Страница

```lua
ns.RegisterPage({
    key = "General",
    title = "General",
    settings = { ... },            -- необязательно, как у модуля
    Create = function(page, frame) end,   -- заполняет страницу под заголовком
    -- Start(page), OnSettingChanged(page, key, value)
})
```

`Create` может задать `frame:Update()`: окно вызывает его после каждого изменения.
Страница работает всегда, с момента входа.

## Настройки

```lua
{ key = "height", type = "slider", title = "Bar height", description = "...",
  min = 1, max = 25, step = 0.5, default = 10, format = "%.1f%%" }
{ key = "hideScreenshotMessage", type = "checkbox", title = "...", description = "...",
  default = false }
```

- `ns.GetSetting(owner, key)`, `ns.SetSetting(owner, key, value)`. Владелец —
  ключ модуля или страницы.
- Откат: снимок значений при `ADDON_LOADED`, `ns.IsSettingChanged` сравнивает
  с ним, `ns.UndoSetting` возвращает. Кнопка отката видна у изменённых.
- Значение ползунка округляется до шага и трёх знаков, чтобы число, прочитанное
  из SavedVariables, совпадало с тем, что дал ползунок.
- `type = "heading"` — заголовок над строками, без значения. `IsShown` —
  функция: строка видна, только пока она возвращает true, остальные
  поднимаются. `indent` сдвигает строку вправо.
- Заглушки показывают значения по умолчанию и ничего не сохраняют.

## Клавиши (Lens)

- У эффекта с `lens = true` своя клавиша `RETIMMERSIVESCREEN_<KEY>`, у Combined
  Lens — `RETIMMERSIVESCREEN_COMBINEDLENS`. Новую клавишу нужно добавить
  в `Bindings.xml` и дать ей имя `BINDING_NAME_…` в `Lens.lua`.
- Эффект в Combined Lens своей клавишей не включается.
- **Esc.** Пока работает хоть один эффект, клавиши `TOGGLEGAMEMENU`
  переназначены на кнопку `RetImmersiveScreenEscapeButton`
  (`SetOverrideBindingClick`): первый Esc выключает все эффекты, переназначение
  снимается, следующий Esc открывает меню. Переназначения нельзя менять в бою:
  на `PLAYER_REGEN_DISABLED` (ещё можно) оно снимается, на `PLAYER_REGEN_ENABLED`
  ставится снова. В бою Esc работает как обычно, а хук
  `hooksecurefunc("ToggleGameMenu", …)` выключает эффекты. Кнопка и хук
  создаются при первом включении эффекта; события зарегистрированы, только
  пока работает эффект.
- **Не использовать `RegisterGameMenuEscHandler`** (`Blizzard_GameMenuEsc.lua`).
  Он сортирует общую таблицу обработчиков Esc (`table.sort`); вызванный
  из аддона, он заражает её, и игра запрещает защищённые вызовы следующих
  обработчиков: `[ADDON_ACTION_FORBIDDEN] … SpellStopCasting()`. Приоритет
  `AddOn` в нём — для аддонов Blizzard, не для сторонних.
- Состояние хранится по эффекту (`active`), а не по линзе. Клавиши только решают,
  что переключить. Поэтому смена набора Combined Lens не ломает состояние.
- Кнопка клавиши на странице Lens пишет в родные привязки игры (`SetBinding`,
  `SaveBindings`) и не работает в бою.
- Привязки в игре разделены по контекстам. `GetBindingKey`, `GetBindingAction`
  и `SetBinding` получают контекст действия из
  `C_KeyBindings.GetBindingContextForAction`, как в родном окне «Назначение
  клавиш» (`Blizzard_Keybindings.lua`). Без контекста клавиши не назначались.
- Кадр со скриптом `OnKeyDown` забирает себе клавиатуру, даже если
  `EnableKeyboard` не вызывали. Поэтому кнопка ставит `OnKeyDown` только
  на время ожидания клавиши и снимает его сразу после, как `KeybindListener`
  в `Blizzard_Keybindings.lua`. Когда скрипт стоял всегда, все кнопки страницы
  Lens ловили каждое нажатие и отвязывали клавиши, в том числе движение.
- Логика назначения повторяет родное окно: новая клавиша становится первой,
  вторая сохраняется; правый клик убирает первую, вторая встаёт на её место.
- Сообщения — родные строки игры, поэтому они на языке клиента:
  `SETTINGS_BIND_KEY_TO_COMMAND_OR_CANCEL` (ожидание), `KEY_BOUND` (готово),
  `KEY_UNBOUND_ERROR` и `PRIMARY_KEY_UNBOUND_ERROR` (клавиша отнята у другой
  команды), `ERR_NOT_IN_COMBAT` (бой).
- Кнопка отпускает клавиатуру до того, как назначает клавишу, а также когда
  она сама или окно скрываются.

## Эффекты

- `Activate` и `Deactivate` вызывает `Lens.lua`, когда клавиша включает
  или выключает эффект. Эффект создаёт свои кадры при первом `Activate`:
  пока клавишу не нажали, он ничего не стоит.
- **HideUI** делает то же, что привязка Alt+Z (`TOGGLEUI` в
  `Bindings_Standard.xml`): `securecall("CloseMenus")`,
  `securecall("CloseAllWindows")`, `SetUIVisibility(false)`; ничего, если
  `GetAppropriateTopLevelParent() ~= UIParent`. `RunBinding` вызвать нельзя:
  он защищён. При выключении интерфейс показывается, только если он всё ещё
  скрыт. Если интерфейс был скрыт Alt+Z до HideUI, он таким и остаётся.
- **Имена HideUI** — пункты раздела «Имена» настроек игры
  (`Blizzard_SettingsDefinitions_Frame/Nameplates.lua`, одинаково в Retail
  и Forever). Пункт виден на странице, только если игра сейчас его показывает:
  одна из его CVar не "0". Пока HideUI держит CVar выключенной, берётся
  исходное значение (`ns.GetOriginalCVar`). Прислужники зависят от игроков,
  как в настройках игры. Окно обновляется по `CVAR_UPDATE`, пока открыто.
  Отдельный пункт вне раздела — `UnitNameFocused`: имя цели, юнита под
  курсором и NPC, подсвеченного для взаимодействия.
- В Forever нет `C_Console`; проверить, есть ли CVar, можно через `GetCVar`
  (nil — нет).
- **Letterbox** — кадр без родителя, привязанный к `UIParent` через
  `SetAllPoints`: он закрывает тот же экран при любом масштабе интерфейса
  и не прячется вместе с ним. Слой `BACKGROUND`, под всеми панелями.
  Высота — процент высоты кадра, пересчёт на `OnSizeChanged`. `OnUpdate`
  стоит только пока полосы движутся. Прерванная анимация продолжается
  с текущей высоты, время пропорционально оставшемуся пути.

## Временные CVar

- `ns.SetTemporaryCVar(owner, name, value)` запоминает исходное значение
  и меняет CVar; `ns.RestoreCVars(owner)` возвращает. CVar, которой нет
  в клиенте (`GetCVar` вернул nil), пропускается.
- Запись идёт очередью, по одной CVar раз в `WRITE_INTERVAL` (0.1 с; `OnUpdate`,
  пока очередь не пуста): каждая запись заставляет игру пересчитать имена
  всех юнитов вокруг.
  Новое желание для той же CVar заменяет ждущее: выключение посреди скрытия
  отменяет ещё не записанное, исходное значение отпускается только после
  того, как записано обратно.
- На `PLAYER_LOGOUT` (выход и `/reload`) всё возвращается сразу, очередь
  очищается.
- SavedVariables пишутся только при чистом выходе, поэтому исходные значения
  сессии с вылетом теряются. На этот случай в `cvarBaseline` хранятся значения
  на момент последнего чистого выхода и значение, которое ставит аддон.
  При входе CVar, в которой осталось значение аддона, получает сохранённое.

## Сохранённые настройки

```lua
ret_ImmersiveScreenDB = {
    schemaVersion = 1,
    enabled = { Letterbox = false },                -- только то, что игрок менял
    settings = { Letterbox = { height = 12 }, General = { hideScreenshotMessage = true } },
    collapsed = { LiteRP = true },                  -- свёрнутые группы списка
    cvarBaseline = { UnitNameNPC = { value = "1", forced = "0" } },   -- CVars.lua
}
```

Настройки общие на аккаунт. Если структура меняется, `SCHEMA_VERSION` в `Core.lua`
растёт на 1, а в `migrations` появляется функция перевода старых данных.

## Находки об API

- Ползунок — `MinimalSliderWithSteppersTemplate`, как в окне Settings. Шаблон
  и его API одинаковые в Retail и Forever (Gethe/wow-ui-source, ветки `live`
  и `forever`). Свой `OnEnter` у ползунка ставится через `HookScript`: шаблон
  сам использует `OnEnter`, чтобы подсвечивать ползунок.
- Значение ползунок пишет справа от себя (`RightText`, +6 px от рамки шаблона),
  поэтому кнопка отката стоит дальше.
- Клавиша записывается через `CreateKeyChordStringUsingMetaKeyState`; нажатие
  одного модификатора пропускается по `IsKeyPressIgnoredForBinding`. Обе функции
  есть в обоих клиентах.
- Forever грузит интерфейс как mainline: в `.toc` аддонов Blizzard стоит
  `AllowLoadGameType: mainline`, поэтому многие шаблоны те же, что в Retail.
- Имена в Lorewalker (режим Immersive при разговоре с NPC,
  `Code/Dialog/CVars.lua`): тот же `SetCVar`, но всего три CVar —
  `UnitNameNPC`, `UnitNameFriendlyPlayerName`, `UnitNameEnemyPlayerName`.
  Не включается в бою, а при входе в бой (`PLAYER_REGEN_DISABLED`) и на
  `ADDONS_UNLOADING` (выход, `/reload`) возвращает значения.
- В окне настроек Forever (`Blizzard_SettingsDefinitions_Frame/Nameplates.lua`)
  раздел имён — это `UnitNameOwn`, выпадающий список имён NPC (он сам ставит
  `UnitNameNPC`, `UnitNameHostleNPC`, `UnitNameInteractiveNPC`,
  `UnitNameFriendlySpecialNPCName` и `ShowQuestUnitCircles`),
  `UnitNameNonCombatCreatureName` и имена и прислужники союзных и враждебных
  игроков.
- Текст «Screen captured» — кадр `ActionStatus`, событие `SCREENSHOT_SUCCEEDED`.
  Скрываем, снимая это событие с кадра, и возвращаем, регистрируя снова.
