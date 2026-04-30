-- gopro_controller.applescript
-- Универсальная библиотека хендлеров для GoPro Player.
-- Подключение:
--     set gp to (load script POSIX file "/path/to/gopro_controller.applescript")
--     gp's playPause()

property kAppName : "GoPro Player"

-- ---------------------------------------------------------------------------
-- Запуск / завершение
-- ---------------------------------------------------------------------------

on launchPlayer()
	tell application kAppName to activate
	-- Ждём появления хотя бы одного окна, иначе GUI-скриптинг ломается.
	tell application "System Events"
		repeat 30 times
			if (exists (process kAppName)) then exit repeat
			delay 0.1
		end repeat
		set frontmost of process kAppName to true
	end tell
end launchPlayer

on quitPlayer()
	tell application kAppName to quit
end quitPlayer

on isRunning()
	tell application "System Events" to return (exists (process kAppName))
end isRunning

-- ---------------------------------------------------------------------------
-- Работа с файлами
-- ---------------------------------------------------------------------------

on openFile(posixPath)
	set theFile to POSIX file posixPath
	tell application kAppName
		activate
		open theFile
	end tell
end openFile

on openFiles(posixPaths)
	repeat with p in posixPaths
		my openFile(p as text)
	end repeat
end openFiles

-- ---------------------------------------------------------------------------
-- Управление воспроизведением (через GUI-скриптинг)
-- ---------------------------------------------------------------------------

on _activateAndFocus()
	my launchPlayer()
	tell application "System Events"
		set frontmost of process kAppName to true
	end tell
	delay 0.05
end _activateAndFocus

on playPause()
	my _activateAndFocus()
	tell application "System Events" to keystroke space
end playPause

on seekBy(seconds)
	-- Нажимаем стрелку нужное количество раз. В GoPro Player каждое нажатие
	-- ←/→ сдвигает на ~1 секунду, поэтому seconds трактуется как количество шагов.
	my _activateAndFocus()
	set steps to seconds as integer
	if steps > 0 then
		repeat steps times
			tell application "System Events" to key code 124 -- right arrow
			delay 0.02
		end repeat
	else if steps < 0 then
		repeat (-steps) times
			tell application "System Events" to key code 123 -- left arrow
			delay 0.02
		end repeat
	end if
end seekBy

on frameStep(direction)
	-- direction: 1 — следующий кадр (.), -1 — предыдущий кадр (,)
	my _activateAndFocus()
	tell application "System Events"
		if direction is greater than or equal to 0 then
			keystroke "."
		else
			keystroke ","
		end if
	end tell
end frameStep

on toggleFullscreen()
	my _activateAndFocus()
	tell application "System Events"
		-- Универсальный шорткат macOS: ⌃⌘F
		key code 3 using {control down, command down} -- "f"
	end tell
end toggleFullscreen

-- ---------------------------------------------------------------------------
-- Экспорт
-- ---------------------------------------------------------------------------

on exportCurrent()
	-- Открывает диалог File → Export… для активного клипа.
	my _activateAndFocus()
	tell application "System Events"
		tell process kAppName
			-- Пытаемся через меню (английская локаль). Если пункт называется иначе,
			-- упадёт в catch и используем универсальный шорткат ⌘E.
			try
				click menu item "Export…" of menu "File" of menu bar 1
			on error
				try
					click menu item "Export..." of menu "File" of menu bar 1
				on error
					keystroke "e" using {command down}
				end try
			end try
		end tell
	end tell
end exportCurrent

on confirmExportDialog()
	-- Жмёт «Export» / «Save» / «Готово» в открытом sheet'е, если он появился.
	tell application "System Events"
		tell process kAppName
			repeat 30 times
				if (exists sheet 1 of window 1) then exit repeat
				delay 0.2
			end repeat
			if (exists sheet 1 of window 1) then
				try
					click button "Export" of sheet 1 of window 1
				on error
					try
						click button "Save" of sheet 1 of window 1
					on error
						-- Последняя попытка — нажать default-кнопку (Return).
						keystroke return
					end try
				end try
			end if
		end tell
	end tell
end confirmExportDialog

-- ---------------------------------------------------------------------------
-- Сервисное
-- ---------------------------------------------------------------------------

on closeFrontWindow()
	my _activateAndFocus()
	tell application "System Events" to keystroke "w" using {command down}
end closeFrontWindow
