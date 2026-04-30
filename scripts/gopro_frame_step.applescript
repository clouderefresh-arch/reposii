-- gopro_frame_step.applescript
-- Покадровая перемотка: «.» — следующий кадр, «,» — предыдущий кадр.
--
-- Использование:
--     osascript gopro_frame_step.applescript next        # на 1 кадр вперёд
--     osascript gopro_frame_step.applescript prev 5      # на 5 кадров назад

property kAppName : "GoPro Player"

on run argv
	set direction to "next"
	set stepCount to 1

	if (count of argv) is greater than or equal to 1 then set direction to (item 1 of argv) as text
	if (count of argv) is greater than or equal to 2 then
		try
			set stepCount to (item 2 of argv) as integer
		end try
	end if

	tell application kAppName to activate
	delay 0.1
	tell application "System Events"
		set frontmost of process kAppName to true
		repeat stepCount times
			if direction is "prev" or direction is "back" or direction is "-" then
				keystroke ","
			else
				keystroke "."
			end if
			delay 0.03
		end repeat
	end tell
end run
