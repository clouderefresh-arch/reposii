-- gopro_seek.applescript
-- Перемотка в GoPro Player на N «шагов» вперёд (положительное число)
-- или назад (отрицательное число). Один шаг ≈ одно нажатие стрелки (~1 секунда).
--
-- Использование:
--     osascript gopro_seek.applescript -- 10        # +10 шагов
--     osascript gopro_seek.applescript -- -5        # -5 шагов
--     (двойное «--» нужно, чтобы osascript не съел отрицательный аргумент)

property kAppName : "GoPro Player"

on run argv
	set steps to 1
	if (count of argv) is greater than 0 then
		try
			set steps to (item 1 of argv) as integer
		on error
			set steps to 1
		end try
	end if

	tell application kAppName to activate
	delay 0.1
	tell application "System Events"
		set frontmost of process kAppName to true
		if steps > 0 then
			repeat steps times
				key code 124 -- стрелка вправо
				delay 0.02
			end repeat
		else if steps < 0 then
			repeat (-steps) times
				key code 123 -- стрелка влево
				delay 0.02
			end repeat
		end if
	end tell
end run
