-- gopro_convert_360_to_mp4.applescript
--
-- Рекурсивно находит все .360 файлы в выбранной папке (или в папках,
-- переданных как аргументы), открывает каждый в GoPro Player и через
-- File → Export… конвертирует в .mp4 с заданными параметрами.
--
-- Использование:
--   1) Без аргументов — появятся два диалога: «откуда брать .360» и «куда сохранять».
--      osascript gopro_convert_360_to_mp4.applescript
--
--   2) С аргументами — путь к исходной папке и (опц.) к выходной:
--      osascript gopro_convert_360_to_mp4.applescript ~/Footage/360 ~/Footage/MP4
--
-- ВАЖНО: GoPro Player не имеет AppleScript-словаря, поэтому параметры
-- экспорта выставляются через GUI-скриптинг. Подписи UI-элементов в Export sheet
-- зависят от версии и языка приложения. Если у вас не английская локаль или
-- GoPro поменял интерфейс — отредактируйте константы в начале файла.

property kAppName : "GoPro Player"

------------------------------------------------------------------------------
-- НАСТРОЙКИ ЭКСПОРТА
------------------------------------------------------------------------------

-- Что выбрать в popup'е "Output" / "Format" в окне экспорта.
-- Типичные значения: "MP4", "H.264 MP4", "HEVC MP4", "HEVC", "H.264".
-- Скрипт пробует найти меню с подходящим пунктом.
property kFormat : "MP4"

-- Кодек (если в окне экспорта есть отдельный popup).
-- Возможные значения зависят от версии: "H.264", "HEVC", "H.265", "ProRes".
property kCodec : "H.264"

-- Качество. Типичные значения: "High", "Medium", "Low", "Original".
property kQuality : "High"

-- Разрешение. Для .360 проекций обычно: "5.6K", "4K", "1440p", "1080p".
-- Если такой ползунок/popup отсутствует — параметр игнорируется.
property kResolution : "5.6K"

-- World Lock / Horizon Lock — стабилизация, привязанная к миру.
-- true / false / "" (не трогать).
property kWorldLock : true

-- Включать ли звук.
property kIncludeAudio : true

-- Расширение результирующего файла (используется для подстановки в имя).
property kOutputExtension : "mp4"

------------------------------------------------------------------------------
-- ТАЙМИНГИ
------------------------------------------------------------------------------

property kExportSheetTimeout : 30 -- сек, ждать появления окна экспорта
property kExportFinishTimeout : 1800 -- сек, максимальное ожидание завершения
property kBetweenFilesDelay : 1.0 -- пауза между файлами

------------------------------------------------------------------------------

on run argv
	set inputFolder to missing value
	set outputFolder to missing value

	if (count of argv) is greater than or equal to 1 then
		set inputFolder to (POSIX file ((item 1 of argv) as text)) as alias
	end if
	if (count of argv) is greater than or equal to 2 then
		set outputFolder to (POSIX file ((item 2 of argv) as text)) as alias
	end if

	if inputFolder is missing value then
		set inputFolder to choose folder with prompt "Выберите папку с .360 файлами (поиск рекурсивный)"
	end if
	if outputFolder is missing value then
		set outputFolder to choose folder with prompt "Куда сохранять .mp4"
	end if

	set outputPosix to POSIX path of outputFolder

	set sourceFiles to my collect360Files(POSIX path of inputFolder)
	set total to count of sourceFiles
	if total is 0 then
		display dialog "В выбранной папке не найдено .360 файлов." buttons {"OK"} default button 1 with icon caution
		return
	end if

	display notification "Найдено " & total & " файлов. Запускаю GoPro Player." with title "GoPro 360 → MP4"

	tell application kAppName to activate
	delay 1.0

	set processed to 0
	set failed to {}

	repeat with srcPath in sourceFiles
		set processed to processed + 1
		set srcText to srcPath as text
		try
			my logLine("[" & processed & "/" & total & "] " & srcText)
			-- 1. Открыть файл в GoPro Player.
			tell application kAppName to open (POSIX file srcText)
			-- Ждать загрузки клипа: появление главного окна с кнопкой воспроизведения.
			delay 2.0
			my waitForDocumentLoaded()

			-- 2. Запустить экспорт.
			my triggerExport()

			-- 3. Дождаться окна экспорта и применить параметры.
			my waitForExportSheet()
			my applyExportSettings()

			-- 4. Имя файла + папка назначения.
			set baseName to my baseNameWithoutExt(srcText)
			my setExportFileName(baseName & "." & kOutputExtension)
			my navigateSaveSheetToFolder(outputPosix)

			-- 5. Подтвердить экспорт.
			my confirmExportDialog()

			-- 6. Дождаться завершения.
			my waitForExportToFinish()

			-- 7. Закрыть окно клипа, чтобы не копились открытые документы.
			my closeFrontDocument()
			delay kBetweenFilesDelay
		on error errMsg number errNum
			set end of failed to srcText & "  →  " & errMsg & " (" & errNum & ")"
			my logLine("ОШИБКА: " & errMsg)
			-- Пытаемся закрыть возможный sheet/окно перед следующим файлом.
			my dismissAnySheet()
			my closeFrontDocument()
		end try
	end repeat

	if failed is {} then
		display notification "Готово: " & total & " файлов" with title "GoPro 360 → MP4"
	else
		set msg to "Завершено с ошибками (" & (count of failed) & " из " & total & "):" & return & return
		repeat with f in failed
			set msg to msg & (f as text) & return
		end repeat
		display dialog msg buttons {"OK"} default button 1 with icon caution
	end if
end run

------------------------------------------------------------------------------
-- ПОИСК ФАЙЛОВ
------------------------------------------------------------------------------

on collect360Files(rootPosix)
	-- Рекурсивный поиск .360 без учёта регистра. Имена файлов с переводами
	-- строк теоретически возможны, но в footage GoPro не встречаются, так что
	-- разделяем по \n — это корректно работает с `do shell script`.
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

on baseNameWithoutExt(posixPath)
	set AppleScript's text item delimiters to "/"
	set parts to text items of posixPath
	set fileName to last item of parts
	set AppleScript's text item delimiters to "."
	set nameParts to text items of fileName
	if (count of nameParts) > 1 then
		set baseParts to items 1 thru -2 of nameParts
		set baseStr to baseParts as text
	else
		set baseStr to fileName
	end if
	set AppleScript's text item delimiters to ""
	return baseStr
end baseNameWithoutExt

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
			try
				click menu item "Export…" of menu "File" of menu bar 1
				set ok to true
			end try
			if not ok then
				try
					click menu item "Export..." of menu "File" of menu bar 1
					set ok to true
				end try
			end if
			if not ok then
				try
					-- Локализованный пункт.
					click menu item "Экспорт…" of menu "Файл" of menu bar 1
					set ok to true
				end try
			end if
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
			repeat while elapsed < kExportSheetTimeout
				if (exists sheet 1 of window 1) then return
				if (exists window "Export") then return
				delay 0.25
				set elapsed to elapsed + 0.25
			end repeat
		end tell
	end tell
	error "Не дождался окна экспорта"
end waitForExportSheet

on applyExportSettings()
	-- Аккуратно перебираем все popup-кнопки/чекбоксы внутри export sheet
	-- и пытаемся выставить значения. Каждый блок завернут в try, чтобы
	-- отсутствие конкретного контрола не ломало пайплайн.
	tell application "System Events"
		tell process kAppName
			set targetUI to my exportContainer()
			if targetUI is missing value then return

			-- Формат / Output type.
			my setPopupValue(targetUI, {"Output", "Format", "Output Format", "Output Type"}, kFormat)

			-- Кодек.
			my setPopupValue(targetUI, {"Codec", "Video Codec"}, kCodec)

			-- Качество.
			my setPopupValue(targetUI, {"Quality", "Video Quality"}, kQuality)

			-- Разрешение.
			my setPopupValue(targetUI, {"Resolution", "Output Resolution", "Size"}, kResolution)

			-- World Lock / Horizon Lock — checkbox.
			if kWorldLock is true then
				my setCheckbox(targetUI, {"World Lock", "Horizon Lock", "Stabilize"}, true)
			else if kWorldLock is false then
				my setCheckbox(targetUI, {"World Lock", "Horizon Lock", "Stabilize"}, false)
			end if

			-- Звук.
			if kIncludeAudio is true then
				my setCheckbox(targetUI, {"Include Audio", "Audio"}, true)
			else if kIncludeAudio is false then
				my setCheckbox(targetUI, {"Include Audio", "Audio"}, false)
			end if
		end tell
	end tell
end applyExportSettings

on exportContainer()
	-- Возвращает ссылку на UI-элемент, в котором живут контролы экспорта:
	-- либо sheet 1 of window 1, либо отдельное окно "Export".
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then return sheet 1 of window 1
			end try
			try
				if (exists window "Export") then return window "Export"
			end try
		end tell
	end tell
	return missing value
end exportContainer

on setPopupValue(container, labels, desiredValue)
	-- Ищем popup button по label/description/help/title и кликаем нужный пункт.
	if desiredValue is "" then return
	tell application "System Events"
		try
			set popups to every pop up button of container
		on error
			return
		end try
		repeat with pb in popups
			try
				set match to false
				try
					set d to description of pb
					if d is not missing value then
						repeat with lbl in labels
							if d contains (lbl as text) then set match to true
						end repeat
					end if
				end try
				if not match then
					try
						set t to title of pb
						if t is not missing value then
							repeat with lbl in labels
								if t contains (lbl as text) then set match to true
							end repeat
						end if
					end try
				end if
				if match then
					try
						click pb
						delay 0.3
						-- В появившемся menu выбираем нужный пункт по contains.
						try
							set menuItems to every menu item of menu 1 of pb
							repeat with mi in menuItems
								try
									set miName to name of mi
									if miName is not missing value and miName contains desiredValue then
										click mi
										delay 0.2
										return
									end if
								end try
							end repeat
							-- Не нашли — закроем меню Esc'ом.
							key code 53
						end try
					end try
				end if
			end try
		end repeat
	end tell
end setPopupValue

on setCheckbox(container, labels, desiredOn)
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
					set t to title of cb
					if t is not missing value then
						repeat with lbl in labels
							if t contains (lbl as text) then set match to true
						end repeat
					end if
				end try
				if not match then
					try
						set d to description of cb
						if d is not missing value then
							repeat with lbl in labels
								if d contains (lbl as text) then set match to true
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
end setCheckbox

on setExportFileName(newName)
	tell application "System Events"
		tell process kAppName
			set c to my exportContainer()
			if c is missing value then return
			try
				-- Стандартный save-sheet — текстовое поле №1.
				set value of text field 1 of c to newName
			end try
		end tell
	end tell
end setExportFileName

on navigateSaveSheetToFolder(posixFolder)
	tell application "System Events"
		tell process kAppName
			-- ⇧⌘G открывает «Go to Folder…» внутри save sheet'а.
			keystroke "g" using {command down, shift down}
			delay 0.5
			keystroke posixFolder
			delay 0.3
			keystroke return
			delay 0.5
		end tell
	end tell
end navigateSaveSheetToFolder

on confirmExportDialog()
	tell application "System Events"
		tell process kAppName
			set c to my exportContainer()
			if c is missing value then return
			set clicked to false
			repeat with btnName in {"Export", "Save", "OK", "Done", "Экспорт", "Сохранить"}
				if not clicked then
					try
						click button btnName of c
						set clicked to true
					end try
				end if
			end repeat
			if not clicked then
				keystroke return
			end if
		end tell
	end tell
end confirmExportDialog

on waitForExportToFinish()
	-- Считаем экспорт завершённым, когда исчезает sheet/окно с прогрессом
	-- и снова доступны меню. Эвристика, но работает в большинстве версий GoPro Player.
	tell application "System Events"
		tell process kAppName
			set elapsed to 0
			repeat while elapsed < kExportFinishTimeout
				set sheetGone to true
				try
					if (exists sheet 1 of window 1) then set sheetGone to false
				end try
				try
					if (exists window "Export") then set sheetGone to false
				end try
				if sheetGone then
					-- Подстраховка: некоторые версии показывают progress в строке состояния.
					delay 1.0
					set sheetGone2 to true
					try
						if (exists sheet 1 of window 1) then set sheetGone2 to false
					end try
					if sheetGone2 then return
				end if
				delay 1.0
				set elapsed to elapsed + 1
			end repeat
		end tell
	end tell
end waitForExportToFinish

on dismissAnySheet()
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then
					-- Esc закроет большинство sheet'ов.
					key code 53
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
					try
						click button "Don’t Save" of sheet 1 of window 1
					on error
						try
							click button "Don't Save" of sheet 1 of window 1
						on error
							try
								click button "Не сохранять" of sheet 1 of window 1
							end try
						end try
					end try
				end if
			end try
		end tell
	end tell
end closeFrontDocument

on logLine(s)
	-- Пишем в /tmp/gopro_360_to_mp4.log, чтобы можно было следить за прогрессом.
	try
		do shell script "echo " & quoted form of ((current date) as text) & " - " & quoted form of (s as text) & " >> /tmp/gopro_360_to_mp4.log"
	end try
end logLine
