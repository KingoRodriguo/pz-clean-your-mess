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

--- #region Local Functions

local function getDistance(x1, y1, z1, x2, y2, z2)
    z1 = z1 * 100 -- ensure that different floors are not considered as close
    z2 = z2 * 100
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2)
end

local function getEquippedWeight(player)
    local inventory = player:getInventory()
    local items = table.convertToTable(inventory:getItems())
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
    local result = false
    if container:getCapacityWeight() + item:getActualWeight() < container:getMaxWeight() then result = true end
    return result
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

--- #region Global Functions
    
-- Update the cleaner
function CYM_UpdateCleaner()
    if not CYM.data.isRunning then return end
    if not CYM.data.player then return end
    if not CYM.data.playerQueue then return end

    -- Check if the player is moving or cancel the action
    if CYM.data.player:pressedMovement(false) or CYM.data.player:pressedCancelAction() then
        print("CYM: Player is moving or cancel the action")
        CYM:stop()
        return
    end

    -- Check if player TimedActionQueue is empty and player is not doing an action
    if #CYM.data.playerQueue.queue == 0 and not CYM.data.playerQueue.isPlayerDoingAction(CYM.data.player) then
        local nextAction = CYM:getNextAction()

        if CYM.data.currentActionState == CYM.ActionState.skip then
            CYM.data.currentActionState = CYM.ActionState.perform
            return
        elseif CYM.data.currentState == CYM.State.ending then CYM:stop() return -- Stop the cleaner
        elseif not nextAction then return -- Action is not valid 
        else CYM.data.playerQueue.add(nextAction) end -- Add the next action to the queue
    end
end

function CYM_createContextOption(player, context, worldObjects, test)
    local object = worldObjects[1]
    local x,y,z = object:getX(), object:getY(), object:getZ()
    local square = getCell():getGridSquare(x, y, z)
    if square:getRoom() == nil then return end
    local _mainMenu = context:addOption("Clean the mess", worldObjects, function() 
        CYM:start(square)
    end)
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
    CYM.data.currentState = CYM.State.cleaning
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
        print("CYM: Cleaning")
        local buildingItems = CYM.data.extended_IsoBuilding:getItems()
        
        if #buildingItems == 0 then -- no items to clean
            print("CYM: No items to clean")
            if CYM.data.player:getInventory():getCapacityWeight() > getEquippedWeight(CYM.data.player) then -- inventory contain item to store
                CYM.data.currentState = CYM.State.storing
                print("CYM: Switch to storing")
                return
            else -- inventory dont contain item to store
                CYM.data.currentState = CYM.State.ending
                print("CYM: Switch to ending")
                return
            end
        else -- items to clean
            print("CYM: Items to clean")
            -- get all items in the building
            local itemsSquares = CYM.data.extended_IsoBuilding:getSquaresWithItems()
            local sortedSquares = {}

            for i = 1, #itemsSquares do
                local square = itemsSquares[i]
                local items = square:getItems()
                local item = nil
                local distance = getDistance(CYM.data.player:getX(), CYM.data.player:getY(), CYM.data.player:getZ(), square.IsoGridSquare:getX(), square.IsoGridSquare:getY(), square.IsoGridSquare:getZ())
                for j = 1, #items do
                    item = items[j]
                    table.insert(sortedSquares, {extendedSquare = square, item = item, distance = distance})
                end
            end

            if not CYM.config.exceedWeightLimit then
                print("CYM: Exceed weight limit false")
                -- remove items that can't fit in the inventory
               for i = #sortedSquares, 1 ,-1 do
                    local square = sortedSquares[i]
                    local invCapacity = CYM.data.player:getInventory():getCapacityWeight()
                    if not invCapacity then print("invCapacity is nil") end
                    local invMaxWeight = CYM.data.player:getInventory():getMaxWeight()
                    if not invMaxWeight then print("invMaxWeight is nil") end
                    local itemWeight = square.item:getItem():getActualWeight()
                    if not itemWeight then print("itemWeight is nil") end

                    if invCapacity + itemWeight > invMaxWeight then
                        table.remove(sortedSquares, i)
                    end
               end
            end

            if #sortedSquares == 0 then -- no room in inventory
                print("CYM: No more room in inventory")
                CYM.data.currentState = CYM.State.storing
                print("CYM: Switch to storing")
                return
            end

            if CYM.config.heaviestItemFirst then
                print("CYM: Heaviest item first")
                sortedSquares = table.sort(sortedSquares, function(a, b) return a.item:getItem():getActualWeight() > b.item:getItem():getActualWeight() end)
            else
                print("CYM: Closest item first")
                sortedSquares = table.sort(sortedSquares, function(a, b) return a.distance < b.distance end)
            end

            local currentItemSelection = sortedSquares[1]
            local playerSquare = CYM.data.player:getCurrentSquare()
            local moveSquare = currentItemSelection.extendedSquare.IsoGridSquare
            local adjacentSquare = AdjacentFreeTileFinder.Find(moveSquare, CYM.data.player)

            -- if player square is different from currentItemSelection.extendedSquare.IsoGridSquare
            local isPlayerOnItem = (playerSquare == moveSquare) or (playerSquare == adjacentSquare)
            if not isPlayerOnItem and CYM.config.moveToItem then
                print("CYM: Move to item")
                -- move to currentItemSelection.extendedSquare.IsoGridSquare or the closest valid square
                if not moveSquare:isSolidTrans() then
                    print("CYM: Move to closest valid square")
                    moveSquare = adjacentSquare
                end
                nextAction = ISWalkToTimedAction:new(CYM.data.player, moveSquare)
                return nextAction
            else
                print("CYM: Player is on item")
            end

            -- take currentItemSelection.item
            print("CYM: Grab item")
            local time = ISWorldObjectContextMenu.grabItemTime(CYM.data.player, currentItemSelection.item)
            nextAction = ISGrabItemAction:new(CYM.data.player, currentItemSelection.item, time)
            return nextAction
        end
        
    elseif CYM.data.currentState == CYM.State.storing then

        -- if player inventory contain only equipped switch to cleaning
        if CYM.data.player:getInventory():getCapacityWeight() == getEquippedWeight(CYM.data.player) then
            print("CYM: player inventory contain only equipped items")
            print("CYM: Switch to cleaning")
            CYM.data.currentState = CYM.State.cleaning
            CYM.ActionState = CYM.ActionState.skip
            return
        end

        -- get all items in the inventory
        local inventoryItems = table.convertToTable(CYM.data.player:getInventory():getItems())
        local sortedItems = {}

        -- remove equipped items or key ring
        for i = 1, #inventoryItems do
            local item = inventoryItems[i]
            if not item:isEquipped() and not instanceof(item, "KeyRing") then
                table.insert(sortedItems, item)
            end
        end
        
        if #sortedItems == 0 then -- no items to store
            print("CYM: No items to store")
            print("CYM: Switch to cleaning")
            CYM.data.currentState = CYM.State.cleaning
            return
        end

        if CYM.config.heaviestItemFirst then
            print("CYM: Heaviest item first")
            sortedItems = table.sort(sortedItems, function(a, b) return a:getActualWeight() > b:getActualWeight() end)
        end

        local currentItemSelection = sortedItems[1]
        local containerData = nil

        if CYM.config.storeInBestContainer then
            print("Best container")
            containerData = getBestContainer(currentItemSelection)
        else
            print("Closest container")
            containerData = getClosestContainer(currentItemSelection)
        end

        if not containerData then -- no container to store the item
            print("CYM: No container to store the item")
            print("CYM: Switch to ending")
            CYM.data.currentState = CYM.State.ending
            return
        end
        local playerSquare = CYM.data.player:getCurrentSquare()
        local containerSquare = containerData.square.IsoGridSquare
        local adjacentSquare = AdjacentFreeTileFinder.Find(containerSquare, CYM.data.player)

        local isPlayerOnContainer = (playerSquare == containerSquare) or (playerSquare == adjacentSquare)

        -- if player square is different from containerSquare
        if not isPlayerOnContainer and CYM.config.moveToContainer then
            print("CYM: Move to container")
            -- move to containerSquare or the closest valid square
            local moveSquare = containerSquare
            if not moveSquare:isSolidTrans() then
                moveSquare = adjacentSquare
            end
            nextAction = ISWalkToTimedAction:new(CYM.data.player, moveSquare)
            return nextAction
        else
            print("CYM: Player is on container")
        end

        if not isValidContainer(containerData.container, currentItemSelection) then
            print("CYM: Container is full")
            print("CYM: Switch to ending")
            CYM.data.currentState = CYM.State.ending
            return
        end

        -- store the item
        print("CYM: Store item")
        nextAction = ISInventoryTransferAction:new(CYM.data.player, currentItemSelection, currentItemSelection:getContainer(), containerData.container)
        return nextAction
    end
end

--- #endregion