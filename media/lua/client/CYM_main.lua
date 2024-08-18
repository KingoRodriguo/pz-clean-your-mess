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

    stateCache = {},
    nextItemData = nil,
    nextContainerData = nil,

    player = nil,
    playerQueue = {},

    startTime = 0,
    endTime = 0,

    IsoBuilding = nil,
    extended_IsoBuilding = nil,

    skipCount = 0,
    maxSkipCount = 5,
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

    cleaningItem = "cleaningItem", -- start cleaning state
    searchItem = "searchItem",   -- search for the next item to clean
    moveToItem = "moveToItem",  -- move to the next item to clean
    pickItem = "pickItem",   -- pick the next item to clean

    storingItem = "storingItem", -- start storing state
    searchContainer = "searchContainer", -- search for the next container to store
    moveToContainer = "moveToContainer", -- move to the next container to store
    storeItem = "storeItem", -- store the next item to the container
}

CYM.ActionState = {
    perform = "perform",
    skip = "skip",
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
            weight = weight + item:getEquippedWeight()
        end
    end
    return weight
end

local function isValidContainer(container, item)
    local result = false
    if container:getCapacityWeight() + item:getActualWeight() < container:getMaxWeight() then result = true end
    --print("Container: " .. container:getType() .. " is valid: " .. tostring(result))
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
        if choosenContainer then print("CYM: Manage Containers best container found") end
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
        if choosenContainer then print("CYM: Smarter Storage best container found") end
    end
    if not choosenContainer then -- regular closest container
        -- get the closest valid container from the player
        choosenContainer = getClosestContainer(item)
        if choosenContainer then print("CYM: Closest container found") end
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
        print("CYM: ---------------------------------------\n")
        print("CYM: Current skip count: " .. CYM.data.skipCount)
        local nextAction = CYM:getNextAction()

        if CYM.data.currentState == CYM.State.ending then CYM:stop() return -- Stop the cleaner
        elseif not nextAction then 
            if CYM.data.skipCount >= CYM.data.maxSkipCount then 
                print("CYM: Skip count reached the limit, stop the cleaner")
                CYM:stop() 
                return 
            end
            print("CYM: Next action is null, skip the action")
            CYM.data.skipCount = CYM.data.skipCount + 1
            return -- Action is not valid 
        else CYM.data.playerQueue.add(nextAction) end -- Add the next action to the queue
        CYM.data.skipCount = 0
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
    CYM.data.currentState = CYM.State.idle
    CYM.data.actionState = CYM.ActionState.perform
    CYM.data.stateCache = {}
    CYM.data.nextItemData = nil
    CYM.data.nextContainerData = nil
    CYM.data.player = nil
    CYM.data.playerQueue = {}
    CYM.data.startTime = 0
    CYM.data.endTime = 0
    CYM.data.IsoBuilding = nil
    CYM.data.extended_IsoBuilding = nil
    CYM.data.skipCount = 0
    CYM.data.maxSkipCount = 5
    CYM.data.SS_Active = false
    CYM.data.MC_Active = false
    print("CYM: Reset")
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
    CYM.data.currentState = CYM.State.cleaningItem
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
    local nextState = nil
    local nextActionState = CYM.data.currentActionState

    -- check which state the cleaner is in
    if CYM.data.currentState then 
        print("CYM: current state: " .. CYM.data.currentState)
        if CYM.data.currentState == CYM.State.cleaningItem then
            print("CYM: Cleaning Item")
            nextState = CYM.State.searchItem
        elseif CYM.data.currentState == CYM.State.searchItem then -- search for the next item to clean
            -- initialize the stateCache after cleaningItem state
            print("CYM: Setting stateCache")

            local itemsData = {}
            local extendedSquares = CYM.data.extended_IsoBuilding:getSquares()

            print("CYM: extendedSquares count: " .. #extendedSquares)
            for i = 1, #extendedSquares do -- generate itemsData
                if extendedSquares[i]:haveItems() then -- check if the square have inventoryWorldItems
                    local wItems = extendedSquares[i]:getItems() -- get inventoryWorldItems in the square
                    for j = 1, #wItems do
                        table.insert(itemsData, {
                            wItem = wItems[j], -- inventoryWorldItem found
                            extendedSquare = extendedSquares[i], -- extended square of the wItem
                            distance = getDistance(
                                CYM.data.player:getX(), CYM.data.player:getY(), CYM.data.player:getZ(),
                                extendedSquares[i].IsoGridSquare:getX(), extendedSquares[i].IsoGridSquare:getY(), extendedSquares[i].IsoGridSquare:getZ())
                            })  -- distance from the player to the wItem
                    end
                end
            end
            print("CYM: itemsData generated")
            print("CYM: itemsData count: " .. #itemsData)
            CYM.data.stateCache = itemsData

            if CYM.data.stateCache and #CYM.data.stateCache > 0 then -- check if stateCache
                print("CYM: found stateCache, beggin searchItem")
                if CYM.config.heaviestItemFirst then -- sort the itemsData by weight (heaviest first)
                    CYM.data.stateCache = table.sort(
                        CYM.data.stateCache,
                        function(a, b) return a.wItem:getItem():getActualWeight() > b.wItem:getItem():getActualWeight() end
                    )
                else -- sort the itemsData by distance (closest first)
                    CYM.data.stateCache.itemsData = table.sort(
                        CYM.data.stateCache.itemsData,
                        function(a, b) return a.distance < b.distance end
                    )
                end

                local itemData = nil
                -- choose the itemData
                if CYM.config.exceedWeightLimit then -- get the first ItemData
                    itemData = CYM.data.stateCache.itemsData[1]
                else -- get the first ItemData that does not exceed the player weight limit
                    for i = 1, #CYM.data.stateCache do
                        local iData = CYM.data.stateCache[i]
                        if CYM.data.player:getInventory():getCapacityWeight() + iData.wItem:getItem():getActualWeight() <= CYM.data.player:getMaxWeight() then
                            itemData = iData
                            break
                        end
                    end
                end

                if itemData then
                    print("CYM: found itemData that fit in player inventory")
                    print("CYM: itemData weight: " .. itemData.wItem:getItem():getActualWeight())
                    print("CYM: player weight: " .. CYM.data.player:getInventory():getCapacityWeight())
                    print("CYM: player max weight: " .. CYM.data.player:getMaxWeight())

                    CYM.data.nextItemData = itemData
                    local itemSquare = nil
                    if itemData.extendedSquare and itemData.extendedSquare.IsoGridSquare then
                        itemSquare = itemData.extendedSquare.IsoGridSquare
                    else
                        print("CYM: Warning, itemSquare is null, wont be able to move to the item")
                    end
                    if CYM.config.moveToItem and itemSquare then
                        print("CYM: moveToItem is enabled, beggin moveToItem")
                        nextState = CYM.State.moveToItem
                    else
                        print("CYM: moveToItem is disabled, skip to pickItem")
                        nextState = CYM.State.pickItem
                    end
                else
                    print("CYM: not itemData found")
                    print("CYM: try storingItem")
                    nextState = CYM.State.storingItem
                end
            elseif not CYM.data.stateCache then -- no stateCache
                print("CYM: no stateCache found")
                nextState = CYM.State.ending
            elseif #CYM.data.stateCache == 0 then -- stateCache is empty
                print("CYM: stateCache is empty")
                -- if player inv weight > player equiped weight, store the items
                local inventoryCapacityWeight = CYM.data.player:getInventory():getCapacityWeight()
                local equippedWeight = getEquippedWeight(CYM.data.player)
                print("CYM: inventoryCapacityWeight: " .. inventoryCapacityWeight)
                print("CYM: equippedWeight: " .. equippedWeight)
                if CYM.data.player:getInventory():getCapacityWeight() > getEquippedWeight(CYM.data.player) then
                    print("CYM: try storingItem")
                    nextState = CYM.State.storingItem
                else
                    print("CYM: no more items to clean")
                    nextState = CYM.State.ending
                end
            end
        elseif CYM.data.currentState == CYM.State.moveToItem then -- move to the item
            print("CYM: begin moveToItem")
            local itemData = CYM.data.nextItemData
            if not itemData then
                print("CYM: itemData is null")
                nextState = CYM.State.ending
            else
                local itemSquare = itemData.extendedSquare.IsoGridSquare
                if itemSquare then
                    if not itemSquare:isSolidTrans() then
                        print("CYM: itemSquare is not accessible, findind closest accessible square")
                        itemSquare = AdjacentFreeTileFinder.Find(itemSquare, CYM.data.player)
                    end
                    --check if player is already in the itemSquare
                    if itemSquare == CYM.data.player:getCurrentSquare() then
                        print("CYM: player is already in the itemSquare")
                        print("CYM: move to pickItem")
                        CYM.data.nextItemData = itemData
                        nextState = CYM.State.pickItem
                    else
                        print("CYM: move to itemSquare")
                        nextAction = ISWalkToTimedAction:new(CYM.data.player, itemSquare)
                        nextState = CYM.State.pickItem
                    end
                else -- no itemSquare, abort
                    print("CYM: itemSquare is null")
                    nextState = CYM.State.ending
                end
            end
        elseif CYM.data.currentState == CYM.State.pickItem then -- pick item on the floor
            print("CYM: begin pickItem")
            local itemData = CYM.data.nextItemData
            if not itemData then
                print("CYM: itemData is null")
                nextState = CYM.State.ending
            else
                local item = itemData.wItem
                if item then
                    print("CYM: pick the item")
                    local time = ISWorldObjectContextMenu.grabItemTime(CYM.data.player, item)
                    nextAction = ISGrabItemAction:new(CYM.data.player, item, time)
                    nextState = CYM.State.cleaningItem
                else
                    print("CYM: item is null")
                    nextState = CYM.State.ending
                end
            end
        elseif CYM.data.currentState == CYM.State.storingItem then -- start storing state
            print("CYM: Storing Item")

            --check if player is carrying items except equipped items or keyring
            local inventory = CYM.data.player:getInventory()
            local items = table.convertToTable(inventory:getItems())
            local itemsToStore = {}
            for i = 1, #items do -- get items to store
                local item = items[i]
                if not item:isEquipped() and not instanceof(item, "KeyRing") then
                    table.insert(itemsToStore, item)
                end
            end
            if itemsToStore and #itemsToStore > 0 then -- check if there is item to store
                print("CYM: Items to store found")
                print("CYM: itemsToStore count: " .. #itemsToStore)
                CYM.data.stateCache = itemsToStore
                nextState = CYM.State.searchContainer
            else
                print("CYM: No items to store")
                if CYM.data.lastState == CYM.State.searchItem then
                    nextState = CYM.State.ending
                else
                    nextState = CYM.State.cleaningItem
                end
            end
        elseif CYM.data.currentState == CYM.State.searchContainer then
            print("CYM: Search Container")
            local itemsToStore = CYM.data.stateCache
            local itemsData = {}
            if itemsToStore and #itemsToStore > 0 then
                print("CYM: Items to store found")
                -- initialize itemsData
                for i = 1, #itemsToStore do
                    local item = itemsToStore[i]
                    local containerData = nil
                    if CYM.config.storeInBestContainer then
                        print("CYM: search for best container")
                        containerData = getBestContainer(item)
                    else
                        print("CYM: search for closest container")
                        containerData = getClosestContainer(item)
                    end
                    if containerData then
                        table.insert(itemsData, {
                            item = item,
                            containerData = containerData,
                            distance = containerData.distance
                        })
                    end
                end

                if #itemsData > 0 then
                    print("CYM: itemsData found")
                    if CYM.config.heaviestItemFirst then -- sort the itemsData by weight (heaviest first)
                        itemsData = table.sort(
                            itemsData,
                            function(a, b) return a.item:getActualWeight() > b.item:getActualWeight() end
                        )
                    else -- sort the itemsData by distance (closest first)
                        itemsData = table.sort(
                            itemsData,
                            function(a, b) return a.distance < b.distance end
                        )
                    end

                    CYM.data.stateCache = {}
                    table.merge(CYM.data.stateCache, itemsData)

                    local bestContainerData = CYM.data.stateCache[1]
                    print("CYM: bestContainerData found")
                    print("CYM: bestContainerData distance: " .. bestContainerData.distance)
                    print("CYM: bestContainerData container: " .. bestContainerData.containerData.container:getType())
                    print("CYM: bestContainerData Square: " .. tostring(bestContainerData.containerData.square.IsoGridSquare))
                    print("CYM: bestContainerData container weight: " .. bestContainerData.containerData.container:getCapacityWeight())
                    print("CYM: bestContainerData container max weight: " .. bestContainerData.containerData.container:getMaxWeight())
                    print("CYM: bestContainerData item: " .. bestContainerData.item:getType())
                    print("CYM: item weight: " .. bestContainerData.item:getActualWeight())

                    if CYM.config.moveToContainer then
                        print("CYM: moveToContainer is enabled, beggin moveToContainer")
                        nextState = CYM.State.moveToContainer
                    else
                        print("CYM: moveToContainer is disabled, skip to storeItem")
                        nextState = CYM.State.storeItem
                    end
                else
                    print("CYM: no itemsData found")
                    nextState = CYM.State.cleaningItem
                end

            else
                print("CYM: No items to store")
                nextState = CYM.State.cleaningItem
            end
        elseif CYM.data.currentState == CYM.State.moveToContainer then
            local itemData = CYM.data.stateCache[1]
            if not itemData then
                print("CYM: itemData is null")
                nextState = CYM.State.cleaningItem
            else
                local containerData = itemData.containerData
                if containerData then
                    local containerSquare = containerData.square.IsoGridSquare
                    local adjacentSquare = AdjacentFreeTileFinder.Find(containerSquare, CYM.data.player)
                    if containerSquare then
                        if not containerSquare:isFree(false) then
                            print("CYM: containerSquare is not accessible, findind closest accessible square")
                            if adjacentSquare then
                                containerSquare = adjacentSquare
                            else
                                print("CYM: no accessible square found")
                                CYM.data.currentState = CYM.State.ending
                                return
                            end
                        end
                        --check if player is already in the containerSquare
                        if containerSquare == CYM.data.player:getCurrentSquare() then
                            print("CYM: player is already in the containerSquare")
                            print("CYM: move to storeItem")
                            CYM.data.nextContainerData = containerData
                            nextState = CYM.State.storeItem
                        else
                            print("CYM: move to containerSquare")
                            nextAction = ISWalkToTimedAction:new(CYM.data.player, containerSquare)
                            nextState = CYM.State.moveToContainer
                        end
                    else -- no containerSquare, abort
                        print("CYM: containerSquare is null")
                        nextState = CYM.State.storeItem
                    end
                else
                    print("CYM: containerData is null")
                    nextState = CYM.State.cleaningItem
                end
            end
        elseif CYM.data.currentState == CYM.State.storeItem then
            local itemData = CYM.data.stateCache[1]
            local containerData = itemData.containerData
            if not containerData then
                print("CYM: containerData is null")
                nextState = CYM.State.cleaningItem
            else
                local item = itemData.item
                local container = containerData.container
                if item and container then
                    print("CYM: store the item")
                    nextAction = ISInventoryTransferAction:new(CYM.data.player, item, item:getContainer(), container)
                    nextState = CYM.State.storingItem
                else
                    print("CYM: item or container is null")
                    nextState = CYM.State.cleaningItem
                end
            end
        else
            print("CYM: State Machine state is not valid")
            CYM.data.currentState = CYM.State.ending
            return
        end

    else
        print("CYM: State Machine state is null")
        CYM.data.currentState = CYM.State.ending
        return
    end

    CYM.data.currentState = nextState
    if not nextAction then CYM.data.currentActionState = CYM.ActionState.skip end
    return nextAction
end

--- #endregion