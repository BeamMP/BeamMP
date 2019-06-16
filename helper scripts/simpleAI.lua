-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local controlledVehicles = nil
local oldAISlotCount = -1
local playerVehicleID = -1

-- table that contains the persistent data for the agents
local agents = {}

local function updateControlList()
    local slotCount = BeamEngine:getSlotCount()
    -- try to find vehicles that are not occupied
    --print("scanning ...")
    controlledVehicles = {}
    agents = {} -- reset persistent data as it might not fit anymore
    playerVehicleID = -1
    for objectID = 0, slotCount, 1 do
        local b = BeamEngine:getSlot(objectID)
        if b ~= nil then
            --print(" * " .. objectID .. " = " .. b.activationMode)
            if b.activationMode == 1 then
                playerVehicleID = objectID

            elseif b.activationMode == 0 then
                -- not driven currently :D
                -- lets hijack this vehicle
                --print(" object " .. objectID .. " is now AI controlled")
                table.insert(controlledVehicles, objectID)
                oldAISlotCount = slotCount
            end
        end
    end
end

local function agentSeek(id, agent, targetPos, flee, straight) --PINECONES
    if agents[id] == nil then
        -- init persistent data
        agents[id] = { stopped = 0, touching = 0, tooFar = 0, origSteer = 0, circling = 0, escapeDist = -1}
    end
    -- shortcut to agent data
    local ad = agents[id]

    -- update the basic info for this agent
    ad.pos  = agent:getPosition()
    ad.dir  = agent:getDirection()
    ad.velo = agent:getVelocity()
    ad.velo = ad.velo:length()

    local targetVector = targetPos - ad.pos
    local distance = targetVector:length()

    -- now the velocity
    local throttle = 1
    local brake = 0
    local parkingbrake = 0

    -- prevent it from getting stuck
    if math.abs(ad.velo) >= 0.5 then
        ad.stopped = ad.stopped - (0.05 * math.abs(ad.velo))
    elseif math.abs(ad.velo) < 0.5 then
        ad.stopped = ad.stopped + (0.5 - math.abs(ad.velo))
    end
    if ad.stopped < 0 then ad.stopped = 0 end

    -- if the two cars are touching
    if distance >= 5 and ad.velo >= 5 then
        ad.touching = ad.touching - 0.5
    elseif distance < 5 and ad.velo < 5 then
        ad.touching = ad.touching + 0.2
    end
    if ad.touching < 0 then ad.touching = 0 end

    --if too far away start running up the tooFar variable
    if distance <= 25 then
        ad.tooFar = ad.tooFar - 1
    elseif distance > 25 then
        ad.tooFar = ad.tooFar + (distance * 0.05)
    end
    if distance < 10 then ad.tooFar = 0 end
    if distance > 50 then ad.tooFar = 1000 end
    if ad.tooFar < 0 then ad.tooFar = 0 end

    if agent:getWheel(0) then ad.w0velo = math.abs(agent:getWheel(0).angularVelocity) end
    if agent:getWheel(1) then ad.w1velo = math.abs(agent:getWheel(1).angularVelocity) end
    if agent:getWheel(2) then ad.w2velo = math.abs(agent:getWheel(2).angularVelocity) end
    if agent:getWheel(3) then ad.w3velo = math.abs(agent:getWheel(3).angularVelocity) end

    if not ad.w0velo then ad.w0velo = 0 end
    if not ad.w1velo then ad.w1velo = 0 end
    if not ad.w2velo then ad.w2velo = 0 end
    if not ad.w3velo then ad.w3velo = 0 end

    local avgVelo = (ad.w0velo + ad.w1velo + ad.w2velo + ad.w3velo)/4

    --print(avgVelo)

    -- the steering?
    local dirVector = (math.atan2((ad.pos.y - targetPos.y),(ad.pos.x - targetPos.x))) + (math.pi/2)

    local dirDiff = ad.dir - dirVector
    if dirDiff > math.pi then dirDiff = -1*(math.pi - (math.abs(math.pi - dirDiff))) end
    if dirDiff > 0 then dirDiff = math.pi - dirDiff
    elseif dirDiff < 0 then dirDiff = -math.pi - dirDiff end

    --local flee = false

    --swap the direction variable
    if flee == true then
        if dirDiff >= 0 then
            dirDiff = math.pi - dirDiff
        elseif dirDiff < 0 then
            dirDiff = -math.pi - dirDiff
        end
        dirDiff = -dirDiff
        if math.abs(dirDiff) < 0.3 then dirDiff = 0 end
    end

    local absDirDiff = math.abs(dirDiff)

    local steer = dirDiff

    ad.origSteer = steer

    local reverse = false

    --make it less predictable
    if ad.escapeDist == -1 then
        ad.escapeDist = math.random(5,15)
    end

    --make it stop circling
    if absDirDiff > 1.2 and absDirDiff < 1.94 and distance < 30 and distance > 10 then
        ad.circling = ad.circling + 1
    else
        ad.circling = ad.circling - 1
    end
    if ad.circling < 0 then ad.circling = 0 end

    --make it spin out a bit less
    if reverse == false then
        if absDirDiff > 0.4 and absDirDiff < 1.5 and math.abs(ad.velo) > 8 then
            throttle = 1 - (absDirDiff * 0.2)
            brake = 0
            --print("slowing")
        end
        if absDirDiff >= 1.5 and math.abs(ad.velo) > 8 then
            throttle = 1 - (ad.velo * 0.003)
            brake = 0.5 + (absDirDiff*0.1)
            --print("braking")
            if brake > 1 then brake = 1 end
            if brake > 0.5 then steer = steer * 0.5 end
        end
        --if the player is beside, stop accelerating
        if absDirDiff > 1 and absDirDiff < 2.14 and distance < 3 and math.abs(ad.velo) < 5 then
            throttle = 0
            --reverse = true
        end
        if math.abs(steer) > 0.5 then
            throttle = throttle - (0.2 * math.abs(steer))
        end
    end

    --if they're close enough and the player is behind, back into him
    if absDirDiff > 2.6 and distance < 50 then
        reverse = true
        steer = (math.pi - absDirDiff) * steer
    end

    --if agent backs into player and touches them for too long, drive away
    if ad.touching > 35 and absDirDiff > 2.9 and reverse == true then
        reverse = false
        throttle = 1
    end

    --if the agent is stopped for too long, switch directions
    if ad.stopped > 30 then
        ad.touching = 0
        ad.stopped = ad.stopped + 0.1
        if reverse == true then
            reverse = false
        else
            reverse = true
        end
        steer = -steer
    end


    --stop circling
    if ad.circling > 50 and math.abs(ad.velo) > 3 then
        throttle = -1 + (absDirDiff * 0.6366)
        steer = -steer
    end

    --less steering while backing up
    if reverse == true then
        throttle = -0.5 + (-0.5 * math.abs(dirDiff))
        steer = steer * 0.5
    end

    --make sure the steering is reversed
    if ad.velo < -1 then
        steer = -steer
    end

    --escape!
    if (distance < ad.escapeDist) and ad.touching > 35 then
        throttle = -1 + (absDirDiff * 0.6366)
        steer = dirDiff * 0.1
        ad.touching = 36
        if distance > ad.escapeDist then
            ad.touching = 0
            ad.escapeDist = -1
        end
    end

    --if far enough away, forget about reversing and just turn around
    if ad.tooFar > 250 then
        reverse = false
        steer = math.pi/(math.pi - absDirDiff) * steer
        throttle = ((math.pi - absDirDiff)/math.pi) - (absDirDiff * 0.2)
        if absDirDiff > 0.3 then
            throttle = 0.6
        else
            throttle = 1
        end
    end

    --reset the variable
    if ad.stopped > 100 then ad.stopped = 0 end

    --have it escape

    --PINECONES
    if straight == true then
        steer = 0
        throttle = 1
        brake = 0
    end
    --PINECONES

    if flee == true then
        if absDirDiff > 3 then
            reverse = true
            steer = (math.pi - absDirDiff) * steer
        end
        if absDirDiff > 1 and absDirDiff <= 3 then
            steer = math.random(-1,1) * steer
        end
    end

    --traction control
    if
    math.abs(avgVelo - ad.w0velo) > 15 or
    math.abs(avgVelo - ad.w1velo) > 15 or
    math.abs(avgVelo - ad.w2velo) > 15 or
    math.abs(avgVelo - ad.w3velo) > 15 then
        throttle = throttle * 0.5
        --steer = steer * 1.5
    end

    --print("touching"..ad.touching)
    --print("stopped"..ad.stopped)
    --print("throttle"..throttle)

    --finalizing inputs, guards to ensure variables are within -1 to 1
    throttle = throttle - brake
    if throttle > 1 then throttle = 1 end
    if throttle < -1 then throttle = -1 end

    if steer < -1 then steer = -1 end
    if steer > 1 then steer = 1 end

    if throttle < 0 then
        brake = throttle * -1
        throttle = 0
    end

    -- tell the agent how to move finally
    agent:queueLuaCommand("input.event(\"axisx0\", "..-steer..", 0)")
    agent:queueLuaCommand("input.event(\"axisy0\", "..throttle..", 0)")
    agent:queueLuaCommand("input.event(\"axisy1\", "..brake..", 0)")
    agent:queueLuaCommand("input.event(\"axisy2\", "..parkingbrake..", 0)")
end

local function update(mode)
    local slotCount = BeamEngine:getSlotCount()
    if oldAISlotCount ~= slotCount then updateControlList() end

    --dump(mode)
    local straight = (mode == "straight") --PINECONES
    local flee = (mode == "car0")
    --print("ai mode: " .. mode)

    -- done, we know the AI vehicles and the player controlled vehicles, now the fun begins
    if playerVehicleID ~= -1 then
        local playerVehicle = BeamEngine:getSlot(playerVehicleID)


        if not playerVehicle or playerVehicle.activationMode ~= 1 then
            -- switched, update and retry
            updateControlList()
            return
        end

        local playerPos = playerVehicle:getPosition()
        -- if a player exists, try to drive towards it
        for k, vID in pairs(controlledVehicles) do
            local agent = BeamEngine:getSlot(vID)
            if agent then
                agentSeek(vID, agent, playerPos, flee,straight) --PINECONES
            end
        end
    end
end

local function reset()
    --local slotCount = BeamEngine:getSlotCount()
    --if oldAISlotCount ~= slotCount then updateControlList() end
    updateControlList()

    for k, vID in pairs(controlledVehicles) do
        local agent = BeamEngine:getSlot(vID)
        if agent then
            local luaCommand = "input.event(\"axisx0\", %f, 1);input.event(\"axisy0\", %f, 1);input.event(\"axisy1\", %f, 1); input.event(\"axisy2\", %d, 1)"
            agent:queueLuaCommand( string.format(luaCommand, 0, 0, 0, 0) )
        end
    end
end


-- public interface
M.update = update
M.reset = reset

return M