-- gopro_fullscreen.applescript
-- Переключает полноэкранный режим в GoPro Player.
-- Сначала пытается вызвать пункт меню View → Enter/Exit Full Screen,
-- иначе — использует системный шорткат ⌃⌘F.

property kAppName : "GoPro Player"

on run
	tell application kAppName to activate
	delay 0.1
	tell application "System Events"
		set frontmost of process kAppName to true
		tell process kAppName
			try
				click menu item "Enter Full Screen" of menu "View" of menu bar 1
			on error
				try
					click menu item "Exit Full Screen" of menu "View" of menu bar 1
				on error
					-- Универсальный системный шорткат полноэкранного режима.
					key code 3 using {control down, command down} -- "f"
				end try
			end try
		end tell
	end tell
end run
