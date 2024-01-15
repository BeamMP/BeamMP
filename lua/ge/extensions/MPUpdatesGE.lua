-- BeamMP, the BeamNG.drive multiplayer mod.
-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
--
-- BeamMP Ltd. can be contacted by electronic mail via contact@beammp.com.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

--- MPUpdatesGE API.
--- Author of this documentation is Titch
--- @module MPUpdatesGE
--- @usage onPlayerConnect() -- internal access
--- @usage MPUpdatesGE.onPlayerConnect() -- external access


local M = {}


-- Tickrate - how often data is being sent from the client, in seconds
local nodesTimer = 0
local nodesTickrate = 1/15

local positionTimer = 0
local positionTickrate = 0.020

local inputsTimer = 0
local inputsTickrate = 1/30

local electricsTimer = 0
local electricsTickrate = 1/15

local powertrainTimer = 0
local powertrainTickrate = 1/10


 -- This doesn't do anything because the data isn't queued on the receiving end
local function onPlayerConnect()
	MPElectricsGE.tick()
	nodesGE.tick()
	positionGE.tick()
	MPInputsGE.tick()
	MPPowertrainGE.tick()
end


--- onUpdate is a game eventloop function. It is called each frame by the game engine.
-- This is the main processing thread of BeamMP in the game
-- @param dt float
local function onUpdate(dt)
	if MPGameNetwork and MPGameNetwork.launcherConnected() then
		nodesTimer = nodesTimer + dt
		if nodesTimer >= nodesTickrate then
			nodesTimer = 0
			nodesGE.tick() -- Comment this line to disable nodes synchronization
		end

		positionTimer = positionTimer + dt
		if positionTimer >= positionTickrate then
			positionTimer = 0
			positionGE.tick() -- Comment this line to disable position synchronization
		end

		inputsTimer = inputsTimer + dt
		if inputsTimer >= inputsTickrate then
			inputsTimer = 0
			MPInputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		electricsTimer = electricsTimer + dt
		if electricsTimer >= electricsTickrate then
			electricsTimer = 0
			MPElectricsGE.tick() -- Comment this line to disable electrics synchronization
		end
		
		powertrainTimer = powertrainTimer + dt
		if powertrainTimer >= powertrainTickrate then
			powertrainTimer = 0
			MPPowertrainGE.tick() -- Comment this line to disable powertrain synchronization
		end
	end
end



M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate
M.onInit = function() setExtensionUnloadMode(M, "manual") end


return M
