# AppleScript для GoPro Player

Набор AppleScript-сценариев для автоматизации [GoPro Player](https://gopro.com/en/us/shop/quik-gopro-player-mac-apps) на macOS: открытие файлов, управление воспроизведением, полноэкранный режим, перемотка, пакетный импорт и **массовая конвертация `.360` → `.mp4`**.

> GoPro Player не предоставляет полноценный AppleScript-словарь, поэтому большинство команд реализованы через GUI-скриптинг (`System Events`). Это значит, что приложение должно быть запущено и активно, а Терминалу/скриптовому хосту нужно дать права в **System Settings → Privacy & Security → Accessibility**.

## Быстрый старт: рендер `.360` → `.mp4` с удалением исходников

Для иерархии вида:

```
Evropolis/
└── EP_2026-04-26_244_…@gmail.com/
    ├── 1/
    │   └── GS010705.360
    └── 2/
        └── GS010712.360
```

рекомендуемый сценарий:

```bash
# 1. Открыть Терминал.
# 2. Перейти в репозиторий со скриптами.
cd /path/to/this/repo

# 3. Один раз дать Terminal'у права в:
#    System Settings → Privacy & Security → Accessibility (флажок Terminal)
#    System Settings → Privacy & Security → Automation → Terminal → GoPro Player + Finder + System Events

# 4. Запустить:
osascript scripts/gopro_render_then_delete_360.applescript ~/Movies/Evropolis
```

Скрипт рекурсивно найдёт **все** `.360` внутри `Evropolis` (включая `1/GS010705.360`, `2/GS010712.360` и т. д.), отрендерит их **по одному**, **`.mp4` сохранит в ту же папку** где лежал исходник, дождётся окончания рендера и **удалит исходный `.360` в Корзину**. Логи прогресса:

```bash
tail -f /tmp/gopro_360_to_mp4.log
```

Подробности и параметры — ниже в разделе [«Конвертация `.360` → `.mp4` по одному файлу с удалением исходников»](#конвертация-360--mp4-по-одному-файлу-с-удалением-исходников).

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
| [`scripts/gopro_dump_menu.applescript`](scripts/gopro_dump_menu.applescript) | Диагностика: дампит реальную UI-структуру GoPro Player в `/tmp/gopro_menu_dump.txt`. Используется, если рендер не запускается — показывает реальные имена пунктов меню в текущей версии плеера |
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

Управляется двумя свойствами в начале файла:

```applescript
property kSaveNextToSource : true   -- сохранять рядом с исходником
property kOutputFolder    : ""      -- используется только если выше false
```

- **`kSaveNextToSource = true`** *(по умолчанию)* — каждый `.mp4` ложится **в ту же папку**, где лежит исходный `.360`. Идеально для иерархий вида `Evropolis/EP_…/1/GS010705.360` — рендер появится прямо в `1/`. Скрипт автоматически выберет этот каталог в save-sheet через `⇧⌘G` (Go to Folder).
- **`kSaveNextToSource = false`** — все `.mp4` идут в одну папку `kOutputFolder`. Если она пустая, скрипт спросит её один раз на запуск.

GoPro Player сам формирует имя выходного файла. У современных версий это либо `<original_name>.mp4`, либо `<original_name>_<timestamp>.mp4` (вида `GS010712_2026-04-30_08-59-40-032.mp4`). Скрипт делает «снимок» списка `.mp4` в выходной папке **до** рендера и затем ловит **новый появившийся файл** — поэтому корректно работает с обоими шаблонами имён.

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

### Полная инструкция запуска (с нуля)

**Шаг 1. Получить файлы скрипта.**

```bash
git clone https://github.com/clouderefresh-arch/reposii.git ~/gopro-applescript
cd ~/gopro-applescript
```

(Можно и просто скачать файл `scripts/gopro_render_then_delete_360.applescript` куда угодно — пути в скрипте не привязаны к репозиторию.)

**Шаг 2. (Опционально) поправить настройки в шапке скрипта.**

Откройте в любом редакторе или в **Script Editor.app**:

```bash
open -a "Script Editor" scripts/gopro_render_then_delete_360.applescript
```

Главные свойства, на которые стоит обратить внимание:

```applescript
property kSourceFolder    : ""        -- можно жёстко прописать корень
property kSaveNextToSource: true      -- сохранять рядом с .360
property kOutputFolder    : ""        -- используется только если выше false
property kDeleteMode      : "trash"   -- "trash" | "rm" | "none"

property kResolution      : "4K"      -- "5,6K" | "4K" | "Пользовательский"
property kCodec           : "H.264"   -- "HEVC" | "H.264" | "ProRes"

property kWorldLock       : false
property kHorizonLine     : true
property kAntiShake       : true
property kMountOptimize   : false

property kSpeedSlider     : 0.7       -- ползунки 0..1
property kQualitySlider   : 0.5
property kFileSizeSlider  : 0.8
property kBitrate         : 0.5
property kDenoiseEnabled  : false
property kDenoiseLevel    : 0.5
```

Любому слайдеру/чекбоксу можно поставить `missing value` — тогда скрипт оставит то значение, которое уже выбрано в плеере.

**Шаг 3. Выдать права macOS.**

GoPro Player управляется через GUI-скриптинг, поэтому процессу, который запускает скрипт, нужны два **разных** разрешения:

- **Accessibility** («Функции универсального доступа») — для эмуляции нажатий клавиш и работы с UI-элементами.
- **Automation** — для команд `tell application …`.

> ⚠️ **Важная тонкость**: при запуске через `osascript file.applescript` macOS требует Accessibility-право не у Terminal, а у самого `/usr/bin/osascript`. Терминалу можно ставить флажки сколько угодно — `osascript` всё равно останется без прав, и вы получите ошибку `-25211 «Функции Универсального доступа для osascript не разрешены»`.
>
> Решений два: либо дать Accessibility самому бинарнику `osascript` (см. ниже), либо собрать `.app` и дать права уже ему — это чище. Рекомендую второй путь.

#### Способ 1 (рекомендуется): собрать `.app` и дать права ему

```bash
osacompile -o "GoPro 360 Render.app" scripts/gopro_render_then_delete_360.applescript
```

После этого:

1. Запустите `GoPro 360 Render.app` двойным кликом (macOS попросит подтвердить запуск приложения от неизвестного разработчика — согласитесь, или зайдите в `System Settings → Privacy & Security` и нажмите **Open Anyway**).
2. **System Settings → Privacy & Security → Accessibility** → `+` → выберите `GoPro 360 Render.app` → флажок **ON**.
3. **System Settings → Privacy & Security → Automation** → раскройте `GoPro 360 Render.app` → разрешите управление `GoPro Player`, `Finder`, `System Events` (эти запросы macOS покажет автоматически при первом запуске; соглашайтесь).
4. Дальше можно либо запускать двойным кликом (тогда появится диалог выбора папки), либо **перетаскивать папку или `.360` файлы прямо на иконку** приложения (droplet-режим).

#### Способ 2: дать Accessibility самому `osascript`

Если хотите запускать `osascript scripts/gopro_render_then_delete_360.applescript …` из Terminal:

1. `System Settings → Privacy & Security → Accessibility` → нажмите `+`.
2. В диалоге выбора файлов нажмите **⇧⌘G** и введите:

   ```
   /usr/bin/osascript
   ```

3. Подтвердите → `osascript` появится в списке → включите тумблер.
4. Аналогично в `Privacy & Security → Automation` разрешите Terminal управлять `GoPro Player`, `Finder`, `System Events` (это запросится автоматически при первом запуске).
5. **Перезапустите Terminal**.

#### Способ 3: запуск из Script Editor

Откройте `scripts/gopro_render_then_delete_360.applescript` в **Script Editor.app** и нажмите **▶ Run**. Дайте Script Editor права в Accessibility и Automation. Удобно для отладки, но не для «нажал и забыл».

#### Коды ошибок прав

- `-25211` или «osascript не разрешены функции универсального доступа» → Accessibility для `osascript`/`.app`.
- `-1719` или `not authorized to send Apple events` → Automation для нужного целевого приложения.

**Шаг 4. Закрыть лишние окна GoPro Player.**

Чтобы скрипт не путался, перед запуском желательно закрыть все открытые в плеере клипы. Достаточно нажать ⌘W в каждом окне или `GoPro Player → Quit GoPro Player`.

**Шаг 5. Запустить.**

```bash
# с диалогом выбора корневой папки
osascript scripts/gopro_render_then_delete_360.applescript

# или сразу с папкой (рекурсивно найдёт все .360 во всех подпапках)
osascript scripts/gopro_render_then_delete_360.applescript ~/Movies/Evropolis

# или с одним конкретным файлом
osascript scripts/gopro_render_then_delete_360.applescript ~/Movies/Evropolis/EP_…/1/GS010705.360
```

Параллельно полезно открыть лог:

```bash
tail -f /tmp/gopro_360_to_mp4.log
```

**Шаг 6. (Удобно) сделать «капельницу» (droplet).**

В **Script Editor.app**: `File → Export…` → `File Format: Application` → сохраните, например, как `GoPro 360 Render.app` на рабочий стол. После этого вы можете просто **перетаскивать на иконку приложения**:

- одну корневую папку (вроде `Evropolis/`) — обработает всё внутри;
- набор `.360` файлов — обработает только их;
- даже отдельный `.360` — отрендерит его и удалит.

При первом перетаскивании macOS попросит дать самому приложению `Accessibility` и `Automation` — нужно подтвердить.

### Что увидит пользователь во время работы

1. Открывается окно GoPro Player с первым `.360`.
2. Появляется диалог «Настройки экспорта» — скрипт выставляет в нём radio-кнопки, чекбоксы, слайдеры.
3. Жмётся «Далее…», в save-sheet:
   - имя файла подставляется как `<original>.mp4`;
   - переходит в нужную папку через `⇧⌘G`;
   - жмётся «Сохранить».
4. Окно клипа закрывается, рендер идёт в фоне очереди GoPro Player.
5. Скрипт ждёт появления нового `.mp4` в выходной папке, а затем — пока его размер не перестанет расти 5 секунд подряд.
6. Только после этого исходник `.360` отправляется в Корзину (или удаляется по `kDeleteMode`).
7. Открывается следующий клип, цикл повторяется.

В конце прохода — нотификация со сводкой; при ошибках появится диалог со списком проблемных файлов.

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

## Если рендеринг не запускается — диагностика

Симптомы:

- GoPro Player запускается и открывает `.360` — видно глазами;
- но диалог «Настройки экспорта» не появляется;
- через ~60 сек скрипт показывает ошибку `-2700 «Не дождался диалога 'Настройки экспорта'»`.

Причина почти всегда — фактическое имя пункта меню в вашей версии GoPro Player отличается от того, что ищет скрипт (например, `Экспортировать…` вместо `Экспорт…`), или у пункта другой shortcut, или меню не активно из-за проблем индексации `.360` на конкретном томе.

Чтобы это исправить, нужен **дамп реальной UI-структуры** GoPro Player. Используйте `scripts/gopro_dump_menu.applescript`:

```bash
cd ~/gopro-applescript
git pull origin cursor/applescript-gopro-player-d935
osacompile -o "GoPro Menu Dump.app" scripts/gopro_dump_menu.applescript
xattr -dr com.apple.quarantine "GoPro Menu Dump.app"
```

Затем:

1. Откройте в GoPro Player один `.360` файл и **дождитесь полной загрузки** (видна полоса проигрывания, можно нажать ▶).
2. Запустите `GoPro Menu Dump.app` (двойной клик).
3. Дайте ему права в `Системные настройки → Конфиденциальность и безопасность → Универсальный доступ` (так же, как давали `GoPro 360 Render`).
4. Должен появиться диалог «Дамп записан в /tmp/gopro_menu_dump.txt».
5. Откройте файл и пришлите его содержимое следующему агенту:

   ```bash
   cat /tmp/gopro_menu_dump.txt
   ```

В дампе будут видны:

- все локализованные имена пунктов меню (`Файл`, `Правка`, `Вид`, …) с их `name`, `enabled`, `AXIdentifier` и shortcut'ом;
- все окна приложения с их role и size;
- AX-дерево окна клипа.

По этому дампу можно точно настроить триггер экспорта в `gopro_render_then_delete_360.applescript` под вашу версию GoPro Player.

## Настройка прав доступа

При первом запуске macOS попросит разрешить:

* **Accessibility** — для эмуляции нажатий клавиш и работы с меню (`System Events`).
* **Automation** — для управления `GoPro Player` и `Finder`.

Если скрипт «молчит» или возвращает ошибку `-1719` / `-25211`, проверьте оба пункта в **System Settings → Privacy & Security**.

## Замечания по совместимости

* Скрипты ориентированы на GoPro Player из Mac App Store (имя процесса `GoPro Player`). Если у вас установлен `GoPro Player + HyperSmooth Pro`, отредактируйте константу `kAppName` в начале каждого файла.
* Названия пунктов меню (`File`, `Export…`, `Enter Full Screen`) указаны для английской локали. Для русской поменяйте их в `gopro_export.applescript` и `gopro_fullscreen.applescript` на `Файл`, `Экспорт…`, `Перейти в полноэкранный режим`.
* Скорость выполнения зависит от анимаций macOS — при необходимости увеличьте `delay`.
