local M = {}
print("Loader Loading...")

local function onInit()
  extensions.load("UI")
  --extensions.registerCoreModule("UI")

  --load("sessionControl")
  --registerCoreModule("sessionControl")

  extensions.load("vehicleGE")
  --extensions.registerCoreModule("vehicleGE")

  extensions.load("inputsGE")
  --extensions.registerCoreModule("inputsGE")

  extensions.load("electricsGE")
  --extensions.registerCoreModule("electricsGE")

  extensions.load("positionGE")
  --extensions.registerCoreModule("positionGE")

  extensions.load("powertrainGE")
  --extensions.registerCoreModule("powertrainGE")

  extensions.load("nodesGE")
  --extensions.registerCoreModule("nodesGE")

  extensions.load("updatesGE")
  --extensions.registerCoreModule("updatesGE")

  extensions.load("CoreNetwork")
  --extensions.registerCoreModule("CoreNetwork")

  extensions.load("mpConfig")
  --extensions.registerCoreModule("mpConfig")

  extensions.load("GameNetwork")
  --extensions.registerCoreModule("GameNetwork")

end

M.onInit = onInit

print("Loader Loaded?!?!")
return M
