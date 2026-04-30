-- gopro_queue_360_to_mp4.applescript
--
-- Пакетная конвертация .360 → .mp4 через очередь экспорта GoPro Player
-- (диалог "Настройки экспорта" → кнопка "Отправить в очередь").
--
-- Алгоритм:
--   1. Рекурсивно ищет все .360 в выбранной папке.
--   2. Для каждого файла:
--        - открывает в GoPro Player;
--        - вызывает File → Export… (или ⌘E);
--        - в диалоге "Настройки экспорта" выставляет разрешение, кодек,
--          ползунки (битрейт/качество/скорость/размер/Denoise) и галочки
--          (Блокировка направления, Линия горизонта, AntiShake,
--          Оптимизация крепления);
--        - нажимает "Отправить в очередь" — клип уходит в очередь рендера;
--        - закрывает текущий клип, переходит к следующему.
--   3. После того как все файлы поставлены в очередь, GoPro Player сам
--      рендерит их в фоне (в окне Queue / "Очередь экспорта").
--
-- Использование:
--     osascript gopro_queue_360_to_mp4.applescript
--     osascript gopro_queue_360_to_mp4.applescript ~/Footage/Max
--
-- Если GoPro Player спросит каталог сохранения — выберите его один раз
-- руками; следующие файлы пойдут в ту же папку (плеер запоминает выбор).

property kAppName : "GoPro Player"

------------------------------------------------------------------------------
-- ПАРАМЕТРЫ ЭКСПОРТА
------------------------------------------------------------------------------

-- Разрешение: "5,6K" | "4K" | "Пользовательский"
-- Английские подписи (на всякий): "5.6K" | "4K" | "Custom"
property kResolution : "4K"

-- Кодек: "HEVC" | "H.264" | "ProRes"
property kCodec : "H.264"

-- Чекбоксы. true / false — выставить точное значение, missing value — не трогать.
property kWorldLock : false -- "Блокировка направления"
property kHorizonLine : true -- "Линия горизонта"
property kAntiShake : true -- "AntiShake"
property kMountOptimize : false -- "Оптимизация крепления"

-- Слайдеры с подписями "медленно — быстро" и "хорошее — лучшее":
-- значение от 0.0 (левая граница) до 1.0 (правая граница).
-- missing value — не трогать.
property kSpeedSlider : 0.7 -- "Скорость экспорта (медленно-быстро)"
property kQualitySlider : 0.5 -- "Качество (хорошее-лучшее)"
property kFileSizeSlider : 0.8 -- "Размер файла"

-- Битрейт: 0.0 .. 1.0 (Мин. — Макс.). missing value — не трогать.
property kBitrate : 0.5

-- Denoise: 0.0 .. 1.0 + чекбокс включения. missing value — не трогать.
property kDenoiseEnabled : false
property kDenoiseLevel : 0.5

------------------------------------------------------------------------------
-- ТАЙМИНГИ
------------------------------------------------------------------------------

property kSheetTimeout : 30 -- ждать появление окна "Настройки экспорта", сек
property kBetweenFilesDelay : 1.0 -- пауза между файлами

------------------------------------------------------------------------------

on run argv
	set inputFolder to missing value
	if (count of argv) is greater than or equal to 1 then
		set inputFolder to (POSIX file ((item 1 of argv) as text)) as alias
	end if
	if inputFolder is missing value then
		set inputFolder to choose folder with prompt "Выберите папку с .360 файлами (рекурсивный поиск)"
	end if

	set sourceFiles to my collect360Files(POSIX path of inputFolder)
	set total to count of sourceFiles
	if total is 0 then
		display dialog "В выбранной папке не найдено .360 файлов." buttons {"OK"} default button 1 with icon caution
		return
	end if

	display notification "Найдено " & total & " файлов. Ставлю в очередь GoPro Player." with title "GoPro 360 → MP4"

	tell application kAppName to activate
	delay 1.0

	set queued to 0
	set failed to {}

	repeat with srcPath in sourceFiles
		set srcText to srcPath as text
		try
			my logLine("Открываю: " & srcText)
			tell application kAppName to open (POSIX file srcText)
			delay 1.5
			my waitForDocumentLoaded()

			my triggerExport()
			my waitForExportSheet()
			my expandAdvancedSection()
			my applyAllSettings()
			my clickAddToQueue()

			set queued to queued + 1
			my logLine("В очереди: " & srcText)

			delay 0.5
			my closeFrontDocument()
			delay kBetweenFilesDelay
		on error errMsg number errNum
			set end of failed to srcText & "  →  " & errMsg & " (" & errNum & ")"
			my logLine("ОШИБКА: " & srcText & " — " & errMsg)
			my dismissAnySheet()
			my closeFrontDocument()
		end try
	end repeat

	set summary to "В очередь поставлено: " & queued & " из " & total
	if failed is not {} then
		set summary to summary & return & return & "Ошибки:" & return
		repeat with f in failed
			set summary to summary & (f as text) & return
		end repeat
		display dialog summary buttons {"OK"} default button 1 with icon caution
	else
		display notification summary with title "GoPro 360 → MP4"
	end if
end run

------------------------------------------------------------------------------
-- ПОИСК ФАЙЛОВ
------------------------------------------------------------------------------

on collect360Files(rootPosix)
	set escaped to my shellQuote(rootPosix)
	set cmd to "/usr/bin/find " & escaped & " -type f -iname '*.360'"
	try
		set rawOutput to do shell script cmd
	on error
		return {}
	end try
	if rawOutput is "" then return {}

	set AppleScript's text item delimiters to (ASCII character 10)
	set parts to text items of rawOutput
	set AppleScript's text item delimiters to ""

	set result to {}
	repeat with p in parts
		set s to p as text
		if s is not "" then set end of result to s
	end repeat
	return result
end collect360Files

on shellQuote(s)
	set AppleScript's text item delimiters to "'"
	set parts to text items of s
	set AppleScript's text item delimiters to "'\\''"
	set joined to parts as text
	set AppleScript's text item delimiters to ""
	return "'" & joined & "'"
end shellQuote

------------------------------------------------------------------------------
-- УПРАВЛЕНИЕ GUI
------------------------------------------------------------------------------

on waitForDocumentLoaded()
	tell application "System Events"
		tell process kAppName
			repeat 30 times
				if (exists window 1) then exit repeat
				delay 0.2
			end repeat
		end tell
	end tell
end waitForDocumentLoaded

on triggerExport()
	tell application "System Events"
		set frontmost of process kAppName to true
		tell process kAppName
			set ok to false
			-- Русская локаль.
			repeat with menuName in {"Файл", "File"}
				repeat with itemName in {"Экспорт…", "Экспорт...", "Export…", "Export..."}
					if not ok then
						try
							click menu item (itemName as text) of menu (menuName as text) of menu bar 1
							set ok to true
						end try
					end if
				end repeat
			end repeat
			if not ok then
				keystroke "e" using {command down}
			end if
		end tell
	end tell
end triggerExport

on waitForExportSheet()
	tell application "System Events"
		tell process kAppName
			set elapsed to 0
			repeat while elapsed < kSheetTimeout
				if (my exportContainer()) is not missing value then return
				delay 0.25
				set elapsed to elapsed + 0.25
			end repeat
		end tell
	end tell
	error "Не дождался диалога Настройки экспорта"
end waitForExportSheet

on exportContainer()
	-- Возвращает контейнер диалога экспорта. В разных версиях это либо sheet,
	-- либо отдельное окно "Настройки экспорта" / "Export Settings".
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then return sheet 1 of window 1
			end try
			repeat with winName in {"Настройки экспорта", "Export Settings", "Export"}
				try
					if (exists window (winName as text)) then return window (winName as text)
				end try
			end repeat
			-- Иногда диалог — это просто frontmost окно с кнопкой "Отправить в очередь".
			try
				set wlist to every window
				repeat with w in wlist
					try
						set btns to every button of w
						repeat with b in btns
							try
								set bn to name of b
								if bn is "Отправить в очередь" or bn is "Add to Queue" then
									return contents of w
								end if
							end try
						end repeat
					end try
				end repeat
			end try
		end tell
	end tell
	return missing value
end exportContainer

on expandAdvancedSection()
	-- Если раздел "Расширенные параметры" свёрнут, разворачиваем.
	-- Это disclosure triangle; ищем по подписи и кликаем.
	set c to my exportContainer()
	if c is missing value then return
	tell application "System Events"
		tell process kAppName
			-- Сначала пробуем DisclosureTriangle.
			try
				set tris to every UI element of c whose role is "AXDisclosureTriangle"
				repeat with t in tris
					try
						if (value of t as integer) is 0 then
							click t
							delay 0.2
						end if
					end try
				end repeat
			end try
			-- Иногда это статический текст-кнопка "Расширенные параметры".
			try
				click (first button of c whose name is "Расширенные параметры")
				delay 0.2
			end try
			try
				click (first button of c whose name is "Advanced")
				delay 0.2
			end try
		end tell
	end tell
end expandAdvancedSection

on applyAllSettings()
	set c to my exportContainer()
	if c is missing value then return

	-- Радио-кнопки.
	my selectRadio(c, my resolutionLabels(kResolution))
	my selectRadio(c, my codecLabels(kCodec))

	-- Чекбоксы.
	if kWorldLock is not missing value then ¬
		my setCheckboxByName(c, {"Блокировка направления", "World Lock", "Direction Lock"}, kWorldLock)
	if kHorizonLine is not missing value then ¬
		my setCheckboxByName(c, {"Линия горизонта", "Horizon Line", "Horizon Lock", "Horizon Leveling"}, kHorizonLine)
	if kAntiShake is not missing value then ¬
		my setCheckboxByName(c, {"AntiShake", "Anti Shake", "Anti-Shake"}, kAntiShake)
	if kMountOptimize is not missing value then ¬
		my setCheckboxByName(c, {"Оптимизация крепления", "Mount Optimization", "Optimize Mount"}, kMountOptimize)

	-- Слайдеры (значения 0..1).
	if kSpeedSlider is not missing value then ¬
		my setSliderByLabel(c, {"Скорость экспорта", "Export Speed", "Speed"}, kSpeedSlider)
	if kQualitySlider is not missing value then ¬
		my setSliderByLabel(c, {"Качество", "Quality"}, kQualitySlider)
	if kFileSizeSlider is not missing value then ¬
		my setSliderByLabel(c, {"Размер файла", "File Size"}, kFileSizeSlider)
	if kBitrate is not missing value then ¬
		my setSliderByLabel(c, {"Битрейт", "Bitrate"}, kBitrate)

	-- Denoise: чекбокс рядом с подписью + слайдер.
	if kDenoiseEnabled is not missing value then ¬
		my setCheckboxByName(c, {"Denoise"}, kDenoiseEnabled)
	if kDenoiseLevel is not missing value then ¬
		my setSliderByLabel(c, {"Denoise"}, kDenoiseLevel)
end applyAllSettings

on resolutionLabels(v)
	if v is "5,6K" or v is "5.6K" then return {"5,6K", "5.6K"}
	if v is "4K" then return {"4K"}
	if v is "Пользовательский" or v is "Custom" then return {"Пользовательский", "Custom"}
	return {v as text}
end resolutionLabels

on codecLabels(v)
	if v is "HEVC" or v is "H.265" or v is "H265" then return {"HEVC", "H.265"}
	if v is "H.264" or v is "H264" then return {"H.264", "H264"}
	if v is "ProRes" then return {"ProRes"}
	return {v as text}
end codecLabels

on selectRadio(container, labels)
	tell application "System Events"
		try
			-- Сначала пробуем все radio buttons (включая внутри radio group).
			set candidates to {}
			try
				set rgs to every radio group of container
				repeat with rg in rgs
					try
						set rbs to every radio button of rg
						repeat with rb in rbs
							set end of candidates to rb
						end repeat
					end try
				end repeat
			end try
			try
				set extra to every radio button of container
				repeat with rb in extra
					set end of candidates to rb
				end repeat
			end try

			repeat with rb in candidates
				try
					set rbName to name of rb
					if rbName is not missing value then
						repeat with lbl in labels
							if (rbName as text) contains (lbl as text) then
								if (value of rb as integer) is 0 then
									click rb
									delay 0.2
								end if
								return
							end if
						end repeat
					end if
				end try
			end repeat
		end try
	end tell
end selectRadio

on setCheckboxByName(container, labels, desiredOn)
	tell application "System Events"
		try
			set boxes to every checkbox of container
		on error
			return
		end try
		repeat with cb in boxes
			try
				set match to false
				try
					set t to name of cb
					if t is not missing value then
						repeat with lbl in labels
							if (t as text) contains (lbl as text) then set match to true
						end repeat
					end if
				end try
				if not match then
					try
						set d to description of cb
						if d is not missing value then
							repeat with lbl in labels
								if (d as text) contains (lbl as text) then set match to true
							end repeat
						end if
					end try
				end if
				if match then
					set currentVal to (value of cb as integer)
					if (desiredOn and currentVal is 0) or ((not desiredOn) and currentVal is 1) then
						click cb
						delay 0.2
					end if
					return
				end if
			end try
		end repeat
	end tell
end setCheckboxByName

on setSliderByLabel(container, labels, normalizedValue)
	-- Ищем slider, у которого name/description/help/title содержит одну из подписей.
	-- Если ни у одного слайдера нет подписи, идём по позиции относительно
	-- статического текста с этой подписью (подбираем ближайший слайдер ниже).
	if normalizedValue < 0 then set normalizedValue to 0
	if normalizedValue > 1 then set normalizedValue to 1

	tell application "System Events"
		set targetSlider to missing value

		-- 1) Пробуем по own name/description.
		try
			set sliders to every slider of container
			repeat with s in sliders
				if targetSlider is missing value then
					set matched to false
					try
						set sn to name of s
						if sn is not missing value then
							repeat with lbl in labels
								if (sn as text) contains (lbl as text) then set matched to true
							end repeat
						end if
					end try
					if not matched then
						try
							set sd to description of s
							if sd is not missing value then
								repeat with lbl in labels
									if (sd as text) contains (lbl as text) then set matched to true
								end repeat
							end if
						end try
					end if
					if matched then set targetSlider to s
				end if
			end repeat
		end try

		-- 2) Если не нашли — ищем по координатам: статический текст с подписью,
		--    затем ближайший по вертикали slider.
		if targetSlider is missing value then
			try
				set labelEl to missing value
				set staticTexts to every static text of container
				repeat with st in staticTexts
					if labelEl is missing value then
						try
							set tv to value of st
							if tv is not missing value then
								repeat with lbl in labels
									if (tv as text) contains (lbl as text) then set labelEl to st
								end repeat
							end if
						end try
					end if
				end repeat
				if labelEl is not missing value then
					set lblPos to position of labelEl
					set lblY to (item 2 of lblPos) as integer
					set sliders to every slider of container
					set bestS to missing value
					set bestDy to 99999
					repeat with s in sliders
						try
							set sp to position of s
							set sy to (item 2 of sp) as integer
							set dy to sy - lblY
							-- Берём слайдер, который ниже подписи и ближе всего к ней.
							if dy ≥ 0 and dy < bestDy then
								set bestDy to dy
								set bestS to s
							end if
						end try
					end repeat
					if bestS is not missing value then set targetSlider to bestS
				end if
			end try
		end if

		if targetSlider is missing value then return

		try
			-- AXSlider value обычно 0.0 .. 1.0 (или min .. max). Пытаемся выставить
			-- напрямую — если не выйдет, кликаем мышкой по нужной координате.
			try
				set value of targetSlider to normalizedValue
				delay 0.15
				return
			end try
			-- Фолбэк: вычисляем абсолютную позицию и кликаем.
			set sp to position of targetSlider
			set ss to size of targetSlider
			set sx to ((item 1 of sp) as integer) + ((item 1 of ss) as integer) * normalizedValue
			set sy to ((item 2 of sp) as integer) + ((item 2 of ss) as integer) / 2
			tell process kAppName
				click at {sx as integer, sy as integer}
			end tell
			delay 0.15
		end try
	end tell
end setSliderByLabel

on clickAddToQueue()
	-- Ищем кнопку "Отправить в очередь" / "Add to Queue".
	set c to my exportContainer()
	if c is missing value then error "Контейнер экспорта пропал"
	tell application "System Events"
		repeat with btnName in {"Отправить в очередь", "Add to Queue", "Add To Queue"}
			try
				click button (btnName as text) of c
				delay 0.5
				return
			end try
		end repeat
	end tell
	error "Кнопка 'Отправить в очередь' не найдена"
end clickAddToQueue

on dismissAnySheet()
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then
					key code 53 -- Esc
					delay 0.3
				end if
			end try
		end tell
	end tell
end dismissAnySheet

on closeFrontDocument()
	tell application "System Events"
		tell process kAppName
			try
				keystroke "w" using {command down}
				delay 0.4
				if (exists sheet 1 of window 1) then
					repeat with bn in {"Не сохранять", "Don’t Save", "Don't Save"}
						try
							click button (bn as text) of sheet 1 of window 1
							exit repeat
						end try
					end repeat
				end if
			end try
		end tell
	end tell
end closeFrontDocument

on logLine(s)
	try
		do shell script "echo " & quoted form of (((current date) as text) & " - " & (s as text)) & " >> /tmp/gopro_360_to_mp4.log"
	end try
end logLine
