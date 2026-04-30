# AppleScript для GoPro Player

Набор AppleScript-сценариев для автоматизации [GoPro Player](https://gopro.com/en/us/shop/quik-gopro-player-mac-apps) на macOS: открытие файлов, управление воспроизведением, полноэкранный режим, перемотка, пакетный импорт и экспорт.

> GoPro Player не предоставляет полноценный AppleScript-словарь, поэтому большинство команд реализованы через GUI-скриптинг (`System Events`). Это значит, что приложение должно быть запущено и активно, а Терминалу/скриптовому хосту нужно дать права в **System Settings → Privacy & Security → Accessibility**.

## Состав

| Скрипт | Назначение |
|---|---|
| [`scripts/gopro_open_file.applescript`](scripts/gopro_open_file.applescript) | Открыть один или несколько файлов в GoPro Player |
| [`scripts/gopro_play_pause.applescript`](scripts/gopro_play_pause.applescript) | Переключить play/pause (пробел) |
| [`scripts/gopro_fullscreen.applescript`](scripts/gopro_fullscreen.applescript) | Переключить полноэкранный режим |
| [`scripts/gopro_seek.applescript`](scripts/gopro_seek.applescript) | Перемотка вперёд/назад на N секунд (стрелки ←/→) |
| [`scripts/gopro_frame_step.applescript`](scripts/gopro_frame_step.applescript) | Пошаговый сдвиг по кадрам (`,` / `.`) |
| [`scripts/gopro_export.applescript`](scripts/gopro_export.applescript) | Запустить экспорт активного клипа через меню `File → Export` |
| [`scripts/gopro_batch_open_finder.applescript`](scripts/gopro_batch_open_finder.applescript) | Открыть выделенные в Finder файлы в GoPro Player |
| [`scripts/gopro_batch_export_folder.applescript`](scripts/gopro_batch_export_folder.applescript) | Пакетный экспорт всех видео из выбранной папки |
| [`scripts/gopro_quit.applescript`](scripts/gopro_quit.applescript) | Корректно завершить приложение |
| [`scripts/gopro_controller.applescript`](scripts/gopro_controller.applescript) | Универсальный контроллер с handlers (можно `load script`) |

## Запуск

### Из Терминала

```bash
osascript scripts/gopro_play_pause.applescript
osascript scripts/gopro_seek.applescript -- 10        # вперёд на 10 с
osascript scripts/gopro_seek.applescript -- -5        # назад на 5 с
osascript scripts/gopro_open_file.applescript ~/Movies/GX010001.MP4
```

### Из Script Editor

1. Откройте `.applescript` в **Script Editor** (`/System/Applications/Utilities/Script Editor.app`).
2. Сохраните как `.scpt` или `.app`, если хотите получить готовое приложение‑дроплет.

### Через горячие клавиши

Скрипты можно повесить на хоткеи через **Automator → Quick Action** (Run AppleScript) и далее **System Settings → Keyboard → Keyboard Shortcuts → Services**, либо через сторонние утилиты (Raycast, BetterTouchTool, Keyboard Maestro, FastScripts).

### Использование контроллера

```applescript
set goproLib to (load script POSIX file "/path/to/scripts/gopro_controller.applescript")
goproLib's launchPlayer()
goproLib's openFile(POSIX path of (choose file of type {"public.movie"}))
goproLib's playPause()
goproLib's seekBy(15)
goproLib's exportCurrent()
```

## Настройка прав доступа

При первом запуске macOS попросит разрешить:

* **Accessibility** — для эмуляции нажатий клавиш и работы с меню (`System Events`).
* **Automation** — для управления `GoPro Player` и `Finder`.

Если скрипт «молчит» или возвращает ошибку `-1719` / `-25211`, проверьте оба пункта в **System Settings → Privacy & Security**.

## Замечания по совместимости

* Скрипты ориентированы на GoPro Player из Mac App Store (имя процесса `GoPro Player`). Если у вас установлен `GoPro Player + HyperSmooth Pro`, отредактируйте константу `kAppName` в начале каждого файла.
* Названия пунктов меню (`File`, `Export…`, `Enter Full Screen`) указаны для английской локали. Для русской поменяйте их в `gopro_export.applescript` и `gopro_fullscreen.applescript` на `Файл`, `Экспорт…`, `Перейти в полноэкранный режим`.
* Скорость выполнения зависит от анимаций macOS — при необходимости увеличьте `delay`.
