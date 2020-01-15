--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local nodesDelay = 0
local nodesTickrate = 4 -- in seconds

local positionDelay = 0
local positionTickrate = 0.1

--local velocityDelay = 0
--local velocityTickrate = 0.1

local inputsDelay = 0
local inputsTickrate = 0.5

local electricsDelay = 0
local electricsTickrate = 3
-- TODO: use common tickrate to increase performances this is just for debugging
-- ============= VARIABLES =============

local function setTickrate(opt, value)
	if value then
		if opt == "nodes" then
			nodesTickrate = value
		elseif opt == "position" then
			positionTickrate = value
		elseif opt == "inputs" then
			inputsTickrate = value
		elseif opt == "electrics" then
			electricsTickrate = value
		end
	else
		if opt == "nodes" then
			return nodesTickrate
		elseif opt == "position" then
			return positionTickrate
		elseif opt == "inputs" then
			return inputsTickrate
		elseif opt == "electrics" then
			return electricsTickrate
		end
	end
end

local function onPlayerConnect()
	-- Update everything for the new connected player
	electricsGE.tick()
	nodesGE.tick()
	positionGE.tick()
	inputsGE.tick()
	powertrainGE.tick()
	--velocityGE.tick()
end



local function onUpdate(dt)
	if 0 then --tonumber(Network.GetTCPStatus()) == 2 then -- If connected

		nodesDelay = nodesDelay + dt
		if nodesDelay > nodesTickrate then
			nodesDelay = 0 -- Reset the delay
			nodesGE.tick() -- Comment this line to disable nodes synchronization
		end

		positionDelay = positionDelay + dt
		if positionDelay > positionTickrate then
			positionDelay = 0 -- Reset the delay
			positionGE.tick() -- Comment this line to disable position synchronization
		end

		--velocityDelay = velocityDelay + dt
		--if velocityDelay > velocityTickrate then
			--velocityDelay = 0 -- Reset the delay
			--velocityGE.tick() -- Comment this line to disable position synchronization
		--end

		inputsDelay = inputsDelay + dt
		if inputsDelay > inputsTickrate then
			inputsDelay = 0 -- Reset the delay
			inputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		electricsDelay = electricsDelay + dt
		if electricsDelay > electricsTickrate then
			electricsDelay = 0 -- Reset the delay
			electricsGE.tick() -- Comment this line to disable electrics synchronization
		end


	end
end



M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate
M.setTickrate         = setTickrate



return M
