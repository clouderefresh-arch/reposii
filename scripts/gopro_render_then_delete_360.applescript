-- gopro_render_then_delete_360.applescript
--
-- Берёт .360 файлы ПО ОДНОМУ, рендерит каждый в .mp4 через GoPro Player,
-- дожидается реального окончания рендера, проверяет результат и ТОЛЬКО ПОСЛЕ
-- этого удаляет исходник. Затем переходит к следующему файлу.
--
-- ОТКУДА БЕРУТСЯ ИСХОДНИКИ
-- ─────────────────────────
-- Скрипт ищет .360 файлы рекурсивно в одном корневом каталоге. Каталог
-- определяется так (по приоритету):
--   1. CLI-аргумент: osascript gopro_render_then_delete_360.applescript ~/Footage/Max
--   2. Свойство kSourceFolder ниже (если оно не пустое).
--   3. Сохраните скрипт как .app (Script Editor → File → Export → Application)
--      и перетащите на него папку в Finder — обработает её.
--      Можно перетащить и несколько .360 файлов напрямую.
--   4. Если ничего из вышеперечисленного — появится диалог "Выберите папку".
--
-- КУДА СОХРАНЯЕТСЯ РЕЗУЛЬТАТ
-- ──────────────────────────
-- Управляется свойствами kSaveNextToSource и kOutputFolder:
--   kSaveNextToSource = true  → каждый .mp4 сохраняется В ТУ ЖЕ ПАПКУ,
--                                где лежит исходный .360 (рекомендуется
--                                для иерархий вида Project/Subfolder/N/X.360).
--   kSaveNextToSource = false → все .mp4 идут в одну папку kOutputFolder
--                                (если пустая — скрипт спросит при запуске).
--
-- УДАЛЕНИЕ ИСХОДНИКА
-- ──────────────────
-- kDeleteMode: "trash" | "rm" | "none"
--   "trash" — переместить .360 в Корзину через Finder (можно восстановить).
--   "rm"    — удалить безвозвратно.
--   "none"  — не трогать. Полезно для теста.
--
-- ВНИМАНИЕ: автоматическое удаление файлов — потенциально опасно. Перед
-- массовым прогоном проверьте на 1-2 файлах с kDeleteMode = "none".

property kAppName : "GoPro Player"

------------------------------------------------------------------------------
-- ОТКУДА / КУДА / ЧТО ДЕЛАТЬ С ИСХОДНИКОМ
------------------------------------------------------------------------------

-- Жёстко прописанная папка с исходниками (POSIX-путь). Пусто = спросить.
property kSourceFolder : ""

-- true — сохранять рядом с исходником (в его же папку). Это то, что нужно
-- при иерархиях вида Project/.../1/X.360 — рендер появится прямо там.
property kSaveNextToSource : true

-- Используется только если kSaveNextToSource = false.
-- Пусто = спросить один раз при запуске.
property kOutputFolder : ""

-- Что делать с исходным .360 после успешного рендера.
property kDeleteMode : "trash" -- "trash" | "rm" | "none"

------------------------------------------------------------------------------
-- ПАРАМЕТРЫ ЭКСПОРТА (см. диалог "Настройки экспорта")
------------------------------------------------------------------------------

property kResolution : "4K" -- "5,6K" | "4K" | "Пользовательский"
property kCodec : "H.264" -- "HEVC" | "H.264" | "ProRes"

property kWorldLock : false -- "Блокировка направления"
property kHorizonLine : true -- "Линия горизонта"
property kAntiShake : true -- "AntiShake"
property kMountOptimize : false -- "Оптимизация крепления"

-- Слайдеры в долях 0.0..1.0, или missing value — не трогать.
property kSpeedSlider : 0.7
property kQualitySlider : 0.5
property kFileSizeSlider : 0.8
property kBitrate : 0.5
property kDenoiseEnabled : false
property kDenoiseLevel : 0.5

------------------------------------------------------------------------------
-- ТАЙМИНГИ
------------------------------------------------------------------------------

property kSheetTimeout : 30 -- ждать диалог "Настройки экспорта", сек
property kSaveSheetTimeout : 30 -- ждать save sheet после "Далее…", сек
property kRenderTimeout : 3600 -- максимум на один файл, сек
property kStableSeconds : 5 -- сколько секунд .mp4 должен иметь стабильный размер
property kPollInterval : 1.0 -- период опроса файла, сек
property kBetweenFilesDelay : 1.0

------------------------------------------------------------------------------

-- Запуск из osascript / Script Editor / двойным кликом.
on run argv
	set sources to my resolveSourceList(argv)
	my mainLoop(sources)
end run

-- Запуск как droplet: перетащить папку или .360 файлы на сохранённый .app.
on open droppedItems
	set sources to my expandDropped(droppedItems)
	my mainLoop(sources)
end open

------------------------------------------------------------------------------
-- ОПРЕДЕЛЕНИЕ ИСТОЧНИКА
------------------------------------------------------------------------------

on resolveSourceList(argv)
	-- 1. CLI-аргумент.
	if (count of argv) is greater than or equal to 1 then
		set arg to (item 1 of argv) as text
		return my collect360FromPath(arg)
	end if
	-- 2. Свойство.
	if kSourceFolder is not "" then
		return my collect360FromPath(kSourceFolder)
	end if
	-- 3. Диалог.
	set chosen to choose folder with prompt "Выберите папку с .360 файлами (поиск рекурсивный)"
	return my collect360FromPath(POSIX path of chosen)
end resolveSourceList

on expandDropped(droppedList)
	set out to {}
	repeat with itm in droppedList
		set p to POSIX path of itm
		try
			set finfo to (info for itm)
			if folder of finfo is true then
				set sub to my collect360FromPath(p)
				repeat with subItem in sub
					set end of out to (subItem as text)
				end repeat
			else
				if (my endsWithIgnoringCase(p, ".360")) then set end of out to p
			end if
		on error
			if (my endsWithIgnoringCase(p, ".360")) then set end of out to p
		end try
	end repeat
	return out
end expandDropped

on endsWithIgnoringCase(s, suffix)
	set sl to (count of s)
	set xl to (count of suffix)
	if sl < xl then return false
	set tail to text (sl - xl + 1) thru sl of s
	return (my toLower(tail)) is (my toLower(suffix))
end endsWithIgnoringCase

on toLower(s)
	set out to ""
	repeat with c in (characters of s)
		set v to (id of c)
		if v ≥ 65 and v ≤ 90 then
			set out to out & (character id (v + 32))
		else
			set out to out & c
		end if
	end repeat
	return out
end toLower

on collect360FromPath(rootPosix)
	-- Рекурсивный поиск .360 без учёта регистра. Поддерживает и одиночный файл.
	-- Отсекаем macOS AppleDouble-«дубли» вида ._GS010705.360 (служебные файлы
	-- метаданных, которые macOS создаёт на не-APFS томах: NTFS / exFAT / NFS).
	set escaped to my shellQuote(rootPosix)
	set cmd to "if [ -d " & escaped & " ]; then /usr/bin/find " & escaped & " -type f -iname '*.360' -not -name '._*'; elif [ -f " & escaped & " ]; then echo " & escaped & "; fi"
	try
		set rawOutput to do shell script cmd
	on error
		return {}
	end try
	if rawOutput is "" then return {}

	set AppleScript's text item delimiters to (ASCII character 10)
	set parts to text items of rawOutput
	set AppleScript's text item delimiters to ""

	set foundList to {}
	repeat with p in parts
		set s to p as text
		if s is not "" then set end of foundList to s
	end repeat
	return foundList
end collect360FromPath

on shellQuote(s)
	set AppleScript's text item delimiters to "'"
	set parts to text items of s
	set AppleScript's text item delimiters to "'\\''"
	set joined to parts as text
	set AppleScript's text item delimiters to ""
	return "'" & joined & "'"
end shellQuote

------------------------------------------------------------------------------
-- ОСНОВНОЙ ЦИКЛ
------------------------------------------------------------------------------

on mainLoop(sources)
	set total to count of sources
	if total is 0 then
		display dialog "Не найдено ни одного .360 файла." buttons {"OK"} default button 1 with icon caution
		return
	end if

	-- Если kSaveNextToSource = false и kOutputFolder пуст — спросим один раз.
	set globalOutFolder to missing value
	if not kSaveNextToSource then
		set globalOutFolder to my resolveGlobalOutputFolder()
		if globalOutFolder is missing value then return
	end if

	display notification "К обработке: " & total & " файлов" with title "GoPro 360 → MP4"

	tell application kAppName to activate
	delay 1.0

	set processed to 0
	set failed to {}

	repeat with srcRef in sources
		set src to srcRef as text
		set processed to processed + 1
		set baseName to my baseNameWithoutExt(src)

		-- Куда сохранять именно этот файл.
		if kSaveNextToSource then
			set outFolder to my parentFolder(src)
		else
			set outFolder to globalOutFolder
		end if

		try
			my logLine("[" & processed & "/" & total & "] Старт: " & src & "  →  " & outFolder)

			-- Запоминаем "снимок" .mp4-файлов в outFolder ДО рендера —
			-- чтобы потом найти именно вновь появившийся файл (GoPro Player
			-- умеет добавлять timestamp-суффикс к имени, например
			-- GS010712_2026-04-30_08-59-40-032.mp4).
			set beforeMp4s to my listMp4s(outFolder)

			my renderOne(src, outFolder, baseName)

			set producedMp4 to my waitForNewMp4(outFolder, beforeMp4s)
			my waitForOutputStable(producedMp4)

			if not my fileExists(producedMp4) then
				error "Выходной файл не создан"
			end if
			if (my fileSize(producedMp4)) < 1024 then
				error "Выходной файл слишком маленький, рендер сорван: " & producedMp4
			end if

			my deleteSource(src)
			my logLine("Готово: " & src & "  →  " & producedMp4)

			delay kBetweenFilesDelay
		on error errMsg number errNum
			set end of failed to src & "  →  " & errMsg & " (" & errNum & ")"
			my logLine("ОШИБКА: " & src & " — " & errMsg)
			my dismissAnySheet()
			my closeFrontDocument()
		end try
	end repeat

	set okCount to total - (count of failed)
	set summary to "Обработано: " & okCount & " из " & total
	if failed is {} then
		display notification summary with title "GoPro 360 → MP4"
	else
		set msg to summary & return & return & "Ошибки:" & return
		repeat with f in failed
			set msg to msg & (f as text) & return
		end repeat
		display dialog msg buttons {"OK"} default button 1 with icon caution
	end if
end mainLoop

on resolveGlobalOutputFolder()
	if kOutputFolder is not "" then return kOutputFolder
	try
		set f to choose folder with prompt "Выберите папку для сохранения .mp4"
		return POSIX path of f
	on error
		return missing value
	end try
end resolveGlobalOutputFolder

on parentFolder(posixPath)
	set p to posixPath as text
	-- Снимаем trailing slashes, чтобы не получить висящий "//".
	repeat while (count of p) > 1 and (last character of p) is "/"
		set p to text 1 thru -2 of p
	end repeat
	set AppleScript's text item delimiters to "/"
	set parts to text items of p
	if (count of parts) ≤ 1 then
		set AppleScript's text item delimiters to ""
		return "/"
	end if
	set parents to items 1 thru -2 of parts
	set joined to parents as text
	set AppleScript's text item delimiters to ""
	if joined is "" then return "/"
	return joined
end parentFolder

on listMp4s(folderPosix)
	-- Возвращает множество имён .mp4 в папке (без рекурсии).
	-- AppleDouble-«дубли» (._файл.mp4) исключаем — это не настоящие видео.
	try
		set raw to do shell script "/bin/ls -1 " & my shellQuote(folderPosix) & " 2>/dev/null | /usr/bin/grep -i '\\.mp4$' | /usr/bin/grep -v '^\\._' || true"
	on error
		return {}
	end try
	if raw is "" then return {}
	set AppleScript's text item delimiters to (ASCII character 10)
	set rawList to text items of raw
	set AppleScript's text item delimiters to ""
	set out to {}
	repeat with rawItem in rawList
		set lineStr to rawItem as text
		if lineStr is not "" then set end of out to lineStr
	end repeat
	return out
end listMp4s

on waitForNewMp4(folderPosix, beforeList)
	-- Ждём, пока в папке появится новый .mp4 которого не было в beforeList.
	-- Возвращает абсолютный POSIX-путь к нему.
	set elapsed to 0
	repeat while elapsed < kSaveSheetTimeout + 60
		set currentList to my listMp4s(folderPosix)
		repeat with curRef in currentList
			set curName to curRef as text
			if not (my listContains(beforeList, curName)) then
				return folderPosix & "/" & curName
			end if
		end repeat
		delay 1.0
		set elapsed to elapsed + 1.0
	end repeat
	error "В папке не появился новый .mp4 файл: " & folderPosix
end waitForNewMp4

on listContains(lst, needle)
	repeat with xRef in lst
		if (xRef as text) is (needle as text) then return true
	end repeat
	return false
end listContains

on baseNameWithoutExt(posixPath)
	set AppleScript's text item delimiters to "/"
	set parts to text items of posixPath
	set fileName to last item of parts
	set AppleScript's text item delimiters to "."
	set nameParts to text items of fileName
	if (count of nameParts) > 1 then
		set baseParts to items 1 thru -2 of nameParts
		set baseStr to baseParts as text
	else
		set baseStr to fileName
	end if
	set AppleScript's text item delimiters to ""
	return baseStr
end baseNameWithoutExt

------------------------------------------------------------------------------
-- РЕНДЕР ОДНОГО ФАЙЛА
------------------------------------------------------------------------------

on renderOne(srcPosix, outFolderPosix, baseName)
	tell application kAppName to open (POSIX file srcPosix)
	delay 1.5
	my waitForDocumentLoaded()

	my triggerExport()
	my waitForExportSheet()
	my expandAdvancedSection()
	my applyAllSettings()

	-- Жмём "Далее…" — переход к save sheet.
	my clickButtonByNames(my exportContainer(), {"Далее…", "Далее...", "Next…", "Next..."})

	-- Save sheet с именем и папкой.
	my waitForSaveSheet()
	my setSaveFileName(baseName & ".mp4")
	my navigateSaveSheetToFolder(outFolderPosix)
	my clickButtonByNames(my saveSheet(), {"Сохранить", "Save", "Экспорт", "Export"})

	-- Закрываем документ — рендер пойдёт в фоне очереди GoPro Player.
	delay 1.0
	my closeFrontDocument()
end renderOne

------------------------------------------------------------------------------
-- ОЖИДАНИЕ ОКОНЧАНИЯ РЕНДЕРА
------------------------------------------------------------------------------

on waitForOutputStable(mp4Path)
	-- Считаем рендер завершённым, когда:
	--   1) файл существует
	--   2) его размер не меняется в течение kStableSeconds подряд
	-- Так мы не зависим от UI прогресса GoPro Player.
	set elapsed to 0
	set lastSize to -1
	set stableFor to 0

	repeat while elapsed < kRenderTimeout
		if my fileExists(mp4Path) then
			set sz to my fileSize(mp4Path)
			if sz = lastSize and sz > 0 then
				set stableFor to stableFor + kPollInterval
				if stableFor ≥ kStableSeconds then return
			else
				set stableFor to 0
				set lastSize to sz
			end if
		end if
		delay kPollInterval
		set elapsed to elapsed + kPollInterval
	end repeat
	error "Превышен таймаут рендера (" & kRenderTimeout & " сек) для " & mp4Path
end waitForOutputStable

on fileExists(posixPath)
	try
		do shell script "test -e " & my shellQuote(posixPath)
		return true
	on error
		return false
	end try
end fileExists

on fileSize(posixPath)
	try
		set s to do shell script "/usr/bin/stat -f %z " & my shellQuote(posixPath)
		return s as integer
	on error
		return 0
	end try
end fileSize

------------------------------------------------------------------------------
-- УДАЛЕНИЕ ИСХОДНИКА
------------------------------------------------------------------------------

on deleteSource(posixPath)
	if kDeleteMode is "none" then
		my logLine("kDeleteMode=none, не удаляю: " & posixPath)
		return
	end if
	if kDeleteMode is "rm" then
		try
			do shell script "/bin/rm -f " & my shellQuote(posixPath)
			my logLine("rm: " & posixPath)
		on error errMsg
			my logLine("Не удалось rm " & posixPath & ": " & errMsg)
		end try
		return
	end if
	-- По умолчанию — в Корзину через Finder.
	try
		tell application "Finder"
			delete (POSIX file posixPath as alias)
		end tell
		my logLine("В Корзину: " & posixPath)
	on error errMsg
		my logLine("Не удалось переместить в Корзину " & posixPath & ": " & errMsg)
	end try
end deleteSource

------------------------------------------------------------------------------
-- GUI: окна, контейнеры, кнопки
------------------------------------------------------------------------------

on waitForDocumentLoaded()
	tell application "System Events"
		tell process kAppName
			repeat 30 times
				if (exists window 1) then exit repeat
				delay 0.2
			end repeat
		end tell
	end tell
end waitForDocumentLoaded

on triggerExport()
	tell application "System Events"
		set frontmost of process kAppName to true
		tell process kAppName
			set ok to false
			repeat with menuName in {"Файл", "File"}
				repeat with itemName in {"Экспорт…", "Экспорт...", "Export…", "Export..."}
					if not ok then
						try
							click menu item (itemName as text) of menu (menuName as text) of menu bar 1
							set ok to true
						end try
					end if
				end repeat
			end repeat
			if not ok then keystroke "e" using {command down}
		end tell
	end tell
end triggerExport

on waitForExportSheet()
	set elapsed to 0
	repeat while elapsed < kSheetTimeout
		if (my exportContainer()) is not missing value then return
		delay 0.25
		set elapsed to elapsed + 0.25
	end repeat
	error "Не дождался диалога 'Настройки экспорта'"
end waitForExportSheet

on exportContainer()
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then return sheet 1 of window 1
			end try
			repeat with winName in {"Настройки экспорта", "Export Settings"}
				try
					if (exists window (winName as text)) then return window (winName as text)
				end try
			end repeat
			try
				set wlist to every window
				repeat with w in wlist
					try
						set btns to every button of w
						repeat with b in btns
							try
								set bn to name of b
								if bn is in {"Отправить в очередь", "Add to Queue", "Далее…", "Далее...", "Next…", "Next..."} then
									return contents of w
								end if
							end try
						end repeat
					end try
				end repeat
			end try
		end tell
	end tell
	return missing value
end exportContainer

on waitForSaveSheet()
	set elapsed to 0
	repeat while elapsed < kSaveSheetTimeout
		if (my saveSheet()) is not missing value then return
		delay 0.25
		set elapsed to elapsed + 0.25
	end repeat
	error "Не дождался диалога сохранения"
end waitForSaveSheet

on saveSheet()
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then
					-- В save-sheet есть кнопка Сохранить/Save или поле "Имя".
					set s to sheet 1 of window 1
					set hasSave to false
					try
						repeat with bn in {"Сохранить", "Save", "Экспорт", "Export"}
							try
								if exists (button (bn as text) of s) then set hasSave to true
							end try
						end repeat
					end try
					if hasSave then return s
				end if
			end try
		end tell
	end tell
	return missing value
end saveSheet

on setSaveFileName(newName)
	set s to my saveSheet()
	if s is missing value then return
	tell application "System Events"
		tell process kAppName
			try
				set value of text field 1 of s to newName
			end try
		end tell
	end tell
end setSaveFileName

on navigateSaveSheetToFolder(posixFolder)
	tell application "System Events"
		tell process kAppName
			keystroke "g" using {command down, shift down}
			delay 0.5
			keystroke posixFolder
			delay 0.3
			keystroke return
			delay 0.5
		end tell
	end tell
end navigateSaveSheetToFolder

on clickButtonByNames(container, names)
	if container is missing value then return false
	tell application "System Events"
		repeat with nm in names
			try
				click button (nm as text) of container
				delay 0.4
				return true
			end try
		end repeat
	end tell
	return false
end clickButtonByNames

------------------------------------------------------------------------------
-- GUI: применение всех параметров рендера
------------------------------------------------------------------------------

on expandAdvancedSection()
	set c to my exportContainer()
	if c is missing value then return
	tell application "System Events"
		tell process kAppName
			try
				set tris to every UI element of c whose role is "AXDisclosureTriangle"
				repeat with t in tris
					try
						if (value of t as integer) is 0 then
							click t
							delay 0.2
						end if
					end try
				end repeat
			end try
			repeat with bn in {"Расширенные параметры", "Advanced", "Advanced Parameters"}
				try
					click (first button of c whose name is (bn as text))
					delay 0.2
				end try
			end repeat
		end tell
	end tell
end expandAdvancedSection

on applyAllSettings()
	set c to my exportContainer()
	if c is missing value then return

	my selectRadio(c, my resolutionLabels(kResolution))
	my selectRadio(c, my codecLabels(kCodec))

	if kWorldLock is not missing value then ¬
		my setCheckboxByName(c, {"Блокировка направления", "World Lock", "Direction Lock"}, kWorldLock)
	if kHorizonLine is not missing value then ¬
		my setCheckboxByName(c, {"Линия горизонта", "Horizon Line", "Horizon Lock"}, kHorizonLine)
	if kAntiShake is not missing value then ¬
		my setCheckboxByName(c, {"AntiShake", "Anti Shake", "Anti-Shake"}, kAntiShake)
	if kMountOptimize is not missing value then ¬
		my setCheckboxByName(c, {"Оптимизация крепления", "Mount Optimization"}, kMountOptimize)

	if kSpeedSlider is not missing value then ¬
		my setSliderByLabel(c, {"Скорость экспорта", "Export Speed", "Speed"}, kSpeedSlider)
	if kQualitySlider is not missing value then ¬
		my setSliderByLabel(c, {"Качество", "Quality"}, kQualitySlider)
	if kFileSizeSlider is not missing value then ¬
		my setSliderByLabel(c, {"Размер файла", "File Size"}, kFileSizeSlider)
	if kBitrate is not missing value then ¬
		my setSliderByLabel(c, {"Битрейт", "Bitrate"}, kBitrate)

	if kDenoiseEnabled is not missing value then ¬
		my setCheckboxByName(c, {"Denoise"}, kDenoiseEnabled)
	if kDenoiseLevel is not missing value then ¬
		my setSliderByLabel(c, {"Denoise"}, kDenoiseLevel)
end applyAllSettings

on resolutionLabels(v)
	if v is "5,6K" or v is "5.6K" then return {"5,6K", "5.6K"}
	if v is "4K" then return {"4K"}
	if v is "Пользовательский" or v is "Custom" then return {"Пользовательский", "Custom"}
	return {v as text}
end resolutionLabels

on codecLabels(v)
	if v is "HEVC" or v is "H.265" then return {"HEVC", "H.265"}
	if v is "H.264" then return {"H.264"}
	if v is "ProRes" then return {"ProRes"}
	return {v as text}
end codecLabels

on selectRadio(container, labels)
	tell application "System Events"
		set candidates to {}
		try
			set rgs to every radio group of container
			repeat with rg in rgs
				try
					set rbs to every radio button of rg
					repeat with rb in rbs
						set end of candidates to rb
					end repeat
				end try
			end repeat
		end try
		try
			set extra to every radio button of container
			repeat with rb in extra
				set end of candidates to rb
			end repeat
		end try
		repeat with rb in candidates
			try
				set rbName to name of rb
				if rbName is not missing value then
					repeat with lbl in labels
						if (rbName as text) contains (lbl as text) then
							if (value of rb as integer) is 0 then
								click rb
								delay 0.2
							end if
							return
						end if
					end repeat
				end if
			end try
		end repeat
	end tell
end selectRadio

on setCheckboxByName(container, labels, desiredOn)
	tell application "System Events"
		try
			set boxes to every checkbox of container
		on error
			return
		end try
		repeat with cb in boxes
			try
				set match to false
				try
					set t to name of cb
					if t is not missing value then
						repeat with lbl in labels
							if (t as text) contains (lbl as text) then set match to true
						end repeat
					end if
				end try
				if not match then
					try
						set d to description of cb
						if d is not missing value then
							repeat with lbl in labels
								if (d as text) contains (lbl as text) then set match to true
							end repeat
						end if
					end try
				end if
				if match then
					set currentVal to (value of cb as integer)
					if (desiredOn and currentVal is 0) or ((not desiredOn) and currentVal is 1) then
						click cb
						delay 0.2
					end if
					return
				end if
			end try
		end repeat
	end tell
end setCheckboxByName

on setSliderByLabel(container, labels, normalizedValue)
	if normalizedValue < 0 then set normalizedValue to 0
	if normalizedValue > 1 then set normalizedValue to 1
	tell application "System Events"
		set targetSlider to missing value

		try
			set sldList to every slider of container
			repeat with sldRef in sldList
				if targetSlider is missing value then
					set matched to false
					set sldEl to (contents of sldRef)
					try
						set sName to name of sldEl
						if sName is not missing value then
							repeat with lbl in labels
								if (sName as text) contains (lbl as text) then set matched to true
							end repeat
						end if
					end try
					if not matched then
						try
							set sDesc to description of sldEl
							if sDesc is not missing value then
								repeat with lbl in labels
									if (sDesc as text) contains (lbl as text) then set matched to true
								end repeat
							end if
						end try
					end if
					if matched then set targetSlider to sldEl
				end if
			end repeat
		end try

		if targetSlider is missing value then
			try
				set labelEl to missing value
				set txtList to every static text of container
				repeat with txtRef in txtList
					if labelEl is missing value then
						try
							set tv to value of (contents of txtRef)
							if tv is not missing value then
								repeat with lbl in labels
									if (tv as text) contains (lbl as text) then
										set labelEl to (contents of txtRef)
									end if
								end repeat
							end if
						end try
					end if
				end repeat
				if labelEl is not missing value then
					set lblPos to position of labelEl
					set lblY to (item 2 of lblPos) as integer
					set sldList to every slider of container
					set bestSld to missing value
					set bestDy to 99999
					repeat with sldRef in sldList
						try
							set sp to position of (contents of sldRef)
							set sy to (item 2 of sp) as integer
							set dy to sy - lblY
							if dy ≥ 0 and dy < bestDy then
								set bestDy to dy
								set bestSld to (contents of sldRef)
							end if
						end try
					end repeat
					if bestSld is not missing value then set targetSlider to bestSld
				end if
			end try
		end if

		if targetSlider is missing value then return
		try
			try
				set value of targetSlider to normalizedValue
				delay 0.15
				return
			end try
			set sp to position of targetSlider
			set ss to size of targetSlider
			set sx to ((item 1 of sp) as integer) + ((item 1 of ss) as integer) * normalizedValue
			set sy to ((item 2 of sp) as integer) + ((item 2 of ss) as integer) / 2
			tell process kAppName
				click at {sx as integer, sy as integer}
			end tell
			delay 0.15
		end try
	end tell
end setSliderByLabel

on dismissAnySheet()
	tell application "System Events"
		tell process kAppName
			try
				if (exists sheet 1 of window 1) then
					key code 53 -- Esc
					delay 0.3
				end if
			end try
		end tell
	end tell
end dismissAnySheet

on closeFrontDocument()
	tell application "System Events"
		tell process kAppName
			try
				keystroke "w" using {command down}
				delay 0.4
				if (exists sheet 1 of window 1) then
					repeat with bn in {"Не сохранять", "Don’t Save", "Don't Save"}
						try
							click button (bn as text) of sheet 1 of window 1
							exit repeat
						end try
					end repeat
				end if
			end try
		end tell
	end tell
end closeFrontDocument

on logLine(s)
	try
		do shell script "echo " & quoted form of (((current date) as text) & " - " & (s as text)) & " >> /tmp/gopro_360_to_mp4.log"
	end try
end logLine
