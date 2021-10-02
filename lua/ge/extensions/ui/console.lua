-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"ui_imgui"}

local im = ui_imgui
local windowOpen = im.BoolPtr(false)
local guiModule = require("ge/extensions/editor/api/gui")
local settingsPath = '/settings/consoleNG.json'
local gui = {setupEditorGuiTheme = nop}
local logs = {}
local logsLimit = 5000
local colors = {D = im.ImVec4(0.12,0.75,1,1), I = im.ImVec4(0.3,1,0.3,1), W = im.ImVec4(1,1,0,1), E = im.ImVec4(1,0.2,0.2,1), M = im.ImVec4(1,0.7,0.4,1)}
local iconColors = {D = im.ImColorByRGB(32,196,255,255), I = im.ImColorByRGB(96,255,96,255), W = im.ImColorByRGB(255,255,0,255), E = im.ImColorByRGB(255,64,64,255), M = im.ImColorByRGB(255,144,64,255)}
local iconButtonBgColor = im.ImColorByRGB(0, 0, 0, 0)
local iconButtonFgColor = im.ImColorByRGB(255, 255, 255, 255)
local iconButtonNoColor = im.ImColorByRGB(64, 64, 64, 255)

local rollAvgUpdate = {}
local rollAvgAdd = {}

local levelFilter = {E=true, W=true, I=true, D=true, A=true, M=true}
local viewColumn = {time = im.BoolPtr(true), level = im.BoolPtr(true), origin = im.BoolPtr(true), msg = im.BoolPtr(true)}
local forceAutoScroll = false
local scroll2Bot = true
local scrollMaxPrev = 0
local logFiltered = {}
local logsHead = 1
local logsTail = 1
local initialWindowSize = im.ImVec2(800, 600)
local filterOld = ""
local filterCur = ""
local originFilterImC = im.ArrayChar(256, "")
local invalidOriginFilter = false
local paused = false
local winTitle = beamng_appname..".consoleNG - "..beamng_versiond .." - ".. beamng_buildtype .." - ".. beamng_arch .."##consoleNG"
local consoleInputField = ffi.new("char[4096]", "")
local inputCallbackC = nil
local comboCurrentItem = im.IntPtr(0)
local fontConsoleFact = im.FloatPtr(0.64)
local fullscreen = true
local winstate = {}
local winBgAlpha = {im.FloatPtr(0.9), im.FloatPtr(0.8)}
local loopHistory = im.BoolPtr(false)
local sandboxCmd = im.BoolPtr(true)
local focusOnShow = im.BoolPtr(true)
local enableVehicleControls = true
local historyFilename = '/temp/ConsoleEntryHistory.json'
local history = nil
local historyPos = -1
local comboCtxTxt = "GE - Lua\0GE - TorqueScript\0CEF/UI - JS\0\0"
local vehIds = {}
local helpstr = [[The filters use lua patterns.
use `(%w)` to capture one letter.
use `(core_[%w]+)` to display only core modules (capture `core_` and as many leters possibles).

Character Class:
- x: (where x is not one of the magic characters ^$()%.[]*+-?) represents the character x itself. Use % to excape those characters
- .: (a dot) represents all characters.
- %a: represents all letters.
- %c: represents all control characters.
- %d: represents all digits.
- %g: represents all printable characters except space.
- %l: represents all lowercase letters.
- %p: represents all punctuation characters.
- %s: represents all space characters.
- %u: represents all uppercase letters.
- %w: represents all alphanumeric characters.
- %x: represents all hexadecimal digits.
- [set]: represents the class which is the union of all characters in set. A range of characters can be specified by separating the end characters of the range, in ascending order, with a '-'. All classes %x described above can also be used as components in set. All other characters in set represent themselves. For example, [%w_] (or [_%w]) represents all alphanumeric characters plus the underscore, [0-7] represents the octal digits, and [0-7%l%-] represents the octal digits plus the lowercase letters plus the '-' character.
- You can put a closing square bracket in a set by positioning it as the first character in the set. You can put a hyphen in a set by positioning it as the first or the last character in the set. (You can also use an escape for both cases.)
- The interaction between ranges and classes is not defined. Therefore, patterns like [%a-z] or [a-%%] have no meaning.
- [^set]: represents the complement of set, where set is interpreted as above.

Pattern Item:
- *: Match the previous character (or class) zero or more times, as many times as possible.
- +: Match the previous character (or class) one or more times, as many times as possible.
- -: Match the previous character (or class) zero or more times, as few times as possible.
- ?: Make the previous character (or class) optional.
]]
local filterErr =""
local vehicleActionMaps = {"VehicleCommonActionMap", "VehicleSpecificActionMap"}


local function getIconByIndex(i)
	local cou = 0
	for k,v in pairs(gui.icons) do
		if cou == i then return k,v end
		cou = cou+1
	end
	return "not found", gui.icons.error
end


local function settingsSave()
 local s = {
   ConFontSize = fontConsoleFact[0],
   levelFilter = levelFilter,
   viewColumn = {time = viewColumn.time[0], level = viewColumn.level[0], origin = viewColumn.origin[0], msg = viewColumn.msg[0],
    },
   fullscreen = fullscreen,
   winstate = winstate,
   loopHistory = loopHistory[0],
   sandboxCmd = sandboxCmd[0],
   focusOnShow = focusOnShow[0],
   winBgAlpha = {winBgAlpha[1][0],winBgAlpha[2][0]},
   enableVehicleControls = enableVehicleControls,
 }
 jsonWriteFile(settingsPath, s, true)

end

local function unDefDefault(val, default)
  if val == nil then
    return default
  end
  return val
end

local function settingsLoad()
  local s = jsonReadFile(settingsPath)
  if s then
    fontConsoleFact[0] = s.ConFontSize or 0.64
    levelFilter = s.levelFilter or {E=true, W=true, I=true, D=true, A=true, M=true}
    viewColumn.time[0] = unDefDefault(s.viewColumn.time , true)
    viewColumn.level[0] = unDefDefault(s.viewColumn.level , true)
    viewColumn.origin[0] = unDefDefault(s.viewColumn.origin , true)
    viewColumn.msg[0] = unDefDefault(s.viewColumn.msg , true)
    fullscreen = unDefDefault(s.fullscreen , true)
    sandboxCmd[0] = unDefDefault(s.sandboxCmd , false)
    winstate = s.winstate or {0,0,400,300}
    loopHistory[0] = unDefDefault(s.loopHistory , false)
    focusOnShow[0] = unDefDefault(s.focusOnShow , false)
    if s.winBgAlpha then
      winBgAlpha[1][0] = s.winBgAlpha[1]
      winBgAlpha[2][0] = s.winBgAlpha[2]
    else
      winBgAlpha[1][0] = 0.9
      winBgAlpha[2][0] = 0.8
    end
    enableVehicleControls = unDefDefault(s.enableVehicleControls, true)
  end
end

local function rollAvgAppend(t,val)
  if #t > 30 then
    table.remove(t,1)
  end
  table.insert(t,val)
end

local function rollAvgCalc(t)
  local tmp = 0
  local i = 0
  for _,v in ipairs(t) do
    tmp = tmp + v
    i = i+1
  end
  return tmp/i
end

local function parseLogLine(line)
  local r = {line:match("([%d.]+)|(%a)|([%w_.:]+)|(.+)")}
  if r and #r>1 then
    table.insert(logs,r)
  else
    M.onConsoleLog(0,"","",line)
  end
end

local function parseLog(data)
  for _,f in ipairs(data) do
    parseLogLine(f)
  end
end

local function show()
  windowOpen[0] = true
end

local function hide()
  windowOpen[0] = false
end

local function toggle()
  if windowOpen[0] then
    hide()
  else
    show()
  end
end

local function clearConsole()
  logs = {}
  logFiltered = {}
  logsHead = 1
  logsTail = 1
end

local function checkPattern(pat)
  local status,err = pcall(function() string.match("", pat) end )
  if not status then filterErr = string.match(tostring(err), "%[.*%]:%d*: ?(.*)") end
  return status
end

local function menuToolbar(uiScale)
  if im.BeginMenuBar() then
    if im.BeginMenu("View") then
      local changedParam = false
      changedParam = changedParam or im.MenuItem2("Time", "", viewColumn.time)
      changedParam = changedParam or im.MenuItem2("Level", "", viewColumn.level)
      changedParam = changedParam or im.MenuItem2("Origin", "", viewColumn.origin)
      changedParam = changedParam or im.MenuItem2("Message", "", viewColumn.msg)

      im.Separator()
      changedParam = changedParam or im.MenuItem2("Loop History", "", loopHistory)
      changedParam = changedParam or im.MenuItem2("Sandbox GE Commands", "", sandboxCmd)
      changedParam = changedParam or im.MenuItem2("Focus on Show", "", focusOnShow)
      if changedParam then
        settingsSave()
      end
      im.Separator()

      im.PushItemWidth(120)
      if im.SliderFloat("ConsoleFont size", fontConsoleFact, 0.5, 2) then
        settingsSave()
      end
      if im.SliderFloat("Background Alpha", winBgAlpha[1], 0.0, 1.0) then
        settingsSave()
      end
      if im.SliderFloat("Background Alpha fullscreen", winBgAlpha[2], 0.0, 1.0) then
        settingsSave()
      end

      im.EndMenu()
    end

    if Lua.getDevLogStats then
      local t = Lua:getDevLogStats()
      -- im.Spacing()
      -- im.Spacing()
      if type(t.errors) == 'number' and t.errors > 0 then
        im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), tostring(t.errors) .. 'E ')
        --im.SameLine()
      end
      if type(t.warnings) == 'number' and t.warnings > 0 then
        im.TextColored(im.ImVec4(1.0, 1.0, 0.0, 1.0), tostring(t.warnings) .. 'W')
      end
    end

    if paused then
      im.TextUnformatted("Paused")
    end

    local fsize = 24--*uiScale--im.CalcTextSize("test").y
    if gui.uiIconImageButton(gui.icons.delete, {x=fsize, y=fsize}, iconButtonFgColor.Value, nil, iconButtonBgColor.Value) then
      clearConsole()
    end
    im.tooltip("Clear console")
    -- im.TextUnformatted(string.format("upd=%.3fms add=%.3fms", rollAvgCalc(rollAvgUpdate), rollAvgCalc(rollAvgAdd)) )

    im.SetCursorPosX(im.GetCursorPosX() + im.GetContentRegionAvailWidth() - fsize)
    if gui.uiIconImageButton(fullscreen and gui.icons.fullscreen_exit or gui.icons.fullscreen, {x=fsize, y=fsize}, iconButtonFgColor.Value, nil, iconButtonBgColor.Value) then
      if fullscreen then
        fullscreen = false
        im.SetWindowPos1(im.ImVec2(winstate[1] or 0,winstate[2] or 0), im.ImGuiCond_Always)
        im.SetWindowSize1(im.ImVec2(winstate[3] or 800,winstate[4] or 600), im.ImGuiCond_Always)
      else
        fullscreen = true
        winstate = {im.GetWindowPos().x, im.GetWindowPos().y,
        im.GetWindowSize().x, im.GetWindowSize().y}
      end
      settingsSave()
    end
    im.tooltip(fullscreen and "Exit fullscreen" or "Go fullscreen")

    im.EndMenuBar()
  end
end

--return true if show, false hide
local function _filter(item,originFilter)
  local cl = levelFilter[item[2]]
  if cl or (cl == nil and levelFilter.A) then --level filter
    if originFilter == "" then
      return true
    else --origin filter
      local s,r = pcall(function() return item[3]:lower():match(originFilter) end)
      if s then
        return r ~= nil
      else
        invalidOriginFilter = true
        filterErr = r
        return false
      end
    end
  end
end

local function runFilter(newEntry)
  invalidOriginFilter = not checkPattern(ffi.string(originFilterImC):lower())
  if invalidOriginFilter then return end
  local origFilter = ffi.string(originFilterImC):lower()
  local r
  local lastEntry
  if newEntry then --running filter from that index
    if not logs[newEntry] then
      log("E","runFilter", "entry not found newEntry="..dumps(newEntry).." head="..dumps(logsHead).." tail="..dumps(logsTail))
      return
    end
    r = _filter(logs[newEntry], origFilter)
    if r then
      local i = #logFiltered +1
      logFiltered[i] = newEntry
      if newEntry ~= logsTail-1 then --if multiple line were added
        for j=(newEntry+1),(logsTail-1) do
          if _filter(logs[j], origFilter) then
            i=i+1
            logFiltered[i] = j
          end
        end
      end
    end
  else --running from begening
    logFiltered = {}
    local i = 1
    for k,l in ipairs(logs) do
      -- if type(l) == "table" then
        r = _filter(logs[k], origFilter)
        if r then
          logFiltered[i] = k
          i=i+1
        end
      -- elseif r and type(l) == "string" then
      --   logFiltered[lastEntry] = k
      -- end
    end
    table.sort(logFiltered)
  end
end

local function inputCallback(data)
  --log('D', 'console', '>>> inputCallback 1 - ' .. dumps(data) .. ' / ' .. tostring(#history))
  if data.EventFlag == im.InputTextFlags_CallbackHistory then
    local prevHistoryPos = historyPos
    if data.EventKey == im.Key_UpArrow then
      --print("UP")
      historyPos = historyPos - 1
      if historyPos < 1 then
        if loopHistory[0] or historyPos<0 then
          historyPos = #history
        else
          historyPos = 1
        end
      end
      --log('D', 'console', 'up prev=' .. dumps(prevHistoryPos) .. ' pos=' .. dumps(historyPos))
    elseif data.EventKey == im.Key_DownArrow then
      --print("DOWN")
      historyPos = historyPos + 1
      if historyPos > #history then
        if loopHistory[0] then
          historyPos = 1
        else
          historyPos = #history
        end
      end
      if prevHistoryPos == -1 then historyPos = 1 end
      --log('D', 'console', 'dw prev=' .. dumps(prevHistoryPos) .. ' pos=' .. dumps(historyPos))
    end

    if #history > 0 and prevHistoryPos ~= historyPos then
      local t = history[historyPos]
      if type(t) ~= "string" then
        log("E","inputCallback", "history is corrupted (not str)")
        return im.Int(0)
      end
      local inplen = string.len(t)
      local inplenInt = im.Int(inplen)
      ffi.copy(data.Buf, t, math.min(data.BufSize-1, inplen+1))
      --data.Buf = ffi.string(t, math.min(data.BufSize-1, inplen+1))
      data.CursorPos = inplenInt
      data.SelectionStart = inplenInt
      data.SelectionEnd = inplenInt
      data.BufTextLen = inplenInt
      data.BufDirty = im.Bool(true);
    end
  -- elseif data.EventFlag == im.InputTextFlags_CallbackCharFilter then
  --   print(data.EventChar)
  elseif data.EventFlag == im.InputTextFlags_CallbackCharFilter and data.EventChar == 96 then --96 = '`'
    hide()
    return im.Int(1)
  end
  return im.Int(0)
end

local function shiftTableEntry(t, old, new)
  local value = t[old]
  if new < old then
     table.move(t, new, old - 1, new + 1)
  else
     table.move(t, old + 1, new, old)
  end
  t[new] = value
end

local function setVehicleControlActive(b)
  for _, mapName in ipairs(vehicleActionMaps) do
    local map = scenetree.findObject(mapName)
    if map then
      map:setEnabled(b)
    end
  end
end

local function onConsoleLog(timer, lvl, origin, line)
  local t = ""
  -- local tim = hptimer()
  -- if lvl == "A" then return end --So it doesn't had prints
  if type(timer) == "string" then
    t = timer
  elseif type(timer) == "number" then
    t = string.format("%.3f", timer)
  else
    t = tostring(timer)
  end
  local slashed = split(line,"\n")
  -- print("slash "..dumps(slashed))
  if #slashed == 0 then slashed[1]="" end --fix for empty print
  if tostring(slashed[1]):len() > 4096 then
    logs[logsTail] = {t,lvl,origin,tostring(slashed[1]):sub(1,4096)} --trim so we save memory and don't stress other part of code
  else
    logs[logsTail] = {t,lvl,origin,slashed[1]}
  end
  logsTail = logsTail + 1
  if #slashed > 1 then
    for i=2,#slashed do
      -- logs[logsTail] = slashed[i]
      if tostring(slashed[i]):len() > 4096 then
        logs[logsTail] = {t,lvl,origin,tostring(slashed[i]):sub(1,4096)} --trim so we save memory and don't stress other part of code
      else
        logs[logsTail] = {t,lvl,origin,slashed[i]} --old T3D in-game console duplicate like that. lot simpler
      end
      logsTail = logsTail + 1
    end
  end

  if (logsTail-logsHead) > (logsLimit*1.1) then --cleanup GC
    while logsHead < (logsTail-logsLimit) do
      logs[logsHead] = nil
      logsHead = logsHead +1
    end
    for i=#logFiltered,1,-1 do
      if not logFiltered[i] or logFiltered[i] < logsHead then
        table.remove(logFiltered, i)
      end
    end
  end
  -- while #logs > 500 do
  --   table.remove( logs, 1 )
  -- end
  -- while #logFiltered > 500 do
  --   table.remove( logFiltered, 1 )
  -- end
  runFilter(math.max(logsTail-(#slashed), logsHead))
  -- rollAvgAppend(rollAvgAdd, tim:stopAndReset())
end

local iconIncr = 0

local previouslyShown
local function onUpdate(dtReal, dtSim, dtRaw)
  if windowOpen[0] ~= true then
    if previouslyShown ~= nil then
      setVehicleControlActive(true)
    end
    previouslyShown = nil
    return
  end
  local mustFocusKeyboard = focusOnShow[0] and not previouslyShown
  if not previouslyShown then
    setVehicleControlActive(enableVehicleControls)
  end
  previouslyShown = true
  -- local tim = hptimer()

  if im.IsKeyReleased(112) then --scroll lock
    paused = not paused
  end

  if not paused then
    local flog = Engine.getFrameLog()
    if flog and #flog then
      for _,l in ipairs(flog) do
        onConsoleLog(l[1],l[2],l[3],l[4])
      end
    end
  end

  local uiScale = 1
  if editor and editor.getPreference and editor.getPreference("ui.scale") then
    uiScale = editor.getPreference("ui.scale")
  else
    uiScale = ui_imgui.GetIO().FontGlobalScale
  end

  im.SetNextWindowSize(initialWindowSize, im.Cond_FirstUseEver)
  if fullscreen then
    local vspace = im.GetMainViewport()
    im.SetNextWindowPos(vspace.Pos, im.ImGuiCond_Always)
    im.SetNextWindowSize(vspace.Size, im.ImGuiCond_Always)
    -- im.SetNextWindowFocus()
    im.SetNextWindowBgAlpha(winBgAlpha[2][0])
  else
    im.SetNextWindowBgAlpha(winBgAlpha[1][0])
  end
  if( im.Begin(winTitle, windowOpen, im.WindowFlags_MenuBar + (fullscreen and (im.WindowFlags_NoResize+im.WindowFlags_NoMove+im.WindowFlags_NoCollapse+im.WindowFlags_NoDocking+im.WindowFlags_NoTitleBar) or 0) ) ) then
    menuToolbar(uiScale)

    local imgsize = (im.CalcTextSize("yes_texture.dds").y + im.GetStyle().FramePadding.y * 2) / uiScale

    if gui.uiIconImageButton(gui.icons.error, {x=imgsize, y=imgsize}, levelFilter.E and iconColors.E.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      levelFilter.E = not levelFilter.E
    end
    im.tooltip("Error")
    im.SameLine()

    if gui.uiIconImageButton(gui.icons.warning, {x=imgsize, y=imgsize}, levelFilter.W and iconColors.W.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      levelFilter.W = not levelFilter.W
    end
    im.tooltip("Warning")
    im.SameLine()

    if gui.uiIconImageButton(gui.icons.info, {x=imgsize, y=imgsize}, levelFilter.I and iconColors.I.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      levelFilter.I = not levelFilter.I
    end
    im.tooltip("Info")
    im.SameLine()

    if gui.uiIconImageButton(gui.icons.bug_report, {x=imgsize, y=imgsize}, levelFilter.D and iconColors.D.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      levelFilter.D = not levelFilter.D
    end
    im.tooltip("Debug")
    im.SameLine()

    if gui.uiIconImageButton(gui.icons.help, {x=imgsize, y=imgsize}, levelFilter.A and iconButtonFgColor.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      levelFilter.A = not levelFilter.A
    end
    im.tooltip("Other")
    im.SameLine()

    im.Spacing()
    im.SameLine()

    if gui.uiIconImageButton(gui.icons.people, {x=imgsize, y=imgsize}, levelFilter.M and iconColors.M.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
	  levelFilter.M = not levelFilter.M
    end
    --im.tooltip(iconname)
    im.tooltip("BeamMP")

    im.SameLine()
    im.Spacing()

    local vehicleButtonBgColor = im.GetStyleColorVec4(im.Col_Button)
    if gui.uiIconImageButton(gui.icons.directions_car,{x=imgsize, y=imgsize}, enableVehicleControls and iconButtonFgColor.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      if not enableVehicleControls then
        enableVehicleControls = true
      else
        enableVehicleControls = false
      end
      setVehicleControlActive(enableVehicleControls)
    end
    im.tooltip("Enable Vehicle control while Console window is open")
    im.SameLine()

    if gui.uiIconImageButton(gui.icons.vertical_align_bottom, {x=imgsize, y=imgsize}, forceAutoScroll and iconButtonFgColor.Value or iconButtonNoColor.Value, nil, iconButtonBgColor.Value) then
      forceAutoScroll = not forceAutoScroll
    end
    im.tooltip("Force scroll bar down")
    im.SameLine()

    im.Spacing()
    im.SameLine()

    im.TextUnformatted("Filter(s):")
    im.SameLine()
    im.ShowHelpMarker(helpstr, false) --broken, goes billow text
    im.SameLine()
    -- im.TextUnformatted("(?)")
    --im.tooltip(helpstr)

    -- invalidOriginFilter = checkPattern(ffi.string(originFilterImC))
    -- im.PushItemWidth(260)
    im.TextUnformatted("Origin")
    im.SameLine()
    if invalidOriginFilter then
      im.PushStyleColor2(im.Col_FrameBg, im.ImColorByRGB(255,0,0,255).Value)
    end
    gui.uiInputSearch(nil, originFilterImC, 260 * uiScale)
    -- im.InputText('Origin Filter', originFilterImC, nil)
    if invalidOriginFilter then
      im.SameLine()
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), tostring(filterErr) )
      im.PopStyleColor()
    end

    local numColm = (viewColumn.time[0] and 1 or 0 ) + (viewColumn.level[0] and 1 or 0 ) + (viewColumn.origin[0] and 1 or 0 ) + (viewColumn.msg[0] and 1 or 0 )
    if im.BeginChild1("LogsChild", im.ImVec2(0, -30 * uiScale), true) and numColm>0 then
      im.SetWindowFontScale(fontConsoleFact[0])
      im.Columns(numColm)

      if fullscreen then--if you set any colmun size, you won't be able to resize any
        -- if viewColumn.time[0] and numColm>1 then
        --   im.SetColumnWidth(0,65 * uiScale)
        -- end
        -- if viewColumn.level[0] and numColm>1 then
        --   im.SetColumnWidth((viewColumn.time[0] and 1 or 0 ),20 * uiScale)
        -- end
      else --in windows mod column resize with windows making it unreadable
        if viewColumn.time[0] and numColm>1 then
          im.SetColumnWidth(0,65 * uiScale)
        end
        if viewColumn.level[0] and numColm>1 then
          im.SetColumnWidth((viewColumn.time[0] and 1 or 0 ),20 * uiScale)
        end
        if viewColumn.origin[0] and numColm>1 then
          im.SetColumnWidth((viewColumn.time[0] and 1 or 0 ) + (viewColumn.level[0] and 1 or 0 ),300 * uiScale)
        end

        if (not viewColumn.time[0] or not viewColumn.level[0] or not viewColumn.origin[0] or not viewColumn.msg[0]) and numColm>1 then
          im.SetColumnWidth(numColm-1,99999)
        end
      end

      filterCur = dumps(levelFilter) .. ffi.string(originFilterImC)
      if filterCur ~= filterOld then
        filterOld = filterCur
        runFilter()
      end

      if im.IoFontsGetCount and im.IoFontsGetCount()>1 then
        im.PushFont2(1)
        --im.SetWindowFontScale(1)
      end

      -- for _,l in ipairs(logs) do
      --   if type(l) == "string" then
      --     im.NextColumn()
      --     im.NextColumn()
      --     im.NextColumn()
      --     im.TextUnformatted(l)
      --     im.NextColumn()
      --   else
      --     local lcol = colors[l[2]] or im.ImVec4(1,1,1,1)
      --     local f = levelFilter[l[2]]
      --     if f or (f==nil and levelFilter.A) then
      --       for i,v in ipairs(l) do
      --         im.TextColored(lcol,"%s",tostring(v) )
      --         im.NextColumn()
      --       end
      --     end
      --   end
      --   -- im.Separator()
      --   --im.NewLine()
      -- end

      --------------------------------------------------------------------------------
      --          OLD Ver Print everything
      --------------------------------------------------------------------------------
      -- for _,l in ipairs(logFiltered) do
      --   if type(l) == "string" then
      --     if viewColumn.time[0] then
      --       im.NextColumn()
      --     end
      --     if viewColumn.level[0] then
      --       im.NextColumn()
      --     end
      --     if viewColumn.origin[0] then
      --       im.NextColumn()
      --     end
      --     if viewColumn.msg[0] then
      --       im.TextUnformatted(l)
      --       im.NextColumn()
      --     end
      --   else
      --     local lcol = colors[l[2]] or im.ImVec4(1,1,1,1)
      --     for i,v in ipairs(l) do
      --       if (i == 1 and not viewColumn.time[0])
      --         or (i == 2 and not viewColumn.level[0])
      --         or (i == 3 and not viewColumn.origin[0])
      --         or (i == 4 and not viewColumn.msg[0])
      --         then goto continue_skipcol end

      --       im.TextColored(lcol,"%s",tostring(v) )
      --       if v ~= 2 and im.GetContentRegionAvailWidth() < im.CalcTextSize(tostring(v)).x then
      --         im.tooltip(tostring(v))
      --       end
      --       im.NextColumn()
      --       ::continue_skipcol::
      --     end
      --   end
      -- end

      --------------------------------------------------------------------------------
      --          virtualScroll table
      --------------------------------------------------------------------------------
      -- local displayStart = im.IntPtr(0)
      -- local displayEnd = im.IntPtr(0)
      -- local lines_height = math.floor( im.GetFontSize() + im.GetStyle().ItemSpacing.y )
      -- local lines_count = logsTail - (logsHead+1)
      -- im.CalcListClipping(lines_count, lines_height, displayStart, displayEnd);
      -- im.SetCursorPosY(im.GetCursorPosY() + (displayStart[0] * lines_height));
      -- for i = displayStart[0],displayEnd[0] do
      --   -- im.TextUnformatted(tostring(i))
      --   local l = logs[i+logsHead]
      --   if not l then
      --     -- print( string.format("head = %d\ttail=%d\ti=%d",logsHead,logsTail , i   ))
      --     goto continue_skipline
      --   end
      --   if type(l) == "string" then
      --     if viewColumn.time[0] then
      --       im.NextColumn()
      --     end
      --     if viewColumn.level[0] then
      --       im.NextColumn()
      --     end
      --     if viewColumn.origin[0] then
      --       im.NextColumn()
      --     end
      --     if viewColumn.msg[0] then
      --       im.TextUnformatted(l)
      --       im.NextColumn()
      --     end
      --   else
      --     local lcol = colors[l[2]] or im.ImVec4(1,1,1,1)
      --     for i,v in ipairs(l) do
      --       if (i == 1 and not viewColumn.time[0])
      --         or (i == 2 and not viewColumn.level[0])
      --         or (i == 3 and not viewColumn.origin[0])
      --         or (i == 4 and not viewColumn.msg[0])
      --         then goto continue_skipcol end

      --       im.TextColored(lcol,"%s",tostring(v) )
      --       if v ~= 2 and im.GetContentRegionAvailWidth() < im.CalcTextSize(tostring(v)).x then
      --         im.tooltip(tostring(v))
      --       end
      --       im.NextColumn()
      --       ::continue_skipcol::
      --     end
      --   end
      --   ::continue_skipline::
      -- end
      -- im.SetCursorPosY(im.GetCursorPosY() + ((lines_count - displayEnd[0]) * lines_height));
      local displayStart = im.IntPtr(0)
      local displayEnd = im.IntPtr(0)
      local lines_height = math.floor( im.GetFontSize() + im.GetStyle().ItemSpacing.y )
      local lines_count = #logFiltered
      local offset = 0
      local filidx = ""
      local idxfilter ={}
      -- for k,v in pairs(logFiltered) do
      --   lines_count = lines_count+1
      --   filidx = filidx..dumps(k)..","
      --   table.insert(idxfilter,k)
      -- end
      -- table.sort(idxfilter)
      im.CalcListClipping(lines_count, lines_height, displayStart, displayEnd);
      im.SetCursorPosY(im.GetCursorPosY() + (displayStart[0] * lines_height));
      -- print("lcount="..lines_count.."\t"..dumps(displayStart[0]).."-"..dumps(displayEnd[0]).."\tlen="..dumps(displayEnd[0]-displayStart[0]))
      local filteredStart = displayStart[0]
      -- for k,v in pairs(logFiltered) do
      --   if filteredStart <= 0 then break end
      --   if v == true then
      --     offset = k - logsHead - displayStart[0]
      --     filteredStart = filteredStart -1
      --   end
      -- end
      -- if offset < 0 then offset = 0 end
      -- local prtidx = ""
      -- print("off="..dumps(offset).."\tl_count="..lines_count.."\t"..dumps(displayStart[0]).."-"..dumps(displayEnd[0]))
      -- print(filidx)
      for i = displayStart[0],displayEnd[0],1 do
        -- im.TextUnformatted(tostring(i))
        -- ::looklineagain::
        -- if not logFiltered[i+logsHead+offset] then
        --   local tmp
        --   for k,v in pairs(logFiltered) do
        --     if type(v) == number and (i+logsHead+offset) >k and (i+logsHead+offset)<=v then tmp = true; print("brk");break; end
        --   end
        --   if not tmp and offset < logsTail then offset = offset+1; goto looklineagain end
        --   --if not tmp or offset > lines_count then goto continue_skipline end
        -- end
        -- -- print("logsHead="..dumps(logsHead).."\toffset="..dumps(offset))
        -- prtidx = prtidx .. dumps(i+logsHead+offset)..","
        -- local l = logs[i+logsHead+offset]
        local l = logs[logFiltered[i+1]]
        -- prtidx = prtidx .. dumps(idxfilter[i+1])..","
        if not l then
          -- print( string.format("head = %d\ttail=%d\ti=%d",logsHead,logsTail , i   ))
          if viewColumn.time[0] then
            im.NextColumn()
          end
          if viewColumn.level[0] then
            im.NextColumn()
          end
          if viewColumn.origin[0] then
            im.NextColumn()
          end
          if viewColumn.msg[0] then
            im.NextColumn()
          end
          goto continue_skipline
        end
        if type(l) == "string" then
          if viewColumn.time[0] then
            im.NextColumn()
          end
          if viewColumn.level[0] then
            im.NextColumn()
          end
          if viewColumn.origin[0] then
            im.NextColumn()
          end
          if viewColumn.msg[0] then
            im.TextUnformatted(l)
            im.NextColumn()
          end
        else
          local lcol = colors[l[2]] or im.ImVec4(1,1,1,1)
          for i,v in ipairs(l) do
            if (i == 1 and not viewColumn.time[0])
              or (i == 2 and not viewColumn.level[0])
              or (i == 3 and not viewColumn.origin[0])
              or (i == 4 and not viewColumn.msg[0])
              then goto continue_skipcol end

            -- im.TextColored(lcol,"%s",tostring(v))
            local txtwidth = im.CalcTextSize(tostring(v)).x
            if v ~= 2 and im.GetContentRegionAvailWidth() < txtwidth then
              im.TextColored(lcol,"%s",tostring(v):sub(1,256) )
              txtwidth = txtwidth * (1/fontConsoleFact[0])
              local vp = im.GetWindowViewport()
              local chunkSize = tostring(v):len() * vp.Size.x / txtwidth
              if txtwidth > vp.Size.x or tostring(v):len()>chunkSize then
                local bt = tostring(v)
                local chunk = ""
                while(bt:len() > chunkSize and chunk:len() < 2048) do
                  chunk = chunk..bt:sub(1,chunkSize).."\n"
                  bt = bt:sub(chunkSize+1)
                end
                if bt:len() < chunkSize then
                  chunk = chunk..bt
                else
                  chunk = chunk.."\n...\nToo long to display, check the log file"
                  --chunk = chunk.."\nlsize="..tostring(v):len()
                end
                im.tooltip(chunk)
              else
                im.tooltip(tostring(v))
              end
            else
              im.TextColored(lcol,"%s",tostring(v))
            end
            im.NextColumn()
            ::continue_skipcol::
          end
        end
        ::continue_skipline::
      end
      im.SetCursorPosY(im.GetCursorPosY() + ((lines_count - displayEnd[0]) * lines_height));


      if forceAutoScroll or (scroll2Bot and scrollMaxPrev ~= im.GetScrollMaxY() ) then
        im.SetScrollY(im.GetScrollMaxY())
      end
      scroll2Bot = im.GetScrollMaxY() == im.GetScrollY()
      if scroll2Bot then
        scrollMaxPrev = im.GetScrollMaxY()
      end

      if im.IoFontsGetCount and im.IoFontsGetCount()>1 then
        im.PopFont()
        --im.SetWindowFontScale(1)
      end
      im.SetWindowFontScale(1.0)
    end
    im.EndChild()

    if true then
      local flags = 0
      flags = flags + im.InputTextFlags_EnterReturnsTrue
      flags = flags + im.InputTextFlags_CallbackCompletion
      flags = flags + im.InputTextFlags_CallbackHistory
      flags = flags + im.InputTextFlags_CallbackCharFilter

      im.PushItemWidth(200 * uiScale)
      if im.Combo2("##cmdctx", comboCurrentItem, comboCtxTxt) then
        --print("context changed")
      end
      im.SameLine()

      if mustFocusKeyboard then im.SetKeyboardFocusHere() end
      im.PushItemWidth(im.GetContentRegionAvailWidth() - 70 * uiScale)
      local exec = im.InputText("", consoleInputField, ffi.sizeof(consoleInputField), flags, inputCallbackC)


      im.SameLine()
      im.PushItemWidth(40 * uiScale)
      exec = exec or im.SmallButton("execute")
      if exec then
        previouslyShown = nil
        local cmd = ffi.string(consoleInputField)
        if string.len(cmd) > 0 then

          --print("> history 1 = " .. dumps(history))
          if history[historyPos] ~= cmd then
            table.insert(history, cmd)
          else
            -- move element to the end
            shiftTableEntry(history, historyPos, #history)
          end
          --print("> history 2 = " .. dumps(history))
          historyPos = -1

          --print(" CMD = " .. tostring(cmd))
          if comboCurrentItem[0] == 0 then
            --table.insert(console_log_buffer, {'i', "> " .. tostring(cmd)})
            if sandboxCmd[0] then
              log("I", "exec", "GELua(Sandboxed) < "..dumps(cmd))
              local res, out = executeLuaSandboxed(cmd, 'GEConsole')
              --print(" RES = " .. tostring(res))
              --print(" OUT = " .. dumps(out))
              if res then
                --table.insert(console_log_buffer, {'r', tostring(res)})
                if type(res)=="string" and res:sub(1,7)== "Error: " then
                  log("E", "exec", res)
                else
                  log("I", "exec", "return > "..dumps(res))
                end
              end
              if out and #out > 0 then
                for _, le in ipairs(out) do
                  --table.insert(console_log_buffer, {'o', tostring(le)})
                  log("I", "exec", "output > "..dumps(le))
                end
              end
            else
              log("I", "exec", "GELua(Queue) < "..dumps(cmd))
              Lua:queueLuaCommand(cmd)
            end
          elseif comboCurrentItem[0] == 1 then
            if not cmd:find(";[\n\r\t ]-$") then cmd = cmd..";" end --append semi-colon if missing
            log("I", "exec", "GE TS < "..dumps(cmd))
            TorqueScript.eval(cmd)
          elseif comboCurrentItem[0] == 2 then
            log("I", "exec", "GE UI < "..dumps(cmd))
            be:queueJS(cmd)
          else
            local vid = vehIds[comboCurrentItem[0]-2]
            if not vid then log("E","exec","Selected vehicle invalid");refreshCombo();goto skipcmd end
            local v = be:getObjectByID(vid)
            if not v then log("E","exec","Selected vehicle dosn't exist");refreshCombo();goto skipcmd end
            log("I", "exec", "veh "..tostring(vid).." < "..dumps(cmd))
            v:queueLuaCommand(cmd)
          end

          ffi.fill(consoleInputField, ffi.sizeof(consoleInputField))

          while(#history > 20) do
            table.remove(history, 1)
          end

          jsonWriteFile(historyFilename, history, true)

          --im.SetItemDefaultFocus()
          --im.SetKeyboardFocusHere(-1)
          ::skipcmd::
        end
      end
    end

  end


  im.End() --Begin
  -- log("D","stats", "#logs="..dumps(#logs).." | #logFiltered="..dumps(#logFiltered).. " | update "..dumps(tim:stopAndReset()))
  -- rollAvgAppend(rollAvgUpdate, tim:stopAndReset())
end

local function vehStrInfo(vobj)
  local strI = tostring(vobj:getID())
  strI = strI..", "..vobj:getJBeamFilename()
  if vobj.partConfig:sub(1,1) == "{" or vobj.partConfig:sub(1,1) == "[" then
    strI = strI..", *custom*"
  else
    local vehConfig = string.match(vobj.partConfig, "([^./]*).pc")
    strI = strI..", "..tostring(vehConfig)
  end
  strI = strI..", "..dumps(vobj.licenseText).."\0"
  return strI
end

local function refreshCombo()
  comboCtxTxt = "GE - Lua\0GE - TorqueScript\0CEF/UI - JS\0"
  local vehCount = be:getObjectCount()
  vehIds = {}
  if vehCount > 0  then
    if be:getPlayerVehicle(0) then
      comboCtxTxt = comboCtxTxt.."BeamNG - Current Vehicle "..vehStrInfo(be:getPlayerVehicle(0))
      vehIds = {be:getPlayerVehicleID(0)}
    end
    for i=0,vehCount-1 do
      local v = be:getObject(i)
      table.insert(vehIds, v:getID())
      comboCtxTxt = comboCtxTxt.."BeamNG - "..vehStrInfo(v)
    end
  end
  comboCtxTxt = comboCtxTxt.."\0"
end

local function onSerialize()
  local d = {}
  d.windowOpen = windowOpen[0]
  d.originFilter = ffi.string(originFilterImC)
  local tmp = ffi.string(consoleInputField)
  if tmp and string.len(tmp) >0 then
    d.consoleInputField = tmp
  end
  d.levelFilter = levelFilter
  d.forceAutoScroll = forceAutoScroll
  d.fullscreen = fullscreen
  d.winstate = winstate
  d.scroll2Bot = scroll2Bot
  return d
end

local function onDeserialized(data)
  windowOpen[0] = data.windowOpen or false
  originFilterImC = im.ArrayChar(256, data.originFilter or "")
  if data.levelFilter then
    levelFilter = data.levelFilter
  end
  if data.consoleInputField then
    ffi.copy(consoleInputField, tostring(data.consoleInputField))
  end
  forceAutoScroll = data.forceAutoScroll
  fullscreen = data.fullscreen
  winstate = data.winstate
  scroll2Bot = data.scroll2Bot
end

local function onExtensionLoaded()
  inputCallbackC = ffi.cast("ImGuiInputTextCallback", inputCallback)
  -- log('D', 'onExtensionLoaded', 'inputCallbackC = ' .. tostring(inputCallbackC))
  -- log('D', 'onExtensionLoaded', 'history = ' .. dumps(history))
  settingsLoad()
  if not history then
    history = jsonReadFile(historyFilename) or {}
  end
  guiModule.initialize(gui)
  refreshCombo()
end

local function onFileChanged(filename, type)
  if string.match(string.lower(filename), "/?"..string.lower(historyFilename)) then
    -- log("E","onFileChanged","reload history")
    history = jsonReadFile(historyFilename) or {}
  end
end


M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onUpdate = onUpdate
M.onFileChanged = onFileChanged

M.show = show
M.hide = hide
M.toggle = toggle

local function showIcons()
	for k,v in pairs(gui.icons) do
		dump(k)
	end
end


M.showIcons = showIcons

--M.onConsoleLog = onConsoleLog --hook removed

M.onVehicleDestroyed = refreshCombo
M.onVehicleSwitched = refreshCombo
M.onVehicleSpawned = refreshCombo


return M
