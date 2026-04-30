-- gopro_open_file.applescript
-- Открывает указанный файл (или несколько) в GoPro Player.
--
-- Использование:
--     osascript gopro_open_file.applescript /path/to/movie.MP4 [/path/to/another.MP4 ...]
--     либо запустить без аргументов — появится диалог выбора файлов.

property kAppName : "GoPro Player"

on run argv
	if (count of argv) is 0 then
		set chosen to choose file with prompt "Выберите видео для GoPro Player" of type {"public.movie", "com.apple.quicktime-movie", "public.mpeg-4"} with multiple selections allowed
		set posixPaths to {}
		repeat with f in chosen
			set end of posixPaths to POSIX path of f
		end repeat
	else
		set posixPaths to argv
	end if

	tell application kAppName to activate

	repeat with p in posixPaths
		try
			set theFile to POSIX file (p as text)
			tell application kAppName to open theFile
		on error errMsg number errNum
			log "Не удалось открыть " & (p as text) & ": " & errMsg & " (" & errNum & ")"
		end try
	end repeat
end run
