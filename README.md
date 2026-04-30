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
| [`scripts/gopro_convert_360_to_mp4.applescript`](scripts/gopro_convert_360_to_mp4.applescript) | **Рекурсивная конвертация всех `.360` файлов в `.mp4` с настраиваемыми параметрами (формат, кодек, качество, разрешение, World Lock, звук)** |
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

## Конвертация `.360` → `.mp4`

Сценарий [`scripts/gopro_convert_360_to_mp4.applescript`](scripts/gopro_convert_360_to_mp4.applescript) делает именно то, что нужно для большинства съёмок с GoPro Max / GoPro 360:

1. Спрашивает (или принимает аргументами) папку с `.360` и папку для результата.
2. Рекурсивно ищет все `.360` через `find`.
3. Для каждого файла:
   - открывает его в GoPro Player;
   - вызывает `File → Export…`;
   - выставляет в окне экспорта формат, кодек, качество, разрешение, World Lock и звук;
   - подставляет имя файла `<original_name>.mp4`;
   - переходит в указанную папку (через `⇧⌘G`);
   - подтверждает экспорт и ждёт его завершения;
   - закрывает клип и переходит к следующему.
4. По завершении показывает уведомление и (при ошибках) сводный диалог.

### Параметры

Все параметры экспорта вынесены в `property` в начале файла:

```applescript
property kFormat : "MP4"        -- формат вывода
property kCodec : "H.264"       -- "H.264" / "HEVC" / "ProRes"
property kQuality : "High"      -- "High" / "Medium" / "Low" / "Original"
property kResolution : "5.6K"   -- "5.6K" / "4K" / "1440p" / "1080p"
property kWorldLock : true      -- true / false
property kIncludeAudio : true   -- true / false
```

Скрипт ищет в окне экспорта popup-меню и чекбоксы по нескольким возможным подписям (`Output`, `Format`, `Codec`, `Quality`, `Resolution`, `World Lock`, `Horizon Lock`, …) и кликает в нужный пункт. Если в вашей версии GoPro Player подпись отличается — добавьте её в массив `labels` соответствующего вызова `setPopupValue` / `setCheckbox`.

### Запуск

```bash
osascript scripts/gopro_convert_360_to_mp4.applescript
osascript scripts/gopro_convert_360_to_mp4.applescript ~/Footage/Max ~/Footage/Max_MP4
```

Прогресс пишется в `/tmp/gopro_360_to_mp4.log`:

```bash
tail -f /tmp/gopro_360_to_mp4.log
```

### Рекомендации

- Перед массовой конвертацией прогоните **один файл вручную** через `File → Export…`, выставьте нужные параметры — GoPro Player запоминает их для следующего раза, и автоматизация будет надёжнее.
- На время рендера лучше не трогать мышь и клавиатуру: GUI-скриптинг чувствителен к фокусу.
- Если экспорт длинного клипа занимает больше получаса, увеличьте `kExportFinishTimeout` (по умолчанию `1800` секунд).
- Для очень тяжёлых .360 файлов имеет смысл выставить `kBetweenFilesDelay` побольше (2–3 секунды), чтобы дать ОС «отдышаться».

## Настройка прав доступа

При первом запуске macOS попросит разрешить:

* **Accessibility** — для эмуляции нажатий клавиш и работы с меню (`System Events`).
* **Automation** — для управления `GoPro Player` и `Finder`.

Если скрипт «молчит» или возвращает ошибку `-1719` / `-25211`, проверьте оба пункта в **System Settings → Privacy & Security**.

## Замечания по совместимости

* Скрипты ориентированы на GoPro Player из Mac App Store (имя процесса `GoPro Player`). Если у вас установлен `GoPro Player + HyperSmooth Pro`, отредактируйте константу `kAppName` в начале каждого файла.
* Названия пунктов меню (`File`, `Export…`, `Enter Full Screen`) указаны для английской локали. Для русской поменяйте их в `gopro_export.applescript` и `gopro_fullscreen.applescript` на `Файл`, `Экспорт…`, `Перейти в полноэкранный режим`.
* Скорость выполнения зависит от анимаций macOS — при необходимости увеличьте `delay`.
