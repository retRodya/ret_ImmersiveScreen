# Архитектура

Как устроено ядро и как добавить эффект или страницу. Что строим и почему —
в `docs/VISION.md`. Окно повторяет ret_TweaksLite: если меняешь общее поведение,
посмотри, как это сделано там.

## Файлы

Порядок загрузки задаёт `.toc`:

| Файл | Что делает |
| --- | --- |
| `Core.lua` | Метаданные из `.toc`, сохранённые настройки, реестр модулей и страниц, настройки с откатом, запуск после входа. |
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
- Заглушки показывают значения по умолчанию и ничего не сохраняют.

## Клавиши (Lens)

- У эффекта с `lens = true` своя клавиша `RETIMMERSIVESCREEN_<KEY>`, у Combined
  Lens — `RETIMMERSIVESCREEN_COMBINEDLENS`. Новую клавишу нужно добавить
  в `Bindings.xml` и дать ей имя `BINDING_NAME_…` в `Lens.lua`.
- Эффект в Combined Lens своей клавишей не включается.
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

## Сохранённые настройки

```lua
ret_ImmersiveScreenDB = {
    schemaVersion = 1,
    enabled = { Letterbox = false },                -- только то, что игрок менял
    settings = { Letterbox = { height = 12 }, General = { hideScreenshotMessage = true } },
    collapsed = { LiteRP = true },                  -- свёрнутые группы списка
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
- Текст «Screen captured» — кадр `ActionStatus`, событие `SCREENSHOT_SUCCEEDED`.
  Скрываем, снимая это событие с кадра, и возвращаем, регистрируя снова.
