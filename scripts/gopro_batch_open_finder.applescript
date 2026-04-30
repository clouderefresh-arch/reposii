-- gopro_batch_open_finder.applescript
-- Открывает в GoPro Player все файлы, выделенные в активном окне Finder.
-- Удобно повесить на Quick Action или хоткей.

property kAppName : "GoPro Player"

on run
	tell application "Finder"
		set sel to selection
		if sel is {} then
			display dialog "В Finder не выбрано ни одного файла." buttons {"OK"} default button 1 with icon caution
			return
		end if
		set posixPaths to {}
		repeat with itm in sel
			set end of posixPaths to POSIX path of (itm as alias)
		end repeat
	end tell

	tell application kAppName to activate
	repeat with p in posixPaths
		try
			tell application kAppName to open (POSIX file (p as text))
		on error errMsg
			log "Не удалось открыть " & (p as text) & ": " & errMsg
		end try
	end repeat
end run
