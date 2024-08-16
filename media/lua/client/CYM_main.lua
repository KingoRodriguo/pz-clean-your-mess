--- #region Requirements

require "Structure/extended_IsoBuilding"

--- #endregion

--- #region Global Variables

CYM =  CYM or {}

-- #endregion

--- #region Local Variables

CYM.data = {
    isRunning = false,
    isPaused = false,
    currentState = "idle",
    actionState = "idle",
    lastState = "idle",
    lastActionState = "idle",

    player = nil,
    playerQueue = {},
    playerEquippedWeight = 0,

    startTime = 0,
    endTime = 0,

    IsoBuilding = nil,
    extended_IsoBuilding = nil,
}

CYM.config = {
    heaviestItemFirst = true,
    exceedWeightLimit = false,

    storeInBestContainer = true,

    moveToItem = true,
    moveToContainer = true,

    SS_Active = false, -- Smarter Storage
    MC_Active = false, -- Manage Containers 
}

CYM.State = {
    idle = "idle",
    running = "running",
    paused = "paused",
    stopped = "stopped",
    notRunning = "notRunning",
    skip = "skip",
    error = "error",
    ending = "ending",

    cleaning = "cleaning",
    storing = "storing",
}

CYM.ActionState = {
    skip = "skip",
    perform = "perform",
}

--- #endregion

--- #region Global Functions
    
-- Update the cleaner
function CYM_UpdateCleaner()
    if not CYM.data.isRunning then return end
    if not CYM.data.player then return end
    if not CYM.data.playerQueue then return end

    -- Check if the player is moving or cancel the action
    if CYM.data.player:pressedMovement(false) or CYM.data.player:pressedCancelAction() then
        CYM:stop()
        return
    end

    -- Check if player TimedActionQueue is empty and player is not doing an action
    if #CYM.data.playerQueue.queue == 0 and #CYM.data.playerQueue.isPlayerDoingAction(CYM.data.player) then
        local nextAction = CYM:getNextAction()

        if CYM.data.currentActionState == CYM.ActionState.skip then
            CYM.data.currentActionState = CYM.ActionState.perform
            return
        elseif CYM.data.currentState == CYM.State.ending then CYM:stop() return -- Stop the cleaner
        elseif not nextAction then CYM:stop() return -- Action is not valid 
        else CYM.data.playerQueue.add(nextAction) end -- Add the next action to the queue
    end
end
--- #endregion

--- #region CYM functions

-- reset the CYM data
function CYM:reset()
    CYM.data.isRunning = false
    CYM.data.isPaused = false
    CYM.data.currentState = CYM.State.notRunning
    CYM.data.lastState = CYM.State.notRunning

    CYM.data.player = nil
    CYM.data.playerQueue = {}

    CYM.data.startTime = 0
    CYM.data.endTime = 0

    CYM.actionQueue = {}
end

-- Start the cleanning process
function CYM:start(start_square)

    if CYM.data.isRunning then return end -- Cleaner is already running
    if not start_square then return end -- No start square
    if not start_square:getRoom() then return end -- Cant clean outside

    -- reset the CYM data
    CYM:reset()

    CYM.data.IsoBuilding = start_square:getRoom():getBuilding()
    CYM.data.extended_IsoBuilding = Extended_IsoBuilding:new(CYM.data.IsoBuilding)

    if not CYM.data.extended_IsoBuilding then return end

    -- set CYM starting value
    CYM.data.isRunning = true
    CYM.data.isPaused = false
    CYM.data.currentState = CYM.State.running
    CYM.data.player = getPlayer()
    CYM.data.playerQueue = ISTimedActionQueue.getTimedActionQueue(CYM.data.player)

    print("CYM started")
end

-- Stop the cleanning process
function CYM:stop()
    if not CYM.data.isRunning then return end -- Cleaner is not running

    -- reset the CYM data
    CYM:reset()

    print("CYM stopped")
end

-- get the next action for the player
function CYM:getNextAction()
    CYM.data.lastState = CYM.data.currentState
    local nextAction = nil
    local nextState = CYM.data.currentState
    local nextActionState = CYM.data.currentActionState

    if CYM.data.currentState == CYM.State.cleaning then
        
        local buildingItems = CYM.data.extended_IsoBuilding:getItems()
        
        if #buildingItems == 0 then -- no items to clean
            if CYM.data.player:getInventory():getCapacityWeight() > CYM.data.playerEquippedWeight then -- inventory contain item to store
                nextState = CYM.State.storing
            else -- inventory dont contain item to store
                nextState = CYM.State.ending
            end
        else -- items to clean
            -- get all items in the building

            if not CYM.config.exceedWeightLimit then
                -- remove items that can't fit in the inventory
            end

            if CYM.config.heaviestItemFirst then
                -- sort items by weight
            else
                -- sort items by distance
            end

            -- select first item

            if CYM.config.moveToItem then
                -- move to the item
            end

            -- take the item
            -- repeat
        end
        
    elseif CYM.data.currentState == CYM.State.storing then

        -- if player inventory contain only equipped switch to cleaning

        -- get all items in the inventory

        if CYM.config.heaviestItemFirst then
            -- sort items by weight
        end

        -- select first item

        if CYM.config.storeInBestContainer then
            -- get the best container to store the item
        else
            -- get the closest container to store the item
        end

        if CYM.config.moveToContainer then
            -- move to the container
        end

        -- store the item
        -- repeat
    end

    CYM.data.currentState = nextState
    CYM.data.currentActionState = nextActionState
    return nextAction
end

--- #endregion