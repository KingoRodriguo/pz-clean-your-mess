testList = {}
cleanList = {}
containerCells = {}

local actionQueue = {}

local emptyQueueActive = false
local cleaning = false

local function getClosestContainer(player)
    local x, y, z = player:getX(), player:getY(), player:getZ()
    local playerSquare = getCell():getGridSquare(x, y, z)

    local closestContainerCell = nil
    local closestContainer = nil
    local closestDistance = 10000

    for _, cell in ipairs(containerCells) do
        local distance = 10000
        if cell.square then
            if cell.container then 
                if cell.container:getCapacityWeight() > cell.container:getMaxWeight()*0.8 then
                    print("Container is full")
                    distance = 10000
                else
                    distance = cell.square:DistTo(playerSquare) or distance
                end
            end
        end
        if distance < closestDistance then
            closestContainerCell = cell
            closestContainer = cell.container
            closestDistance = distance
        end
    end
    if closestDistance == 10000 then
        actionQueue = {}
        cleanList = {}
        highlightCells = {}
        getPlayer():Say("No container found with enought space")
        return nil, nil, nil
    end
    return closestContainerCell, closestContainer
end

local function getBestContainer(player, item)
    local itemCat = item:getCategory()

    local currentBestContainerCell = nil
    local currentBestContainer = nil
    local currentBestContainerValue = 0

    if not itemCat then return end

    for _, cell in ipairs(containerCells) do
        --print("Checking cell: " .. tostring(cell))
        cell:update()
        if cell.container then
            --print("Container found: " .. tostring(cell.container))
            for _, categorie in pairs(cell.containerCategories) do
                print("Container categorie name: " .. tostring(categorie))
                local result = false
                if categorie == itemCat then
                    result = true
                    if categorie > currentBestContainerValue then
                        currentBestContainerValue = categorie
                        currentBestContainer = cell.container
                        currentBestContainerCell = cell
                    end
                end
                print("Container categorie contain item categorie: " .. tostring(result))
            end
        else
            print("No container found")
        end
    end
    if not currentBestContainer then
        print("Closest container choosen")
        currentBestContainerCell, currentBestContainer = getClosestContainer(player)
    else
        print("Best container choosen")
    end
    return currentBestContainerCell, currentBestContainer
end

local function getPlayerSquare(player)
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    return getCell():getGridSquare(x, y, z)
end

local function MoveToLocation(player, toSquare, pos)
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    local adjacent = AdjacentFreeTileFinder.Find(toSquare, player)

    local playerSquare = getCell():getGridSquare(x, y, z)

    if playerSquare:isBlockedTo(adjacent) then
        --print("path blocked")
        return false
    end
    local action  = ISWalkToTimedAction:new(player, adjacent)
    
    -- Need to find a way to know if the path is valid

    if pos == nil then
        table.insert(actionQueue, action)
    else
        --is a integer
        if type(pos) == "number" then
            --print("MoveToLocation inserting at pos: " .. pos)
            table.insert(actionQueue, pos, action)
        end
    end
    --print("Moving to: " .. tostring(toSquare))
    return true
end

local function InitialiseBuildings()
    for _, building in pairs(testList) do
        --print("Building: " .. tostring(building))
        for _, room in pairs(building.rooms) do
            --print("Room: " .. tostring(room))
            for _, cell in pairs(room) do
                --print("Cell: " .. tostring(cell))
                cell:update()
                
                if #cell.items > 0 then
                    if cleanList[cell.roomName] == nil then
                        print("CleanList room added: " .. cell.roomName)
                        cleanList[cell.roomName] = {}
                    end
                    --print("CleanList room inserted: " .. cell.roomName)
                    table.insert(cleanList[cell.roomName], cell)
                end

                if cell.container then
                    table.insert(containerCells, cell)
                end
            end
        end
    end
end

function Test(mess)
    testList = {}
    cleanList = {}
    containerCells = {}

    highlightCells = {}

    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()

    local startSquare = getCell():getGridSquare(x, y, z)

    local building = Building:new(startSquare) 

    building:populate(x, y, z)
    table.insert(testList, building)
    if mess then building:doMess() end

    InitialiseBuildings()
    --print("highlightCells: " .. tostring(#highlightCells))
end

function Clean()
    for _, building in ipairs(testList) do
        building:clean()
    end
    for _, cell in ipairs(containerCells) do
        --cell:cleanContainer()
    end
end

-- Take all items in a cell and put them in the player's inventory
function TakeAll(player, cell, pos)
    local items = cell.items

    if #items > 0 then
        for i = 1, #items do
            local item = items[i]
            if item ~= nil then
                local time = ISWorldObjectContextMenu.grabItemTime(player, item)
                
                if pos == nil then
                    --print("Item: " .. tostring(item) .. " | Time: " .. time)
                    table.insert(actionQueue, ISGrabItemAction:new(player, item, time))
                else
                    --is a integer
                    if type(pos) == "number" then
                        print("TakeAll inserting at pos: " .. pos)
                        table.insert(actionQueue, pos, ISGrabItemAction:new(player, item, time))
                    end
                end
            end
        end
    end

    cell:update()
end

function TransferAll(player, container, pos)
    local playerInv = player:getInventory()
    local items = playerInv:getItems()
    if items == nil then
        print("No items in inventory")
        return
    end
    --print("Items in inventory: " .. items:size())
    print("Transferring all items to: " .. tostring(container))
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        --print("Item: " .. tostring(item))
        if pos == nil then
            table.insert(actionQueue, ISInventoryTransferAction:new(player, item, playerInv, container))
        else
            --is a integer
            if type(pos) == "number" then
                table.insert(actionQueue, pos, ISInventoryTransferAction:new(player, item, playerInv, container))
            end
        end
    end
end

function TransferItem(player, item, container, pos)
    local playerInv = player:getInventory()
    if pos == nil then
        table.insert(actionQueue, ISInventoryTransferAction:new(player, item, playerInv, container))
    else
        --is a integer
        if type(pos) == "number" then
            table.insert(actionQueue, pos, ISInventoryTransferAction:new(player, item, playerInv, container))
        end
    end
end

function Test2()
    InitialiseBuildings()

    for _, building in ipairs(testList) do
        local playerSquare = getPlayerSquare(getPlayer())
        local closestContainerCell, closestContainer, closestContainerDistance = getClosestContainer(playerSquare)

        if not closestContainer then
            print("No container found")
            return
        end
        if not closestContainerCell then
            print("No container cell found")
            return
        end
        print(tostring(closestContainerCell))
        print(tostring(closestContainer:getType()))

        MoveToLocation(getPlayer(), closestContainerCell.square)
        --TransferAll(getPlayer(), closestContainer)
    end

end

function Reset()
    Test(false)
    Clean()
    --Test(true)
end

function DoCleaning()
    Test(false)
    cleaning = true

    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    local startSquare = getCell():getGridSquare(x, y, z)

    for _, room in pairs(cleanList) do
        for _, cell in ipairs(room) do
            local toSquare = cell.square

            MoveToLocation(player, toSquare)
            
            TakeAll(player, cell)
        end
    end

    MoveToLocation(player, startSquare)
end

-- check all cells in in the cleanList, if they are empty remove them from the list
local function updateCleanList()
    for _, room in pairs(cleanList) do
        for i = #room, 1, -1 do
            local cell = room[i]
            cell:update()
            if #cell.items == 0 then
                table.remove(room, i)
            end
        end
    end
end

local function updateQueue()
    updateCleanList()

    if cleaning then
        local player = getPlayer()
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        local playerInv = player:getInventory()
        local playerInvWeight = playerInv:getCapacityWeight()
        local playerInvMaxWeight = playerInv:getMaxWeight()

        if playerInvWeight < playerInvMaxWeight * 0.8 and emptyQueueActive then
            emptyQueueActive = false
            print("emptyQueueActive: " .. tostring(emptyQueueActive))
        end

        --if playerInv full add moveto action to best containers and transfer all items
        if playerInvWeight >= playerInvMaxWeight and not emptyQueueActive then
            emptyQueueActive = true
            print("emptyQueueActive: " .. tostring(emptyQueueActive))

            local items = playerInv:getItems()

            for i = items:size() - 1, 0, -1 do
                local item = items:get(i)
                local bestContainerCell, bestContainer = getBestContainer(player, item)

                if bestContainer and bestContainerCell then
                    MoveToLocation(player, bestContainerCell.square,1)
                    TransferItem(player, item, bestContainer, 2)
                end
            end
        else
            if #queue.queue == 0 and #actionQueue > 0 and not queue.isPlayerDoingAction(player) then
                queue.add(actionQueue[1])
                table.remove(actionQueue, 1)
            end
        end

        if #queue.queue == 0 and #actionQueue == 0 then
            cleaning = false
            player:Say("Cleaning done")
        end
    end
end

Events.OnTick.Add(updateQueue)