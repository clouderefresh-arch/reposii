-- gopro_dump_menu.applescript
--
-- Диагностический дампер. Активирует GoPro Player и сохраняет в файл
-- /tmp/gopro_menu_dump.txt полное описание UI (меню + окна + AX-дерево
-- фронтального окна). По этому дампу можно настроить триггер экспорта
-- в gopro_render_then_delete_360.applescript под конкретную версию
-- и локализацию GoPro Player.
--
-- Что должен сделать пользователь:
--   1) Открыть в GoPro Player один .360 файл и ДОЖДАТЬСЯ полной загрузки
--      (полоса прокрутки появилась, кнопка ▶ активна).
--   2) Запустить этот скрипт (osascript / Script Editor / .app).
--   3) Прислать содержимое /tmp/gopro_menu_dump.txt.

property kAppName : "GoPro Player"
property kOutPath : "/tmp/gopro_menu_dump.txt"
property kMaxDepth : 6
property kMaxBytes : 200000

on run
	try
		my resetLog()
		my logLn("=== GoPro Player UI dump ===")
		my logLn("Время: " & ((current date) as text))
		my logLn("")

		tell application kAppName to activate
		delay 0.5

		my dumpMenuBar()
		my logLn("")
		my dumpWindows()
		my logLn("")
		my dumpFrontWindowTree()
		my logLn("")
		my logLn("=== END ===")

		display dialog "Дамп записан в " & kOutPath & return & return & "Пришлите содержимое этого файла следующему агенту:" & return & "cat " & kOutPath buttons {"OK"} default button 1
	on error errMsg number errNum
		try
			my logLn("FATAL: " & errNum & " — " & errMsg)
		end try
		display dialog "Ошибка дампера (" & errNum & "):" & return & return & errMsg buttons {"OK"} default button 1 with icon stop
	end try
end run

------------------------------------------------------------------------------
-- I/O
------------------------------------------------------------------------------

on resetLog()
	do shell script "echo -n '' > " & quoted form of kOutPath
end resetLog

on logLn(theStr)
	try
		do shell script "printf '%s\\n' " & quoted form of (theStr as text) & " >> " & quoted form of kOutPath
	end try
end logLn

on logBytes()
	try
		return (do shell script "/usr/bin/stat -f %z " & quoted form of kOutPath) as integer
	on error
		return 0
	end try
end logBytes

------------------------------------------------------------------------------
-- MENU BAR
------------------------------------------------------------------------------

on dumpMenuBar()
	my logLn("--- MENU BAR ---")
	tell application "System Events"
		tell process kAppName
			try
				set barCount to count of menu bars
				my logLn("menu bars: " & barCount)
				if barCount is 0 then return

				set bar1 to menu bar 1
				set topMenus to every menu of bar1
				my logLn("top menus: " & (count of topMenus))

				repeat with menuRef in topMenus
					set mEl to (contents of menuRef)
					set mName to my safeName(mEl)
					my logLn("")
					my logLn("[MENU] " & mName)
					try
						set itemList to every menu item of mEl
						my logLn("  items: " & (count of itemList))
						repeat with itemRef in itemList
							my dumpMenuItem((contents of itemRef), "  ")
						end repeat
					on error e1
						my logLn("  (не смог перечислить пункты: " & e1 & ")")
					end try
				end repeat
			on error e2
				my logLn("ERROR dumpMenuBar: " & e2)
			end try
		end tell
	end tell
end dumpMenuBar

on dumpMenuItem(itEl, indent)
	set itName to my safeName(itEl)
	set itEnabled to my safeEnabled(itEl)
	set itAxId to my safeAttr(itEl, "AXIdentifier")
	set itCmd to my safeAttr(itEl, "AXMenuItemCmdChar")
	set itMods to my safeAttr(itEl, "AXMenuItemCmdModifiers")
	my logLn(indent & "- name=" & itName & " | enabled=" & itEnabled & " | AXId=" & itAxId & " | cmd=" & itCmd & " | mods=" & itMods)

	-- Подменю, если есть.
	tell application "System Events"
		try
			set subList to every menu item of menu 1 of itEl
			repeat with subRef in subList
				my dumpMenuItem((contents of subRef), indent & "    ")
			end repeat
		end try
	end tell
end dumpMenuItem

------------------------------------------------------------------------------
-- WINDOWS
------------------------------------------------------------------------------

on dumpWindows()
	my logLn("--- WINDOWS ---")
	tell application "System Events"
		tell process kAppName
			try
				set wins to every window
				my logLn("count=" & (count of wins))
				repeat with winRef in wins
					set wEl to (contents of winRef)
					set wName to my safeName(wEl)
					set wRole to my safeRole(wEl)
					set wPos to my safePosition(wEl)
					set wSize to my safeSize(wEl)
					my logLn("- name=" & wName & " | role=" & wRole & " | pos=" & wPos & " | size=" & wSize)
				end repeat
			on error eW
				my logLn("ERROR dumpWindows: " & eW)
			end try
		end tell
	end tell
end dumpWindows

------------------------------------------------------------------------------
-- AX TREE
------------------------------------------------------------------------------

on dumpFrontWindowTree()
	my logLn("--- FRONT WINDOW TREE ---")
	tell application "System Events"
		tell process kAppName
			try
				if (count of windows) is 0 then
					my logLn("(окон нет)")
					return
				end if
				set w1 to window 1
				my dumpElement((contents of w1), 0)
			on error eT
				my logLn("ERROR dumpFrontWindowTree: " & eT)
			end try
		end tell
	end tell
end dumpFrontWindowTree

on dumpElement(el, depth)
	if depth > kMaxDepth then return
	if (my logBytes()) > kMaxBytes then
		my logLn((my pad(depth)) & "... (превышен лимит размера дампа)")
		return
	end if
	set indent to my pad(depth)
	set rRole to my safeRole(el)
	set rName to my safeName(el)
	set rDesc to my safeDesc(el)
	set rAxId to my safeAttr(el, "AXIdentifier")
	set rVal to my safeValue(el)
	my logLn(indent & rRole & "  name=" & rName & "  desc=" & rDesc & "  AXId=" & rAxId & "  value=" & rVal)
	tell application "System Events"
		try
			set kids to every UI element of el
			repeat with kidRef in kids
				my dumpElement((contents of kidRef), depth + 1)
			end repeat
		end try
	end tell
end dumpElement

------------------------------------------------------------------------------
-- Безопасные геттеры (никогда не падают)
------------------------------------------------------------------------------

on safeName(el)
	tell application "System Events"
		try
			set v to name of el
			if v is missing value then return ""
			return (v as text)
		end try
	end tell
	return ""
end safeName

on safeRole(el)
	tell application "System Events"
		try
			set v to role of el
			if v is missing value then return ""
			return (v as text)
		end try
	end tell
	return ""
end safeRole

on safeDesc(el)
	tell application "System Events"
		try
			set v to description of el
			if v is missing value then return ""
			return (v as text)
		end try
	end tell
	return ""
end safeDesc

on safeValue(el)
	tell application "System Events"
		try
			set v to value of el
			if v is missing value then return ""
			return (v as text)
		end try
	end tell
	return ""
end safeValue

on safeEnabled(el)
	tell application "System Events"
		try
			set v to enabled of el
			return (v as text)
		end try
	end tell
	return "?"
end safeEnabled

on safeAttr(el, attrName)
	tell application "System Events"
		try
			set v to value of attribute attrName of el
			if v is missing value then return ""
			return (v as text)
		end try
	end tell
	return ""
end safeAttr

on safePosition(el)
	tell application "System Events"
		try
			set v to position of el
			return (v as text)
		end try
	end tell
	return ""
end safePosition

on safeSize(el)
	tell application "System Events"
		try
			set v to size of el
			return (v as text)
		end try
	end tell
	return ""
end safeSize

on pad(n)
	set s to ""
	repeat n times
		set s to s & "  "
	end repeat
	return s
end pad
