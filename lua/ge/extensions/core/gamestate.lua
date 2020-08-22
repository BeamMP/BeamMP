local M = {}
local logTag = "gamestate"

M.state = {}

local loadingActive = false
local waitingForUIToBeInitialised = false
local waitingForUIChangeToLoading = false
local UIInitialised = false
-- GameState = GAME (not UI)
-- This is meant to store if we are in freeroam or campaign etc
-- This is espacially helpfull if the campaign contains something similar to a freeroam part
-- this also will hold specific game relevant ui configurations, like applayout and menu items, those can be emited and will then be filled by defaults

local function sendGameState()
  extensions.hook('onGameStateUpdate', M.state)
  guihooks.trigger('GameStateUpdate', M.state)
end

-- if only one should be updated omit the other parameters or set to nil
local function setGameState(state, appLayout, menuItems, options)
  M.state = {
    state = state or M.state.state,
    appLayout = appLayout or M.state.appLayout,
    menuItems = menuItems or M.state.menuItems,
    options = options or M.state.options
  }
  sendGameState()
end

-- called when going back to main menu
local function resetGameState()
  M.state = {}
end

-- UI state === to main menu or not to main menu
-- This is a state for the ui, so it knows if it should show the main menu or the side menu
-- important: this is not meant to change the router state, but only a variable change.
local function sendShowMainMenu ()
  -- TODO: check if getter setter is needed or if this is enough and always correct -yh
  local mainMenu = getMissionFilename() == ''
  log('D', logTag, 'show main menu (' .. tostring(mainMenu) .. ')')
  guihooks.trigger('ShowEntertainingBackground', mainMenu)

  return mainMenu
end

-- loading screen
-- the problem until now, was that lua could not distinguish between level unloads and level switches
-- since we do not want to exit the loading screen when currently switching and unloading stage is finished this was a problem
-- solution: we just wait until the last module finished requiring the loading screen and then and only then exit the loading screen
local loadingScreenRequests = {}
local listeners = {}

local function tellListeners ()
  for k,v in ipairs(listeners) do
    v()
    listeners[k] = nop
  end
end

local function containsOnly (arr, val)
  for _, l in pairs(arr) do
    if l ~= val then
      return false
    end
  end
  return true
end

local function loading ()
  return not (containsOnly(loadingScreenRequests, false) or tableIsEmpty(loadingScreenRequests))
end

local function getLoadingStatus(tagName)
  return loadingScreenRequests[tagName]
end

local function showLoadingScreen (tagName, func)
  if tagName == nil then return end

  local first = containsOnly(loadingScreenRequests, false)
  log('D', logTag, 'loading screen request from: ' .. tagName .. '; value before was: ' .. tostring(loadingScreenRequests[tagName]))
  if loadingScreenRequests[tagName] then log('D', logTag, 'trying to enter state we are already in: ' .. tostring(tagName)) end
  loadingScreenRequests[tagName] = true
  func = func or nop

  if first and not loadingActive then
    log('D', logTag, 'sending show loading screen')
    guihooks.trigger('ChangeState', 'loading')
    waitingForUIChangeToLoading = true
  end

  if loadingActive then
    log('D', logTag, 'exec fun direct')
    func()
  else
    table.insert(listeners, func)
    log('D', logTag, 'ui initialised (' .. tostring(UIInitialised) .. ')')
    log('D', logTag, 'waiting for ui (' .. tostring(waitingForUIToBeInitialised) .. ')')
    if not UIInitialised then
      waitingForUIToBeInitialised = true
    end
  end
end

local function exitLoadingScreen (tagName)
  if tagName == nil then return end

  log('D', logTag, 'exiting : ' .. tagName)
  if not loadingScreenRequests[tagName] then log('W', logTag, 'trying to exit state we haven\'t been in before -please check your code') end
  loadingScreenRequests[tagName] = false

  if containsOnly(loadingScreenRequests, false) then
    if sendShowMainMenu() then
      guihooks.trigger('ChangeState', 'menu.mainmenu')
      log('D', logTag, 'change state to menu.mainmenu')
      -- this is the only case we aren't in a gamestate everything else should be
      resetGameState()
    else
      log('D', logTag, 'exiting loading screen to menu')
      guihooks.trigger('ChangeState', 'menu', {'loading', 'menu.mainmenu'})
    end

    listeners = {}
    loadingActive = false
  end
end

local function loadingScreenActive ()
  log('D', logTag, 'ui told us loading screen is now loaded')
  loadingActive = true
  tellListeners()
end

local function onDeserialized(data)
end

local function uiReady ()
  log('D', logTag, 'ui finished loading')
  UIInitialised = true;

  if waitingForUIToBeInitialised then
    log('D', logTag, 'wait for ui is over')
    guihooks.trigger('ChangeState', 'loading')
  end
end

-- in case lua is re-loaded but the ui is not
-- this is called directly, TODO: think about making it a proper hook and not just having it look like one
local function onExtensionLoaded ()
  -- it is important this does happen direclty, so potential others don't get confused
  guihooks.trigger('requestUIInitialised')
  log('D', logTag, 'see if ui is loaded')
end

-- this code is added to solve an issue when loading screen dont load for some reason
-- kick listeners after 1 sec of waiting
local waitingForChangeUI = 0
local function onUpdate(dtReal, dtSim, dtRaw)
  if #listeners == 0 or waitingForUIChangeToLoading then
    waitingForChangeUI = 0
    return
  end

  waitingForChangeUI = waitingForChangeUI + math.min(dtReal, 1 / 30)
  if(waitingForChangeUI > 1) then
    waitingForChangeUI = 0
    log('D', logTag, 'Forcing continue without loading screen')
    loadingScreenActive()
  end
end
-- -------------------------------------------------

-- interface
M.onDeserialized = onDeserialized

M.requestGameState = sendGameState
M.setGameState = setGameState

M.requestMainMenuState = sendShowMainMenu

M.requestEnterLoadingScreen = showLoadingScreen
M.requestExitLoadingScreen = exitLoadingScreen
M.loading = loading -- do not use this inside the loading process, unless you know what you are doing
M.getLoadingStatus = getLoadingStatus -- use this instead

M.loadingScreenActive = loadingScreenActive

M.onUIInitialised = uiReady
M.onUpdate = onUpdate
M.onExtensionLoaded = onExtensionLoaded

return M