-- gopro_play_pause.applescript
-- Переключает воспроизведение/паузу в GoPro Player (имитирует нажатие пробела).

property kAppName : "GoPro Player"

on run
	tell application kAppName to activate
	delay 0.1
	tell application "System Events"
		set frontmost of process kAppName to true
		keystroke space
	end tell
end run
