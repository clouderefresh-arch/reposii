-- gopro_dump_menu.applescript
--
-- Диагностический дампер. Активирует GoPro Player и сохраняет в файл
-- /tmp/gopro_menu_dump.txt полное описание:
--   1. Все меню в строке меню с их локализованными именами.
--   2. Все пункты каждого меню (имя, активность, AXIdentifier, shortcut).
--   3. Все окна процесса (имя, role, размер).
--   4. AX-дерево фронтального окна (с ограничением глубины и размера).
--
-- Что должен сделать пользователь:
--   1) Открыть в GoPro Player один .360 файл и ДОЖДАТЬСЯ полной загрузки
--      (полоса прокрутки появится, видео можно проиграть).
--   2) Запустить этот скрипт (двойной клик по .app, собранному из него,
--      или Script Editor → ▶, или osascript).
--   3) Прислать содержимое /tmp/gopro_menu_dump.txt.

property kAppName : "GoPro Player"
property kOutPath : "/tmp/gopro_menu_dump.txt"
property kMaxDepth : 6
property kMaxBytes : 200000

on run
	try
		my reset()
		my writeLine("=== GoPro Player UI dump ===")
		my writeLine("Время: " & ((current date) as text))
		my writeLine("Скрипт: " & (POSIX path of (path to me)))
		my writeLine("")

		tell application kAppName to activate
		delay 0.5

		my dumpMenuBar()
		my writeLine("")
		my dumpWindows()
		my writeLine("")
		my dumpFrontWindowTree()
		my writeLine("")
		my writeLine("=== END ===")

		display dialog "Дамп записан в " & kOutPath & return & return & "Пришлите содержимое этого файла следующему агенту." buttons {"OK"} default button 1
	on error errMsg number errNum
		try
			my writeLine("FATAL: " & errNum & " — " & errMsg)
		end try
		display dialog "Ошибка дампера (" & errNum & "):" & return & return & errMsg buttons {"OK"} default button 1 with icon stop
	end try
end run

on reset()
	do shell script "echo -n '' > " & quoted form of kOutPath
end reset

on writeLine(s)
	try
		do shell script "printf '%s\\n' " & quoted form of (s as text) & " >> " & quoted form of kOutPath
	end try
end writeLine

on bytesWritten()
	try
		return (do shell script "/usr/bin/stat -f %z " & quoted form of kOutPath) as integer
	on error
		return 0
	end try
end bytesWritten

on dumpMenuBar()
	my writeLine("--- MENU BAR ---")
	tell application "System Events"
		tell process kAppName
			try
				set bars to every menu bar
				my writeLine("menu bars: " & (count of bars))
				if (count of bars) > 0 then
					set bar1 to menu bar 1
					set topMenus to every menu of bar1
					my writeLine("top menus: " & (count of topMenus))
					repeat with m in topMenus
						set mEl to (contents of m)
						set mName to ""
						try
							set mName to (name of mEl as text)
						end try
						my writeLine("")
						my writeLine("[MENU] " & mName)
						try
							set items_ to every menu item of mEl
							my writeLine("  items: " & (count of items_))
							repeat with it in items_
								set itEl to (contents of it)
								my dumpMenuItem(itEl, "  ")
							end repeat
						on error e
							my writeLine("  (не смог перечислить пункты: " & e & ")")
						end try
					end repeat
				end if
			on error e
				my writeLine("ОШИБКА dumpMenuBar: " & e)
			end try
		end tell
	end tell
end dumpMenuBar

on dumpMenuItem(itEl, indent)
	set itName to ""
	set itEnabled to "?"
	set itAxId to ""
	set itCmd to ""
	set itMods to ""
	try
		set itName to (name of itEl as text)
	end try
	try
		set itEnabled to (enabled of itEl as text)
	end try
	try
		set itAxId to (value of attribute "AXIdentifier" of itEl as text)
	end try
	try
		set itCmd to (value of attribute "AXMenuItemCmdChar" of itEl as text)
	end try
	try
		set itMods to (value of attribute "AXMenuItemCmdModifiers" of itEl as text)
	end try
	my writeLine(indent & "- name=" & itName & " | enabled=" & itEnabled & " | AXId=" & itAxId & " | cmd=" & itCmd & " | mods=" & itMods)
	-- Подменю.
	try
		set sub to menu 1 of itEl
		try
			set subItems to every menu item of sub
			repeat with sItem in subItems
				my dumpMenuItem((contents of sItem), indent & "    ")
			end repeat
		end try
	end try
end dumpMenuItem

on dumpWindows()
	my writeLine("--- WINDOWS ---")
	tell application "System Events"
		tell process kAppName
			try
				set wins to every window
				my writeLine("count=" & (count of wins))
				repeat with w in wins
					set wEl to (contents of w)
					set wName to ""
					set wRole to ""
					set wPos to ""
					set wSize to ""
					try
						set wName to (name of wEl as text)
					end try
					try
						set wRole to (role of wEl as text)
					end try
					try
						set wPos to (position of wEl as text)
					end try
					try
						set wSize to (size of wEl as text)
					end try
					my writeLine("- window name=" & wName & " | role=" & wRole & " | pos=" & wPos & " | size=" & wSize)
				end repeat
			on error e
				my writeLine("ОШИБКА dumpWindows: " & e)
			end try
		end tell
	end tell
end dumpWindows

on dumpFrontWindowTree()
	my writeLine("--- FRONT WINDOW TREE ---")
	tell application "System Events"
		tell process kAppName
			try
				if (count of windows) is 0 then
					my writeLine("(окон нет)")
					return
				end if
				set w to window 1
				my dumpElement((contents of w), 0)
			on error e
				my writeLine("ОШИБКА dumpFrontWindowTree: " & e)
			end try
		end tell
	end tell
end dumpFrontWindowTree

on dumpElement(el, depth)
	if depth > kMaxDepth then return
	if (my bytesWritten()) > kMaxBytes then
		my writeLine((my pad(depth)) & "... (превышен лимит размера дампа)")
		return
	end if
	set indent to my pad(depth)
	set role_ to ""
	set name_ to ""
	set desc_ to ""
	set axId to ""
	set val_ to ""
	try
		set role_ to (role of el as text)
	end try
	try
		set name_ to (name of el as text)
	end try
	try
		set desc_ to (description of el as text)
	end try
	try
		set axId to (value of attribute "AXIdentifier" of el as text)
	end try
	try
		set val_ to (value of el as text)
	end try
	my writeLine(indent & role_ & "  name=" & name_ & "  desc=" & desc_ & "  AXId=" & axId & "  value=" & val_)
	try
		set kids to every UI element of el
		repeat with k in kids
			my dumpElement((contents of k), depth + 1)
		end repeat
	end try
end dumpElement

on pad(n)
	set s to ""
	repeat n times
		set s to s & "  "
	end repeat
	return s
end pad
