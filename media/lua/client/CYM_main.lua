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

    startTime = 0,
    endTime = 0,

    IsoBuilding = nil,
    extended_IsoBuilding = nil,
}

CYM.config = {
    heaviestItemFirst = true,
    currentFloorFirst = true,
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

--- #region Local Functions

local function getDistance(x1, y1, z1, x2, y2, z2)
    z1 = z1 * 100 -- ensure that different floors are not considered as close
    z2 = z2 * 100
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

local function getEquippedWeight(player)
    local inventory = player:getInventory()
    local items = inventory:getItems()
    local weight = 0

    for i = 1, #items do
        local item = items[i]
        if item:isEquipped() then
            weight = weight + item:getActualWeight()
        end
    end
    return weight
end

local function isValidContainer(container, item)
    if container:getCapacityWeight() + item:getActualWeight() > container:getMaxWeight() then return false else return true end
end

local function getClosestContainer(item)
    local containerSquares = CYM.data.extended_IsoBuilding:getContainerSquares()
    local validContainerSquares = {}
    
    for i = 1, #containerSquares do -- get valid container squares
        local square = containerSquares[i]
        local squareContainers = square:getContainers()
        for j = 1, #squareContainers do
            if isValidContainer(squareContainers[j], item) then
                table.insert(validContainerSquares, {
                    square = square, 
                    container = squareContainers[j], 
                    distance = getDistance(CYM.data.player:getX(), CYM.data.player:getY(), CYM.data.player:getZ(), 
                        square.IsoGridSquare:getX(), square.IsoGridSquare:getY(), square.IsoGridSquare:getZ())
                })
            end
        end
    end

    -- get the closest valid container from the player
    validContainerSquares = table.sort(validContainerSquares, function(a, b) return a.distance < b.distance end)

    return validContainerSquares[1] or nil
end

local function getBestContainer(item)
    local containerSquares = CYM.data.extended_IsoBuilding:getContainerSquares()
    local validContainerSquares = {}
    local choosenContainer = nil

    for i = 1, #containerSquares do -- get valid container squares
        local square = containerSquares[i]
        local squareContainers = square:getContainers()
        for j = 1, #squareContainers do
            if isValidContainer(squareContainers[j], item) then
                table.insert(validContainerSquares, {
                    square = square, 
                    container = squareContainers[j], 
                    distance = getDistance(CYM.data.player:getX(), CYM.data.player:getY(), CYM.data.player:getZ(), 
                        square.IsoGridSquare:getX(), square.IsoGridSquare:getY(), square.IsoGridSquare:getZ())
                })
            end
        end
    end
 
    if CYM.data.MC_Active then -- Manage Containers compatibility
        -- get the closest valid container from Manage Containers
    end
    if not choosenContainer and CYM.data.SS_Active then -- Smarter Storage compatibility
        local SS_Squares = {}
        -- get the closest valid container from Smarter Storage
        for i = 1 , #validContainerSquares do
            local containerData = validContainerSquares[i]
            local container = containerData.container
            local container_ModData = container:getParent():getModData() or nil
            local SS_Name = container_ModData.SmarterStorage_Name or nil
            local SS_Icon = container_ModData.SmarterStorage_Icon or nil

            if SS_Icon then 
                local itemIcon = InventoryItemFactory.CreateItem(SS_Icon)
                if itemIcon then
                    local containerCategory = itemIcon:getDisplayCategory()
                    if (containerCategory == item:getDisplayCategory()) or (SS_Name == item:getDisplayCategory()) then
                        table.insert(SS_Squares, containerData)
                    end
                end
            end
        end
        SS_Squares = table.sort(SS_Squares, function(a, b) return a.distance < b.distance end)
        choosenContainer = SS_Squares[1] or nil
    end
    if not choosenContainer then -- regular closest container
        -- get the closest valid container from the player
        choosenContainer = getClosestContainer(item)
    end
    return choosenContainer
end

--- #endregion Local functions

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

    CYM.data.SS_Active = CYM_Compat.SmarterStorage
    CYM.data.MC_Active = CYM_Compat.ManageContainers

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
            if CYM.data.player:getInventory():getCapacityWeight() > getEquippedWeight(CYM.data.player) then -- inventory contain item to store
                CYM.data.currentState = CYM.State.storing
            else -- inventory dont contain item to store
                CYM.data.currentState = CYM.State.ending
            end
        else -- items to clean
            -- get all items in the building
            local itemsSquares = CYM.data.extended_IsoBuilding:getSquaresWithItems()
            local sortedSquares = {}

            for i = 1, #itemsSquares do
                local square = itemsSquares[i]
                local item = square:getWorldObjects():get(0)
                local distance = getDistance(CYM.data.player:getX(), CYM.data.player:getY(), CYM.data.player:getZ(), square.IsoGridSquare:getX(), square.IsoGridSquare:getY(), square.IsoGridSquare:getZ())
                table.insert(sortedSquares, {extendedSquare = square, item = item, distance = distance})
            end

            if not CYM.config.exceedWeightLimit then
                -- remove items that can't fit in the inventory
               for i = #sortedSquares, 1 ,-1 do
                    local square = sortedSquares[i]
                    if CYM.data.player:getInventory():getCapacityWeight() < CYM.data.playerEquippedWeight + square.item:getWeight() then
                        table.remove(sortedSquares, i)
                    end
               end
            end

            if CYM.config.heaviestItemFirst then
                sortedSquares = table.sort(sortedSquares, function(a, b) return a.item:getWeight() > b.item:getWeight() end)
            else
                sortedSquares = table.sort(sortedSquares, function(a, b) return a.distance < b.distance end)
            end

            local currentItemSelection = sortedSquares[1]

            local playerPosKey = CYM.data.player:getX() .. "," .. CYM.data.player:getY() .. "," .. CYM.data.player:getZ()
            local itemPosKey = currentItemSelection.extendedSquare.IsoGridSquare:getX() .. "," .. currentItemSelection.extendedSquare.IsoGridSquare:getY() .. "," .. currentItemSelection.extendedSquare.IsoGridSquare:getZ()

            -- if player square is different from currentItemSelection.extendedSquare.IsoGridSquare
            if playerPosKey ~= itemPosKey and CYM.config.moveToItem then
                -- move to currentItemSelection.extendedSquare.IsoGridSquare or the closest valid square
                local moveSquare = currentItemSelection.extendedSquare.IsoGridSquare
                if not moveSquare:isSolidTrans() then
                    moveSquare = AdjacentFreeTileFinder.Find(moveSquare, CYM.data.player)
                end
                nextAction = ISWalkToTimedAction:new(CYM.data.player, moveSquare)
                return nextAction
            end

            -- take currentItemSelection.item
            local time = ISWorldObjectContextMenu.grabItemTime(CYM.data.player, currentItemSelection.item)
            nextAction = ISGrabItemAction:new(CYM.data.player, currentItemSelection.item, time)
            return nextAction
        end
        
    elseif CYM.data.currentState == CYM.State.storing then

        -- if player inventory contain only equipped switch to cleaning
        if CYM.data.player:getInventory():getCapacityWeight() == getEquippedWeight(CYM.data.player) then
            CYM.data.currentState = CYM.State.cleaning
            CYM.ActionState = CYM.ActionState.skip
            return
        end

        -- get all items in the inventory
        local inventoryItems = CYM.data.player:getInventory():getItems()
        local sortedItems = {}

        -- remove equipped items or key ring
        for i = 1, #inventoryItems do
            local item = inventoryItems[i]
            if not item:isEquipped() and not instanceof(item, "KeyRing") then
                table.insert(sortedItems, item)
            end
        end        

        if CYM.config.heaviestItemFirst then
            sortedItems = table.sort(inventoryItems, function(a, b) return a:getActualWeigh() > b:getActualWeigh() end)
        end

        local currentItemSelection = sortedItems[1]
        local containerData = nil

        if CYM.config.storeInBestContainer then
            containerData = getBestContainer(currentItemSelection)
        else
            containerData = getClosestContainer(currentItemSelection)
        end

        if not containerData then -- no container to store the item
            CYM.data.currentState = CYM.State.ending
            return
        end
        local containerSquare = containerData.square

        local playerPosKey = CYM.data.player:getX() .. "," .. CYM.data.player:getY() .. "," .. CYM.data.player:getZ()
        local containerPosKey = containerSquare:getX() .. "," .. containerSquare:getY() .. "," .. containerSquare:getZ()

        -- if player square is different from containerSquare
        if playerPosKey ~= containerPosKey and CYM.config.moveToContainer then
            -- move to containerSquare or the closest valid square
            local moveSquare = containerSquare
            if not moveSquare:isSolidTrans() then
                moveSquare = AdjacentFreeTileFinder.Find(moveSquare, CYM.data.player)
            end
            nextAction = ISWalkToTimedAction:new(CYM.data.player, moveSquare)
            return nextAction
        end

        -- store the item
        nextAction = ISInventoryTransferAction:new(CYM.data.player, currentItemSelection, currentItemSelection:getContainer(), containerData.container)
        return nextAction
    end
end

--- #endregion