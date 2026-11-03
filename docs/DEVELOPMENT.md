# Разработка

Как настроить рабочее место и проверять аддон в игре.

## Аддон в клиентах игры

Папка `ret_ImmersiveScreen/` из репозитория подключается к клиентам связью-junction.
Тогда правка файла в репозитории сразу видна в игре после `/reload`, и копировать
ничего не нужно. Права администратора для junction не требуются.

PowerShell, путь к игре замени на свой:

```powershell
$addon = "D:\Hobby\WoW_addons\ret_ImmersiveScreen_project_opus\ret_ImmersiveScreen"
$wow = "D:\Games\World of Warcraft"
New-Item -ItemType Junction -Path "$wow\_retail_\Interface\AddOns\ret_ImmersiveScreen" -Target $addon
New-Item -ItemType Junction -Path "$wow\_forever_\Interface\AddOns\ret_ImmersiveScreen" -Target $addon
```

Если в `AddOns` уже есть папка `ret_ImmersiveScreen`, сначала убери её.
Junction работает только на одном компьютере. Если игра стоит на другом,
клонируй туда репозиторий и создай связи там.

Удаление связи не трогает файлы репозитория:

```powershell
Remove-Item "$wow\_retail_\Interface\AddOns\ret_ImmersiveScreen"
```

## Проверка в игре

- Пока идёт проверка, выключи старый ret_Cinemator: оба аддона скрывают
  интерфейс и рисуют полосы и будут мешать друг другу.
- Ошибки Lua: установи BugGrabber и BugSack или включи `/console scriptErrors 1`.
- После правки файла достаточно `/reload`. Новый файл в `.toc` требует
  перезапуска клиента.
- Версия интерфейса клиента: `/dump select(4, GetBuildInfo())`. Если число
  не совпадает со строкой `## Interface` в `.toc`, обнови её.
