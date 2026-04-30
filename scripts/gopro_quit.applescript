-- gopro_quit.applescript
-- Корректно завершает GoPro Player.

property kAppName : "GoPro Player"

on run
	tell application "System Events"
		if (exists (process kAppName)) then
			tell application kAppName to quit
		end if
	end tell
end run
