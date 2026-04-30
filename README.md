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
| [`scripts/gopro_convert_360_to_mp4.applescript`](scripts/gopro_convert_360_to_mp4.applescript) | Рекурсивная конвертация всех `.360` файлов в `.mp4` с настраиваемыми параметрами (универсальный, поэлементно ждёт окончания каждого экспорта) |
| [`scripts/gopro_queue_360_to_mp4.applescript`](scripts/gopro_queue_360_to_mp4.applescript) | Ставит все `.360` в очередь экспорта GoPro Player одним проходом (использует кнопку «Отправить в очередь») |
| [`scripts/gopro_render_then_delete_360.applescript`](scripts/gopro_render_then_delete_360.applescript) | **Один файл за раз**: рендерит `.360`, ждёт окончания, проверяет результат, **удаляет исходник** (Корзина / `rm` / не трогать) и переходит к следующему |
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

## Конвертация `.360` → `.mp4` по одному файлу с удалением исходников

Сценарий [`scripts/gopro_render_then_delete_360.applescript`](scripts/gopro_render_then_delete_360.applescript) — это «съел исходник, выплюнул mp4». Он идёт по `.360` файлам по одному и **только после успешного рендера** удаляет исходник.

### Как скрипт находит исходники

Источник определяется в таком порядке (что нашлось — то и используется):

1. **CLI-аргумент**:

   ```bash
   osascript scripts/gopro_render_then_delete_360.applescript ~/Footage/Max
   osascript scripts/gopro_render_then_delete_360.applescript /Volumes/GoPro/DCIM/100GOPRO/GS010001.360
   ```

   Можно передать как папку, так и одиночный `.360` файл.

2. **Свойство в скрипте** — задайте путь жёстко в начале файла:

   ```applescript
   property kSourceFolder : "/Users/me/Footage/Max"
   ```

3. **Droplet** — сохраните скрипт через **Script Editor → File → Export… → File Format: Application** (например, `GoPro 360 Render.app`). После этого можно просто **перетащить папку или несколько `.360` файлов на иконку приложения** — обработает их.

4. **Диалог** — если ничего из вышеперечисленного не задано, появится `choose folder` для выбора папки.

Поиск внутри папки рекурсивный (`find -type f -iname '*.360'`), регистр не важен.

### Куда сохраняется результат

В `kOutputFolder` (если пусто — спросит при запуске). Имя выходного файла — `<имя_исходника>.mp4`. Если такой `.mp4` уже существует и непустой, рендер пропускается, а исходник всё равно удаляется (можно использовать как «дочистку» после прерванного прогона).

### Что происходит с исходником

Управляется свойством `kDeleteMode`:

| Значение | Что делает |
|---|---|
| `"trash"` *(по умолчанию)* | Перемещает `.360` в **Корзину** через Finder — можно восстановить |
| `"rm"` | Удаляет безвозвратно (`/bin/rm -f`) |
| `"none"` | Ничего не делает (для теста) |

Удаление происходит **только** если:
1. Рендер завершился без исключений.
2. Целевой `.mp4` существует.
3. Размер `.mp4` больше 1 КБ (защита от пустого/обрезанного файла).
4. Размер `.mp4` стабилен в течение `kStableSeconds` подряд (по умолчанию 5 сек) — это и есть «маркер окончания рендера»: GoPro Player пишет файл потоково, и пока он растёт, мы ждём.

### Как определяется окончание рендера

Без полагаться на UI прогресса (его подписи плавают между версиями), скрипт следит за самим выходным файлом:

1. После клика «Далее…» → «Сохранить» закрывает окно клипа.
2. В цикле опрашивает размер `.mp4` через `stat -f %z` каждую секунду.
3. Считает рендер завершённым, когда размер не меняется `kStableSeconds` секунд подряд.
4. Жёсткий таймаут — `kRenderTimeout` (по умолчанию 1 час).

Это надёжно работает даже если GoPro Player в это время уже подхватил следующий файл из очереди — нас интересует именно конкретный `.mp4`.

### Запуск

```bash
osascript scripts/gopro_render_then_delete_360.applescript                 # с диалогами
osascript scripts/gopro_render_then_delete_360.applescript ~/Footage/Max   # с папкой
tail -f /tmp/gopro_360_to_mp4.log
```

> **Совет**: первый прогон сделайте с `kDeleteMode : "none"` или `"trash"`, чтобы убедиться, что параметры рендера и пути выбраны правильно. `"rm"` ставьте, только когда уверены.

## Конвертация `.360` → `.mp4` (через очередь экспорта — рекомендуется)

Сценарий [`scripts/gopro_queue_360_to_mp4.applescript`](scripts/gopro_queue_360_to_mp4.applescript) учитывает реальный UI диалога **«Настройки экспорта»** (см. скриншот) и не ждёт окончания каждого рендера, а **ставит все клипы в очередь** через кнопку **«Отправить в очередь»**. После этого GoPro Player сам последовательно отрендерит их в фоне.

### Что выставляется автоматически

| Параметр диалога | `property` в скрипте | Тип |
|---|---|---|
| Разрешение (5,6K / 4K / Пользовательский) | `kResolution` | radio |
| Кодек (HEVC / H.264 / ProRes) | `kCodec` | radio |
| Скорость экспорта (медленно↔быстро) | `kSpeedSlider` (0..1) | slider |
| Качество (хорошее↔лучшее) | `kQualitySlider` (0..1) | slider |
| Размер файла | `kFileSizeSlider` (0..1) | slider |
| Битрейт (Мин.↔Макс.) | `kBitrate` (0..1) | slider |
| Denoise (вкл + уровень) | `kDenoiseEnabled`, `kDenoiseLevel` | checkbox + slider |
| Блокировка направления | `kWorldLock` | checkbox |
| Линия горизонта | `kHorizonLine` | checkbox |
| AntiShake | `kAntiShake` | checkbox |
| Оптимизация крепления | `kMountOptimize` | checkbox |

Чекбоксы можно «не трогать», задав `missing value` — тогда скрипт оставит то, что выставлено в плеере по умолчанию.

### Параметры по умолчанию в скрипте

```applescript
property kResolution     : "4K"
property kCodec          : "H.264"
property kWorldLock      : false   -- "Блокировка направления"
property kHorizonLine    : true    -- "Линия горизонта"
property kAntiShake      : true    -- "AntiShake"
property kMountOptimize  : false   -- "Оптимизация крепления"
property kSpeedSlider    : 0.7     -- скорость экспорта
property kQualitySlider  : 0.5     -- качество
property kFileSizeSlider : 0.8     -- размер файла
property kBitrate        : 0.5     -- битрейт
property kDenoiseEnabled : false
property kDenoiseLevel   : 0.5
```

### Запуск

```bash
osascript scripts/gopro_queue_360_to_mp4.applescript
osascript scripts/gopro_queue_360_to_mp4.applescript ~/Footage/Max
tail -f /tmp/gopro_360_to_mp4.log
```

Папку для сохранения результатов GoPro Player запросит однократно (в первый раз) — выберите её, и все последующие клипы из очереди уйдут туда же.

### Как это работает

1. Скрипт открывает первый `.360` файл, нажимает `File → Export…` (или ⌘E).
2. В появившемся диалоге «Настройки экспорта»:
   - разворачивает раздел «Расширенные параметры» (если свёрнут);
   - выбирает radio-кнопки `Разрешение` и `Кодек`;
   - проставляет все чекбоксы;
   - двигает слайдеры (`AXSlider value` пишется напрямую, при отказе — клик мышью в нужной координате);
3. Нажимает **«Отправить в очередь»**.
4. Закрывает текущий клип (⌘W) и переходит к следующему.
5. После прохода — все файлы стоят в очереди GoPro Player и рендерятся сами.

## Альтернатива: блокирующая конвертация по одному файлу

Сценарий [`scripts/gopro_convert_360_to_mp4.applescript`](scripts/gopro_convert_360_to_mp4.applescript) делает то же самое, но без использования очереди — нажимает в диалоге `Export` и ждёт окончания рендера каждого файла. Полезно, если у вас старая версия GoPro Player без кнопки «Отправить в очередь», или если нужно поштучно складывать результаты в разные папки.

Описание (для общего случая — съёмки GoPro Max / 360):

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
