--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Debug menus for monitoring BeamMP performance and more
--====================================================================================

--- @class MPDebug: table
local M = {}

--- Assertion function that logs to the output along with the error.
--- @return boolean
local function assert(condition, message)
	if not condition then
		log('E', 'MPDebug', message)
		error(message, 2)
	end
	return condition
end

--- @param position Point3F
--- @return boolean
local function isPoint3F(position)
	return select(2, pcall(function()
		return type(position.xyz) == 'function'
	end)) == true
end

local function parsePoint3F(...)
	local x, y, z = ...
	if type(x) == 'table' then
		return
			x.x or x[1] or 0,
			x.y or x[2] or 0,
			x.z or x[3] or 0
	end
	return
		type(x) == 'number' and x or 0,
		type(y) == 'number' and y or 0,
		type(z) == 'number' and z or 0
end

--- Teleport the local user's vehicle to the specified position.
--- @vararg Point3F | number
local function tpPlayerToPos(...)
	local activeVehicle = assert(be:getPlayerVehicle(0), 'The current user has no active vehicle.')
	local targetVehRot = quatFromDir(vec3(activeVehicle:getDirectionVector()), vec3(activeVehicle:getDirectionVectorUp()))
	local position = vec3(parsePoint3F(...))
	assert(isPoint3F(position), 'Invalid position.')
	spawn.safeTeleport(activeVehicle, position, targetVehRot, false)
end

--- The dependancies of this extension.
M.dependencies = { 'ui_imgui' }

local gui_module = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}
local im = ui_imgui
local ui_strings = {}

local function onExtensionLoaded()
	gui_module.initialize(gui)
	gui.registerWindow("MPplayerList", im.ImVec2(256, 256))
	gui.registerWindow("MPspawnTeleport", im.ImVec2(256, 256))
	gui.registerWindow("MPnetworkPerf", im.ImVec2(256, 256))
end

local function drawPlayerList()
	if not gui.isWindowVisible("MPplayerList") then return end
	local players = MPVehicleGE.getPlayers()
	if tableIsEmpty(players) then return end
	gui.setupWindow("MPplayerList")
    im.SetNextWindowBgAlpha(0.4)
	im.Begin("MP Developer Tools")

	im.Columns(5, "Bar") -- gimme ein táblázat

	im.Text("Name")
	im.NextColumn()

	im.Text("")
	im.NextColumn()
	im.Text("")
	im.NextColumn()
	im.Text("")
	im.NextColumn()
	im.Text("")
	im.NextColumn()

	local listIndex = 1
	for playerID, player in pairs(players) do
		listIndex = listIndex+1

		if player.isLocal then im.TextColored(im.ImVec4(0.0, 1.0, 1.0, 1.0), player.name) --teal if current user
		else im.Text(player.name) end
		im.NextColumn()

		--im.Text(tostring(ping))
		--im.NextColumn()

		if im.Button("Camera##"..tostring(listIndex)) then MPVehicleGE.teleportCameraToPlayer(player.name) end --focusCameraOnPlayer
		im.NextColumn()

		if im.Button("GPS##"..tostring(listIndex)) then MPVehicleGE.groundmarkerToPlayer(player.name) end
		im.NextColumn()

		if im.Button("Follow##"..tostring(listIndex)) then MPVehicleGE.groundmarkerFollowPlayer(player.name) end
		im.NextColumn()

		if im.Button("Teleport##"..tostring(listIndex)) then MPVehicleGE.teleportVehToPlayer(player.name) end
		im.NextColumn()
	end

	im.Columns(1);
	im.End()
end


local function drawSpawnTeleport()
	if not gui.isWindowVisible("MPspawnTeleport") then return end
	if getMissionFilename() == "" then return end
	gui.setupWindow("MPspawnTeleport")
    --im.SetNextWindowBgAlpha(0.4)
	im.Begin("Teleport menu")


	local listIndex = 1
	im.Columns(2, "Bar");

	im.Text("Name") im.NextColumn()
	im.NextColumn()

	local spawnpoints = extensions.ui_uiNavi and extensions.ui_uiNavi.getSpawnpoints() or {}

	for _, point in pairs(spawnpoints) do
		listIndex = listIndex+1
		im.Text(tostring(ui_strings[point.translationId] or point.objectname))
		im.NextColumn()

		if im.Button("Teleport##"..tostring(listIndex)) then
			tpPlayerToPos(point.pos)
		end
		im.NextColumn()
	end

	im.Columns(1);
	im.End()
end




local var = {}
var.refresh_rate = 1.0 --in Hz
var.refresh_time = 0.0

var.sentCount = im.ArrayFloat(90)
var.sentSize = im.ArrayFloat(90)
var.receivedCount = im.ArrayFloat(90)
var.receivedSize = im.ArrayFloat(90)

var.values_offset = 0
var.last_offset = 0

local sentPacketCount = 0
local receivedPacketCount = 0
local sentPacketSize = 0
local receivedPacketSize = 0

local function avgData(data)
	local sum, max = 0, 0

	for i=0, im.GetLengthArrayFloat(data) do
		sum = sum + data[i]
		if data[i] > max then max = data[i] end
	end
	return sum/im.GetLengthArrayFloat(data), max
end

local function drawPlotWithAvg(format, data, offset, lastVal)
	local avgSent, maxSent = avgData(data)
	im.PlotLines1(string.format(format, lastVal), data, im.GetLengthArrayFloat(data), offset, string.format("avg %.2f, max %i", avgSent or 0, maxSent or 0), 0.0, maxSent, im.ImVec2(0,80))
end

local function drawNetworkPerf()
	if not gui.isWindowVisible("MPnetworkPerf") then return end
	gui.setupWindow("MPnetworkPerf")
    --im.SetNextWindowBgAlpha(0.4)
	im.Begin("Network Performance")


		-- Tip: If your float aren't contiguous but part of a structure, you can pass a pointer to your first float and the sizeof() of your structure in the Stride parameter.
		if refresh_time == 0.0 then var.refresh_time = im.GetTime() end


		if var.refresh_time < im.GetTime() then
			var.sentCount[var.values_offset] = sentPacketCount
			sentPacketCount = 0
			var.receivedCount[var.values_offset] = receivedPacketCount
			receivedPacketCount = 0

			var.sentSize[var.values_offset] = sentPacketSize
			sentPacketSize = 0
			var.receivedSize[var.values_offset] = receivedPacketSize
			receivedPacketSize = 0

			var.last_offset = var.values_offset
			var.values_offset = (var.values_offset + 1) % (im.GetLengthArrayFloat(var.sentCount))
			var.refresh_time = var.refresh_time + 1.0 / var.refresh_rate
		end


		drawPlotWithAvg("Sent packets: %i/s", var.sentCount, var.values_offset, var.sentCount[var.last_offset])
		drawPlotWithAvg("Sent bytes: %.2f KB/s", var.sentSize, var.values_offset, var.sentSize[var.last_offset]/1000.0)

		drawPlotWithAvg("Received packets: %i/s", var.receivedCount, var.values_offset, var.receivedCount[var.last_offset])
		drawPlotWithAvg("Received bytes: %.2f KB/s", var.receivedSize, var.values_offset, var.receivedSize[var.last_offset]/1000.0)

	im.End()
end


local function showUI()
	gui.showWindow("MPplayerList")
	gui.showWindow("MPspawnTeleport")
	gui.showWindow("MPnetworkPerf")
end
local function hideUI()
	gui.hideWindow("MPplayerList")
	gui.hideWindow("MPspawnTeleport")
	gui.hideWindow("MPnetworkPerf")
end

function MP_Console(show)
	if show and show == 1 then
		showUI()
	elseif show == 0 then
		hideUI()
	end
end

local function onUpdate()
	drawPlayerList()
	drawSpawnTeleport()
	drawNetworkPerf()
end

--- Fired when a packet is sent
--- @param bytes number
local function packetSent(bytes)
	sentPacketCount = sentPacketCount + 1
	if type(bytes) == 'number' then
		sentPacketSize = sentPacketSize + bytes
	end
end

--- Fired when a packet is received
--- @param bytes number
local function packetReceived(bytes)
	receivedPacketCount = receivedPacketCount + 1
	if type(bytes) == 'number' then
		receivedPacketSize = receivedPacketSize + bytes
	end
end

M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.packetSent = packetSent
M.packetReceived = packetReceived

return M
