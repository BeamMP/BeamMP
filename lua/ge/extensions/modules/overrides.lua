--====================================================================================
-- All work by Titch2000
-- You have no permission to edit, redistribute or upload other than for the purposes of contributing. 
-- Contact BeamMP for more info!
--====================================================================================

--- overrides API. Handles the overri
--- Author of this documentation is Titch
--- @module overrides

local M = {}

local applyOverrides = function()
  print('OVERRIDES APPLIED!=============================================================================================================================')
  local original_core_vehicles_cloneCurrent = core_vehicles.cloneCurrent

  core_vehicles.cloneCurrent = function()
    local veh = be:getPlayerVehicle(0)
    local protected = veh:getDynDataFieldbyName("protectedConf", 0)
    if not veh then
      log('E', 'vehicles', 'unable to clone vehicle: player 0 vehicle not found')
      return false
    end
    if protected then
      log('E', 'vehicles', 'unable to clone vehicle: player 0 vehicle is protected')
      return false
    end
    original_core_vehicles_cloneCurrent()
  end

  local original_core_vehicle_partmgmt_saveLocal = extensions.core_vehicle_partmgmt.saveLocal

  extensions.core_vehicle_partmgmt.saveLocal = function(fn)
    local veh = be:getPlayerVehicle(0)
    local protected = veh:getDynDataFieldbyName("protectedConf", 0)
    if not veh then
      log('E', 'vehicles', 'unable to clone vehicle: player 0 vehicle not found')
      return false
    end
    if protected then
      log('E', 'vehicles', 'unable to clone vehicle: player 0 vehicle is protected')
      return false
    end
    original_core_vehicle_partmgmt_saveLocal(fn)
  end


  -- This may be required however need to test the above first before I will know
  local original_spawn_setVehicleObject = spawn.setVehicleObject

  spawn.setVehicleObject = function (veh, options)
    print('RUNNING CUSTOM setVehicleObject FUNCTION')
    local _veh = original_spawn_setVehicleObject(veh, options)
    if options.protectedConf then
      _veh:setDynDataFieldbyName("protectedConf", options.protectedConf)
    end
    return _veh
  end
end

M.onExtensionLoaded = applyOverrides

return M