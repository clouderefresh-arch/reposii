-- gopro_batch_export_folder.applescript
-- Пакетный экспорт всех видео из выбранной папки.
-- Логика:
--   1. Пользователь выбирает входную папку и папку для экспорта.
--   2. Скрипт по очереди открывает каждый видеофайл в GoPro Player.
--   3. Запускает File → Export…, переходит в нужную папку, подтверждает сохранение.
--   4. Закрывает окно клипа и переходит к следующему файлу.
--
-- ВНИМАНИЕ: время ожидания подобрано «с запасом», но для длинных клипов
-- может потребоваться его увеличить — см. константу kExportWait.

property kAppName : "GoPro Player"
property kVideoExtensions : {"mp4", "mov", "m4v", "lrv", "360"}
property kExportWait : 90 -- максимум секунд ожидания завершения экспорта

on run
	set sourceFolder to choose folder with prompt "Выберите папку с исходными видео"
	set destFolder to choose folder with prompt "Выберите папку для экспорта"
	set destPosix to POSIX path of destFolder

	set videoFiles to my collectVideos(sourceFolder)
	if videoFiles is {} then
		display dialog "В выбранной папке не найдено видеофайлов." buttons {"OK"} default button 1
		return
	end if

	tell application kAppName to activate
	delay 0.5

	repeat with f in videoFiles
		set posixPath to POSIX path of f
		try
			tell application kAppName to open (POSIX file posixPath)
			-- Дать GoPro Player подгрузить клип.
			delay 1.5
			my exportToFolder(destPosix, my baseName(posixPath))
			my waitForExportToFinish()
			my closeFrontDocument()
		on error errMsg number errNum
			log "Ошибка с " & posixPath & ": " & errMsg & " (" & errNum & ")"
		end try
	end repeat

	display notification "Пакетный экспорт завершён" with title "GoPro Player"
end run

-- ---------------------------------------------------------------------------

on collectVideos(theFolder)
	set theList to {}
	tell application "System Events"
		set allFiles to (every file of theFolder)
		repeat with f in allFiles
			set ext to name extension of f
			if ext is not missing value then
				set extLower to my toLower(ext as text)
				if kVideoExtensions contains extLower then
					set end of theList to (POSIX path of (path of f))
				end if
			end if
		end repeat
	end tell
	return theList
end collectVideos

on toLower(s)
	set lower to ""
	repeat with c in (characters of s)
		set asciiVal to (id of c)
		if asciiVal ≥ 65 and asciiVal ≤ 90 then
			set lower to lower & (character id (asciiVal + 32))
		else
			set lower to lower & c
		end if
	end repeat
	return lower
end toLower

on baseName(posixPath)
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
end baseName

on exportToFolder(destPosix, suggestedName)
	tell application "System Events"
		set frontmost of process kAppName to true
		tell process kAppName
			try
				click menu item "Export…" of menu "File" of menu bar 1
			on error
				try
					click menu item "Export..." of menu "File" of menu bar 1
				on error
					keystroke "e" using {command down}
				end try
			end try

			repeat 60 times
				if (exists sheet 1 of window 1) then exit repeat
				delay 0.25
			end repeat

			-- Имя файла (если поле редактируемо).
			try
				set value of text field 1 of sheet 1 of window 1 to suggestedName
			end try

			-- Перейти в нужный каталог сохранения.
			try
				keystroke "g" using {command down, shift down}
				delay 0.4
				keystroke destPosix
				delay 0.2
				keystroke return
				delay 0.4
			end try

			-- Подтвердить экспорт.
			try
				click button "Export" of sheet 1 of window 1
			on error
				try
					click button "Save" of sheet 1 of window 1
				on error
					keystroke return
				end try
			end try
		end tell
	end tell
end exportToFolder

on waitForExportToFinish()
	-- Ждём, пока пропадёт прогресс-окно/sheet. Эвристика, но работает в большинстве случаев.
	tell application "System Events"
		tell process kAppName
			set elapsed to 0
			repeat while elapsed < kExportWait
				if not (exists sheet 1 of window 1) then
					-- Дополнительно ждём чуть-чуть, чтобы убедиться, что экспорт реально закончился.
					delay 1
					if not (exists sheet 1 of window 1) then return
				end if
				delay 1
				set elapsed to elapsed + 1
			end repeat
		end tell
	end tell
end waitForExportToFinish

on closeFrontDocument()
	tell application "System Events"
		tell process kAppName
			try
				keystroke "w" using {command down}
				delay 0.3
				-- Если появится диалог «Save changes?», нажимаем Don't Save.
				if (exists sheet 1 of window 1) then
					try
						click button "Don’t Save" of sheet 1 of window 1
					on error
						try
							click button "Don't Save" of sheet 1 of window 1
						end try
					end try
				end if
			end try
		end tell
	end tell
end closeFrontDocument
