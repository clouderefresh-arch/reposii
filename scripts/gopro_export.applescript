-- gopro_export.applescript
-- Запускает экспорт активного клипа в GoPro Player через File → Export…
-- и подтверждает диалог сохранения, если он появится.
--
-- При желании можно передать путь к каталогу для сохранения и имя файла:
--     osascript gopro_export.applescript ~/Movies/exports MyClip
--
-- Если параметры не заданы, используется путь, выбранный пользователем
-- в стандартном диалоге GoPro Player.

property kAppName : "GoPro Player"

on run argv
	set destFolder to ""
	set destName to ""
	if (count of argv) is greater than or equal to 1 then set destFolder to (item 1 of argv) as text
	if (count of argv) is greater than or equal to 2 then set destName to (item 2 of argv) as text

	tell application kAppName to activate
	delay 0.2

	tell application "System Events"
		set frontmost of process kAppName to true
		tell process kAppName
			-- 1) Открываем меню экспорта.
			set exportTriggered to false
			try
				click menu item "Export…" of menu "File" of menu bar 1
				set exportTriggered to true
			end try
			if not exportTriggered then
				try
					click menu item "Export..." of menu "File" of menu bar 1
					set exportTriggered to true
				end try
			end if
			if not exportTriggered then
				-- Запасной путь: универсальный шорткат ⌘E.
				keystroke "e" using {command down}
			end if

			-- 2) Ждём появления sheet'а с настройками экспорта.
			repeat 60 times
				if (exists sheet 1 of window 1) then exit repeat
				delay 0.25
			end repeat

			-- 3) Если задан destName — заменяем имя файла.
			if destName is not "" then
				try
					set value of text field 1 of sheet 1 of window 1 to destName
				end try
			end if

			-- 4) Если задан destFolder — открываем "Go to Folder" внутри sheet'а.
			if destFolder is not "" then
				try
					keystroke "g" using {command down, shift down}
					delay 0.4
					keystroke destFolder
					delay 0.2
					keystroke return
					delay 0.4
				end try
			end if

			-- 5) Подтверждаем экспорт.
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
end run
