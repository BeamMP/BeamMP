--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local tPos = {x=0, y=0, z=0}
local vPos = {x=0, y=0, z=0}
local vWeight = 1500
-- ============= VARIABLES =============



local function moveTo(tempWeight, x, y ,z)
	tPos.x = x
	tPos.y = y
	tPos.z = z+1
	vWeight = tempWeight
end



local planet = true
local latestPlanet = {deleted=true}
local planetTimer = 0.1
local planetTimerCurrent = 0
local function onUpdate(dt)

	--[[

	vPos = obj:getPosition()
	local argX = vPos.x - tPos.x
	local argY = vPos.y - tPos.y
	local argZ = vPos.z - tPos.z
	local distance = math.sqrt( argX*argX + argY*argY + argZ*argZ )
	
	if distance > 3 and latestPlanet["deleted"] == true then
		planetTimerCurrent = 0
		
		local velocity = obj:getVelocity()
		
		local velocityMultiplier = 1 + (velocity.x + velocity.y + velocity.z) / (20+distance/10)		
		local forceMultiplier = math.sqrt(distance)/10
		local weightMultiplier = 1+vWeight/5000
		local radius = 45+math.sqrt(distance)
		local planetMass = 15e15 * velocityMultiplier * forceMultiplier
		local pPos = {x=(vPos.x+tPos.x)/2, y=(vPos.y+tPos.y)/2, z=(vPos.z+tPos.z)/2}
		
		if velocityMultiplier > 0.80 and velocityMultiplier < 1.20 and distance < 10 then
			forceMultiplier = math.sqrt(distance)/3
			radius = 20+math.sqrt(distance)
		end
		
		print(distance)
		beamstate.addPlanet(pPos, radius, planetMass, 0.1)
		latestPlanet["position"] = pPos
		latestPlanet["mass"] = planetMass
		latestPlanet["deleted"] = false
		planetTimerCurrent = 0
	end

	if planetTimerCurrent < planetTimer then
		planetTimerCurrent = planetTimerCurrent + dt
	else
		if latestPlanet["deleted"] == false then
			--beamstate.delPlanet(latestPlanet["position"], 10, latestPlanet["mass"])
			latestPlanet["deleted"] = true
		end
	end
	
	--]]
	
end



M.moveTo    = moveTo
M.updateGFX = onUpdate



return M