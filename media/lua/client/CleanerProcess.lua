-- Requirements
---------------------------------------------
require "class_DEBUG"
require "class_Building"

-- DB Data
---------------------------------------------
local _DB = DB_GetDBMode("Cleaner")

-- local data
---------------------------------------------
local isEnabled = false
local state = "Clean"

local building = nil
local dirtyCells = {}
local containerCells = {}

local player = nil
local inventory = nil

local queue = nil

-- Local functions
---------------------------------------------

local function removeElement(_table, _element)
    if not _table then
        if _DB then DB_Log("Can't remove element because table is nil", "Error") end
        return
    end

    if not _element then
        if _DB then DB_Log("Can't remove element because element is nil", "Error") end
        return
    end

    for i = #_table, 1, -1 do
        if _table[i] == _element then
            table.remove(_table, i)
        end
    end
end

local function getPlayerSquare(player)
    if not player then
        --if _DB then DB_Log("Can't get player square because player is nil", "Error") end
        return nil
    end

    local x, y, z = player:getX(), player:getY(), player:getZ()
    local playerSquare = getCell():getGridSquare(x, y, z)

    --if _DB then DB_Log("Player Square: " .. tostring(playerSquare), "Info") end
    return playerSquare
end

local function resetCleaner()
    if _DB then DB_Log("Reset Cleaner", "Info") end
    player = nil
    isEnabled = false
    state = "Clean"

    building = nil
    dirtyCells = {}
    containerCells = {}

    queue = nil
    inventory = nil
end

local function createBuilding(startSquare)
    if not startSquare then
        if _DB then DB_Log("Can't create building because startSquare is nil", "Error") end
        return
    end

    if building then
        if _DB then DB_Log("Can't create building because there is already a building", "Error") end
        return
    end

    -- Initialize building
    building = Building:new(startSquare)
    building.building = building:SetBuilding()
    building.cells = building:GetCells(startSquare)
end

local function getClosestCell(player, cells)
    if not player then
        if _DB then DB_Log("Can't get closest cell because player is nil", "Error") end
        return nil
    end

    if not cells or #cells == 0 then
        if _DB then DB_Log("Can't get closest cell because cells is nil or empty", "Error") end
        return nil
    end

    local closestCell = nil
    local closestDistance = 999999

    for i = 1, #cells do
        local cell = cells[i]
        local distance = cell.square:DistTo(getPlayerSquare(player))
        if distance < closestDistance then
            closestCell = cell
            closestDistance = distance
        end
    end

    return closestCell
end

local function getClosestContainerCell(player, item, cells)
    if not player then
        if _DB then DB_Log("Can't get closest container cell because player is nil", "Error") end
        return nil
    end

    if not cells or #cells == 0 then
        if _DB then DB_Log("Can't get closest container cell because cells is nil or empty", "Error") end
        return nil
    end

    if not item then
        if _DB then DB_Log("Can't get closest container cell because item is nil", "Error") end
        return nil
    end

    local closestContainerCell = nil

    for i = #cells, 1, -1 do
        local cell = cells[i]
        local container = cell:GetCellContainer()
        if not container then
            -- remove cell from cells if container is nil
            removeElement(cells, cell)
        end
        if (container:getCapacityWeight() + item:getActualWeight()) > container:getMaxWeight() then
            -- remove cell from cells if container + item is full or container is nil
            removeElement(cells, cell)
        end
    end

    closestContainerCell = getClosestCell(player, cells)

    return closestContainerCell
end

local function getEquippedWeight(container)
    if not container then
        --if _DB then DB_Log("Can't get equipped weight because container is nil", "Error") end
        return nil
    end

    local equippedWeight = 0
    local items = container:getItems()
    if not items or items:size() == 0 then
        --if _DB then DB_Log("Can't get equipped weight because items is nil or empty", "Error") end
        return nil
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:isEquipped() then
            equippedWeight = equippedWeight + item:getEquippedWeight()
        end
    end
    equippedWeight = math.floor(equippedWeight * 100) / 100
    return equippedWeight
end

local function getNotEquippedItems(inventoryItems)
    local notEquippedItems = {}
    if not inventoryItems or inventoryItems:size() == 0 then
        if _DB then DB_Log("Can't get not equipped items because inventoryItems is nil or empty", "Error") end
        return notEquippedItems
    end
    for i = 0, inventoryItems:size() - 1 do
        local item = inventoryItems:get(i)
        if item and not item:isEquipped() and not instanceof(item, "KeyRing") then
            table.insert(notEquippedItems,item)
        end
    end
    return notEquippedItems
end

local function moveToCell(cell)
    if not cell then
        if _DB then DB_Log("Can't move to cell because cell is nil", "Error") end
        return nil
    end
    local square = cell.square
    square = AdjacentFreeTileFinder.Find(square, player)
    local action = ISWalkToTimedAction:new(player, square)
    return action
end

local function takeItem(item)
    if not item then
        if _DB then DB_Log("Can't take item because item is nil", "Error") end
        return nil
    end

    local time = ISWorldObjectContextMenu.grabItemTime(player, item)
    local action = ISGrabItemAction:new(player, item, time)
    return action
end

local function TransferItem(player, inventoryItems, container)
    local playerInv = player:getInventory()
    local action = nil
    if not inventoryItems or #inventoryItems == 0 then
        if _DB then DB_Log("Can't transfer item because inventoryItems is nil or empty", "Error") end
        return nil
    end
    local item = nil

    for i = 1, #inventoryItems do
        local _item = inventoryItems[i]
        if _item and not _item:isEquipped() and not instanceof(_item, "KeyRing") then
            item = _item
            break
        end
    end
    if item then
        action = ISInventoryTransferAction:new(player, item, item:getContainer(), container)
    end
    return action
end

local function getNextAction()
    local action = nil
    if state == "Clean" then
        -- If player full switch to state "Store"
        if inventory and inventory:getCapacityWeight() >= inventory:getMaxWeight() then
            state = "Store"
            return "SKIP"
        end
        if #dirtyCells > 0 then
            local cell = getClosestCell(player, dirtyCells)
            local cellSquare = nil
            if cell and cell.square then
                cellSquare = AdjacentFreeTileFinder.Find(cell.square, player)
            end
            local playerSquare = getPlayerSquare(player)
            if cellSquare == playerSquare then
                --if _DB then DB_Log("Player is in cell", "Info") end
                -- Check if cell is dirty
                if cell and cell:GetDirtiness() > 0 then
                    --if _DB then DB_Log("Cleaning cell", "Info") end
                    local items = cell:GetItems()
                    -- Take item
                    if #items > 0 then
                        action = takeItem(items[1])
                        if _DB then DB_Log("Taking item", "Info") end
                        return action
                    end
                else
                    -- Remove clean cell from dirtyCells
                    removeElement(dirtyCells, cell)
                    if _DB then DB_Log("Skipping clean cell", "Info") end
                    return "SKIP"
                end
            else
                --if _DB then DB_Log("Moving to cell", "Info") end
                action = moveToCell(cell)
                if _DB then DB_Log("Moving to cell", "Info") end
                return action
            end
        else
            if _DB then DB_Log("No dirty cells found", "Info") end
            return "END"
        end
    end
    if state == "Store" then
        if _DB then DB_Log("Storing items", "Info") end
        if inventory then
            local inventoryWeight = math.floor(inventory:getCapacityWeight() * 100) / 100
            if inventoryWeight == getEquippedWeight(inventory) then
                -- Player inventory is empty (except equipped items)
                state = "Clean"
                return "SKIP"
            else
                -- Player inventory is not empty
                if _DB then
                    if _DB then 
                        DB_Log("Player inventory is not empty", "Info")
                        DB_Log("Player inventory weight: " .. tostring(inventoryWeight), "Info")
                        DB_Log("Player equipped weight: " .. tostring(getEquippedWeight(inventory)), "Info")
                    end
                end
            end
            local inventoryAllItems = inventory:getItems()
            local inventoryItems = getNotEquippedItems(inventoryAllItems)
            if not inventoryItems or #inventoryItems == 0 then
                if _DB then DB_Log("No items found in inventory", "Error") end
                state = "Clean"
                return "SKIP"
            end
            local item = inventoryItems[1]
            local containerCell = nil
            local cellSquare = nil
            if item then
                if containerCells and #containerCells > 0 then
                    containerCell = getClosestContainerCell(player, item, containerCells)
                else
                    if _DB then DB_Log("No closest container cells found", "Error") end
                end
            else
                if _DB then DB_Log("No item found in inventory", "Error") end
            end
            if containerCell and containerCell.square then
                cellSquare = AdjacentFreeTileFinder.Find(containerCell.square, player)
            end

            local playerSquare = getPlayerSquare(player)
            if cellSquare and cellSquare == playerSquare then
                if _DB then DB_Log("Player is in container cell", "Info") end
                local container = nil
                if containerCell then
                    container = containerCell:GetCellContainer()
                else
                    if _DB then DB_Log("Container cell is nil", "Error") end
                end
                if container then
                    action = TransferItem(player, inventoryItems, container)
                    if action then
                        if _DB then DB_Log("TransferItem action added to queue", "Info") end
                        return action
                    else
                        if _DB then DB_Log("TransferItem action is nil", "Error") end
                        return "SKIP"
                    end
                else
                    if _DB then DB_Log("Container is nil", "Error") end
                end
            elseif cellSquare then
                if _DB then DB_Log("Moving to Container cell", "Info") end
                action = moveToCell(containerCell)
                if action then
                    if _DB then DB_Log("MoveToCell action added to queue", "Info") end
                    return action
                else
                    if _DB then DB_Log("MoveToCell action is nil", "Error") end
                    return "SKIP"
                end
            else
                if _DB then DB_Log("No container cell found", "Error") end
            end
        else
            if _DB then DB_Log("Player inventory is nil", "Error") end
        end
    end
end

local function forceStop()
    isEnabled = false
    resetCleaner()
end

local function UpdateCleaner()
    if not isEnabled then return end
    if queue == nil then return end
    if player == nil then return end

    if player:pressedMovement(false) or player:pressedCancelAction() then
        forceStop()
        return
    end

    --if _DB then DB_Log("Queue size: " ..#queue.queue, "Info") end
    if #queue.queue == 0 and not queue.isPlayerDoingAction(player) then
        --if _DB then DB_Log("Cleaner is running", "Info") end
        local action = getNextAction()
        if action then
            if action == "SKIP" then
                return
            elseif action == "END" then
                player:Say("Cleaning is done")
                isEnabled = false
                resetCleaner()
            else
                --if _DB then DB_Log("Adding action to queue", "Info") end
                queue.add(action)
            end
        elseif not action then
            if _DB then DB_Log("Action is nil", "Error") end
            isEnabled = false

        else
            if _DB then DB_Log("Action is not valid", "Error") end
            isEnabled = false
        end
    end
end

-- Global functions
---------------------------------------------

function CleanYourMess(start_square)
    --Startup procedure
    if isEnabled then
        if _DB then DB_Log("Cleaner is already enabled", "Info") end
        return
    end

    resetCleaner()

    player = getPlayer()
    inventory = player:getInventory()
    queue = ISTimedActionQueue.getTimedActionQueue(player)

    -- Check if start_square is nil
    if not start_square then
        if _DB then DB_Log("Can't clean because start_square is nil", "Error") end
        return
    end
    -- Check if start_square is indoor
    if not start_square:getRoom() then
        player:Say("I cannot clean outside")
        if _DB then DB_Log("Can't clean because start_square is outdoor", "Info") end
        return
    end

    -- Create Building Structure
    createBuilding(start_square)

    -- Check if building is nil
    if not building then
        if _DB then DB_Log("Can't clean because building is nil", "Error") end
        return
    end

    -- Initialize dirtyCells
    dirtyCells = building:GetDirtyCells()
    if not dirtyCells or #dirtyCells == 0 then
        player:Say("There is nothing to clean")
        if _DB then DB_Log("Can't clean because there is nothing to clean", "Info") end
        return
    end

    -- Initialize containerCell
    containerCells = building:GetContainersCells()
    if not containerCells or #containerCells == 0 then
        player:Say("There is no container to store items")
        if _DB then DB_Log("Can't clean because there is no container to store items", "Info") end
        return
    end

    isEnabled = true
end

-- Events
---------------------------------------------

local function createContextOption(player, context, worldObjects, test)
    local object = worldObjects[1]
    local x,y,z = object:getX(), object:getY(), object:getZ()
    local square = getCell():getGridSquare(x, y, z)
    if square:getRoom() == nil then return end
    local _mainMenu = context:addOption("Clean the mess", worldObjects, function() 
        CleanYourMess(square)
    end)
end

Events.OnTick.Add(UpdateCleaner)
Events.OnFillWorldObjectContextMenu.Add(createContextOption)