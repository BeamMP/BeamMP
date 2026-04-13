-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPVoiceChat API. Handles PTT / Open Mic voice chat via the Launcher.
--- Sends capture commands, listener position, volume, and device selection.
--- @module MPVoiceChat

local M = {}

local isTalking = false
local isMuted = false
local openMicActive = false
local positionUpdateInterval = 0.05
local positionTimer = 0
local settingsSyncTimer = 0
local lastVolume = -1
local lastInputDevice = nil
local lastOutputDevice = nil
local lastMode = nil
local lastMicGain = -1
local micLevel = 0
local availableInputDevices = {}
local availableOutputDevices = {}
local pendingDeviceRequest = false
local pendingDeviceTimer = 0
local activeSpeakers = {} -- sourceId -> {name, injected, timestamp}

--- Check if voice chat is enabled in settings
local function isEnabled()
	return settings.getValue("enableVoiceChat") ~= false
end

--- Get the current mic mode: 'ptt' or 'open'
local function getMode()
	return settings.getValue("voiceChatMode") or "ptt"
end

--- Get mute state from settings
local function isMutedSetting()
	return settings.getValue("voiceChatMuted") == true
end

--- Send volume to Launcher (0-100 integer)
local function syncVolume()
	local vol = settings.getValue("voiceChatVolume")
	if vol == nil then vol = 80 end
	if vol ~= lastVolume then
		lastVolume = vol
		MPCoreNetwork.send('Fv' .. tostring(math.floor(vol)))
	end
end

--- Send mic gain to Launcher (0-800, 100=default 4x, 500=20x, 800=32x)
local function syncMicGain()
	local gain = settings.getValue("voiceChatMicGain")
	if gain == nil then gain = 100 end
	gain = math.max(0, math.min(800, math.floor(gain)))
	if gain ~= lastMicGain then
		lastMicGain = gain
		MPCoreNetwork.send('Fg' .. tostring(gain))
	end
end

--- Send device selection to Launcher
local function syncDevices()
	local inputDev = settings.getValue("voiceChatInputDevice") or "default"
	local outputDev = settings.getValue("voiceChatOutputDevice") or "default"
	if inputDev ~= lastInputDevice then
		lastInputDevice = inputDev
		MPCoreNetwork.send('Fi' .. tostring(inputDev))
	end
	if outputDev ~= lastOutputDevice then
		lastOutputDevice = outputDev
		MPCoreNetwork.send('Fo' .. tostring(outputDev))
	end
end

--- Start voice capture (PTT pressed or open-mic activation)
local function startTalking()
	if not MPCoreNetwork or not MPCoreNetwork.isMPSession() then return end
	if isTalking or not isEnabled() then return end
	if getMode() == 'open' then return end
	isTalking = true
	MPCoreNetwork.send('Fs')
	guihooks.trigger('VoiceChatSelfStart')
	extensions.hook('onVoiceChatSelfStart')
	log('D', 'MPVoiceChat', 'PTT: start talking')
end

--- Stop voice capture (PTT released)
local function stopTalking()
	if not MPCoreNetwork or not isTalking then return end
	if getMode() == 'open' then return end
	isTalking = false
	MPCoreNetwork.send('Fe')
	guihooks.trigger('VoiceChatSelfStop')
	extensions.hook('onVoiceChatSelfStop')
	log('D', 'MPVoiceChat', 'PTT: stop talking')
end

--- Toggle mute (for open mic mode, also usable via key binding)
local function toggleMute()
	if not MPCoreNetwork or not MPCoreNetwork.isMPSession() then return end
	if not isEnabled() then return end
	isMuted = not isMuted
	settings.setValue("voiceChatMuted", isMuted)
	if isMuted then
		MPCoreNetwork.send('Fm1')
		guihooks.trigger('VoiceChatSelfStop')
		log('D', 'MPVoiceChat', 'Mute: ON')
	else
		MPCoreNetwork.send('Fm0')
		if openMicActive then
			guihooks.trigger('VoiceChatSelfStart')
		end
		log('D', 'MPVoiceChat', 'Mute: OFF')
	end
end

--- Request device list from Launcher
local function requestDevices()
	if not MPCoreNetwork then return end
	log('I', 'MPVoiceChat', 'Requesting device list from launcher')
	MPCoreNetwork.send('Fd')
end

--- Handle data received from launcher (devices, mic level, etc.)
local function onLauncherData(data)
	if not data or #data < 1 then 
		log('W', 'MPVoiceChat', 'onLauncherData: empty data received')
		return 
	end
	
	log('D', 'MPVoiceChat', 'onLauncherData: received data: ' .. tostring(data))
	
	local subCmd = string.sub(data, 1, 1)
	local payload = string.sub(data, 2)
	
	if subCmd == 'd' then -- Device list
		log('D', 'MPVoiceChat', 'Device list payload: ' .. payload)
		local devices = jsonDecode(payload)
		if devices then
			availableInputDevices = devices.input or {}
			availableOutputDevices = devices.output or {}
			guihooks.trigger('VoiceChatDevicesReceived', devices)
			log('I', 'MPVoiceChat', 'Received devices: ' .. #availableInputDevices .. ' input, ' .. #availableOutputDevices .. ' output')
		else
			log('E', 'MPVoiceChat', 'Failed to decode device JSON: ' .. payload)
		end
	elseif subCmd == 'l' then -- Microphone level (from "Fl" command)
		micLevel = tonumber(payload) or 0
		log('D', 'MPVoiceChat', 'Mic level updated: ' .. micLevel .. '%')
		guihooks.trigger('VoiceChatMicLevel', micLevel)
	elseif subCmd == 'k' then -- Speaking notification: "k<sourceId>:<injected>"
		local sep = string.find(payload, ':')
		if sep then
			local sourceId = tonumber(string.sub(payload, 1, sep - 1))
			local isInjected = string.sub(payload, sep + 1) == '1'
			if sourceId then
				local name = nil
				if MPVehicleGE and MPVehicleGE.getPlayerByID then
					local player = MPVehicleGE.getPlayerByID(sourceId)
					if player then name = player.name end
				end
				activeSpeakers[sourceId] = { name = name or ('Player ' .. sourceId), injected = isInjected, time = os.clock() }
				guihooks.trigger('VoiceChatSpeaking', { id = sourceId, name = activeSpeakers[sourceId].name, injected = isInjected })
				extensions.hook('onVoiceChatSpeaking', sourceId, activeSpeakers[sourceId].name, isInjected)
			end
		end
	end
end

--- Manage open mic state based on settings (called from onUpdate, MPCoreNetwork guaranteed available)
local function updateOpenMicState()
	local mode = getMode()
	local muted = isMutedSetting()

	if mode == 'open' and isEnabled() and MPCoreNetwork.isMPSession() then
		if not openMicActive then
			openMicActive = true
			isMuted = muted
			if not muted then
				MPCoreNetwork.send('Fs')
				guihooks.trigger('VoiceChatSelfStart')
			else
				MPCoreNetwork.send('Fm1')
			end
			log('D', 'MPVoiceChat', 'Open mic: activated')
		end
		if muted ~= isMuted then
			isMuted = muted
			if muted then
				MPCoreNetwork.send('Fm1')
				guihooks.trigger('VoiceChatSelfStop')
			else
				MPCoreNetwork.send('Fm0')
				guihooks.trigger('VoiceChatSelfStart')
			end
		end
	else
		if openMicActive then
			openMicActive = false
			isTalking = false
			MPCoreNetwork.send('Fe')
			guihooks.trigger('VoiceChatSelfStop')
			log('D', 'MPVoiceChat', 'Open mic: deactivated')
		end
	end
end

--- Called every frame.
local function onUpdate(dt)
	if not MPCoreNetwork then return end

	-- Handle pending device request (delayed to ensure socket is ready)
	if pendingDeviceRequest then
		pendingDeviceTimer = pendingDeviceTimer + dt
		if pendingDeviceTimer >= 1.0 then
			pendingDeviceRequest = false
			pendingDeviceTimer = 0
			requestDevices()
			syncVolume()
			syncDevices()
		end
	end

	if not MPCoreNetwork.isMPSession() then
		if isTalking or openMicActive then
			isTalking = false
			openMicActive = false
			guihooks.trigger('VoiceChatSelfStop')
		end
		return
	end

	if not isEnabled() then
		if isTalking or openMicActive then
			MPCoreNetwork.send('Fe')
			isTalking = false
			openMicActive = false
			guihooks.trigger('VoiceChatSelfStop')
		end
		return
	end

	-- Sync settings periodically (volume, devices, mode)
	settingsSyncTimer = settingsSyncTimer + dt
	if settingsSyncTimer >= 0.5 then
		settingsSyncTimer = 0
		syncVolume()
		syncMicGain()
		syncDevices()
		updateOpenMicState()
	end

	-- Clean up stale speakers (>1.5s since last voice packet)
	local now = os.clock()
	for id, info in pairs(activeSpeakers) do
		if now - info.time > 1.5 then
			activeSpeakers[id] = nil
			guihooks.trigger('VoiceChatSpeakingStop', { id = id, name = info.name })
			extensions.hook('onVoiceChatSpeakingStop', id, info.name)
		end
	end

	-- Send listener position
	positionTimer = positionTimer + dt
	if positionTimer < positionUpdateInterval then return end
	positionTimer = 0

	-- G3: Prefer the driven vehicle position for spatial consistency with server-side filtering.
	-- Fall back to camera position if no vehicle is available (e.g., free camera).
	local pos = nil
	local veh = be and be:getPlayerVehicle(0)
	if veh then
		pos = veh:getPosition()
	end
	if not pos then
		pos = getCameraPosition()
	end
	if not pos then return end
	MPCoreNetwork.send(string.format('Fp%.2f,%.2f,%.2f', pos.x, pos.y, pos.z))

	-- Send listener forward vector for stereo panning (real camera direction)
	local fwd = getCameraForward and getCameraForward()
	if fwd then
		MPCoreNetwork.send(string.format('Ff%.3f,%.3f,%.3f', fwd.x, fwd.y, fwd.z))
	end
end

--- Called when joining a server session (via extensions.hook('runPostJoin'))
--- NOTE: Socket may not be ready yet at this point, so we defer device request
local function runPostJoin()
	log('I', 'MPVoiceChat', 'runPostJoin called - initializing voice chat')
	lastVolume = -1
	lastInputDevice = nil
	lastOutputDevice = nil
	lastMode = nil
	openMicActive = false
	isTalking = false
	isMuted = false
	micLevel = 0
	activeSpeakers = {}
	availableInputDevices = {}
	availableOutputDevices = {}
	-- Defer device request to onUpdate to ensure socket is connected
	pendingDeviceRequest = true
	pendingDeviceTimer = 0
end

--- Get the table of currently active speakers (for other extensions to query)
local function getActiveSpeakers()
	return activeSpeakers
end

--- Get current mic level (0-100)
local function getMicLevel()
	return micLevel
end

--- Set mic sensitivity (0-800). 100=default (4x gain), 500=20x, 800=32x max.
local function setMicSensitivity(pct)
	pct = math.max(0, math.min(800, math.floor(tonumber(pct) or 100)))
	log('D', 'MPVoiceChat', 'setMicSensitivity: pct=' .. tostring(pct))
	settings.setValue('voiceChatMicGain', pct)
	lastMicGain = pct
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		MPCoreNetwork.send('Fg' .. tostring(pct))
	else
		log('W', 'MPVoiceChat', 'setMicSensitivity: not in MP session, Fg not sent')
	end
end

--- Get current mic sensitivity setting (0-800, 100=default 4x)
local function getMicSensitivity()
	local gain = settings.getValue('voiceChatMicGain')
	if gain == nil then return 100 end
	return math.max(0, math.min(800, math.floor(gain)))
end

M.startTalking    = startTalking
M.stopTalking     = stopTalking
M.toggleMute      = toggleMute
M.requestDevices  = requestDevices
M.onLauncherData  = onLauncherData
M.onUpdate        = onUpdate
M.runPostJoin     = runPostJoin
M.getActiveSpeakers = getActiveSpeakers
M.getMicLevel       = getMicLevel
M.setMicSensitivity = setMicSensitivity
M.getMicSensitivity = getMicSensitivity
M.isEnabled         = isEnabled
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
