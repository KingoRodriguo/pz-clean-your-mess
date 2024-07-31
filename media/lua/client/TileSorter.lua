local testList = {}
local cleanList = {}
local containerCells = {}

local actionQueue = {}

local emptyQueueActive = false

local function MoveToLocation(player, toSquare, pos)
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()

    local playerSquare = getCell():getGridSquare(x, y, z)

    if playerSquare:isBlockedTo(toSquare) then
        print("path blocked")
        return false
    end

    if pos == nil then
        table.insert(actionQueue, ISWalkToTimedAction:new(player, toSquare))
    else
        --is a integer
        if type(pos) == "number" then
            table.insert(actionQueue, pos, ISWalkToTimedAction:new(player, toSquare))
        end
    end
    return true
end

function Test()
    testList = {}
    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()

    local startSquare = getCell():getGridSquare(x, y, z)

    local building = Building:new(startSquare) 

    building:populate(x, y, z)
    table.insert(testList, building)
    --building:doMess()
end

function Clean()
    for _, building in ipairs(testList) do
        building:clean()
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
                    table.insert(actionQueue, ISGrabItemAction:new(player, item, time))
                else
                    --is a integer
                    if type(pos) == "number" then
                        table.insert(actionQueue, pos, ISGrabItemAction:new(player, item, time))
                    end
                end
            end
        end
    end

    cell:update()
end

function TransferAll(player, container, queue)
    local playerInv = player:getInventory()
    local items = playerInv:getItems()
    if items == nil then
        return
    end
    for _, item in ipairs(items) do
        table.insert(queue,ISInventoryTransferAction:new(player, item, item:getContainer(), container))
    end
end

function Test2()
    for _, building in ipairs(testList) do
        for _, room in pairs(building.rooms) do
            print("Room: " ..room)
        end
    end
end

function DoCleaning()
    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    local startSquare = getCell():getGridSquare(x, y, z)

    for _, building in pairs(testList) do
        --print("Building: " .. tostring(building))
        for _, room in pairs(building.rooms) do
            --print("Room: " .. tostring(room))
            for _, cell in pairs(room) do
                --print("Cell: " .. tostring(cell))
                cell:update()
                
                if #cell.items > 0 then
                    if cleanList[cell.roomName] == nil then
                        --print("CleanList room added: " .. cell.roomName)
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

    for _, room in pairs(cleanList) do
        for _, cell in ipairs(room) do
            local toSquare = cell.square

            MoveToLocation(player, toSquare, actionQueue)
            TakeAll(player, cell, actionQueue)
        end
    end

    MoveToLocation(player, startSquare, actionQueue)
end

function Reset()
    Test()
    Clean()
    testList = {}
    Test()
end


local function updateQueue()
    local player = getPlayer()
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    local playerInv = player:getInventory()
    local playerInvWeight = playerInv:getCapacityWeight()
    local playerInvMaxWeight = playerInv:getMaxWeight()

    --print("Player weight: " .. playerInvWeight .. " | Max weight: " .. playerInvMaxWeight)
    if emptyQueueActive and playerInvWeight < playerInvMaxWeight then
        emptyQueueActive = false
    end

    --if playerInv full add moveto action to closest container and transfer all items
    if playerInvWeight >= playerInvMaxWeight and not emptyQueueActive then
        emptyQueueActive = true
        local closestContainer = nil
        local closestDistance = 1000
        local x = player:getX()
        local y = player:getY()
        local z = player:getZ()
        local playerSquare = getCell():getGridSquare(x, y, z)

        for _, cell in ipairs(containerCells) do
            local distance = 1000
            if cell.square then
                distance = cell.square:DistTo(playerSquare)
            end
            if distance < closestDistance then
                closestContainer = cell
                closestDistance = distance
            end
        end

        if closestContainer then
            print("Moving to container. distance: " .. closestDistance)
            MoveToLocation(player, closestContainer.square, 1)
            TransferAll(player, closestContainer.container, 1)
            MoveToLocation(player, playerSquare, 1)
        end
    end

    if #queue.queue == 0 and #actionQueue > 0 and not queue.isPlayerDoingAction(player) then
        print("Queue action added")
        queue.add(actionQueue[1])
        table.remove(actionQueue, 1)
    end
end

Events.OnTick.Add(updateQueue)