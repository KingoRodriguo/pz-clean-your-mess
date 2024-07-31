--Debug oriented functions
--DONT USE IN RELEASE

-- item list for random generation
local RandItems = {
    "Base.Torch",
    "Base.Candle",
    "Base.Book",
    "Base.Knife",
    "Base.BottleEmpty",
    "Base.WaterBottleFull",
    "Base.Bandage",
    "Base.Soup",
    "Base.CannedBeans",
    "Base.CannedCornedBeef",
    "Base.CannedChili",
    "Base.CannedSoup",
    "Base.CannedBolognese",
    "Base.CannedCarrots",
    "Base.CannedCorn",
    "Base.CannedMushroomSoup",
    "Base.CannedPeas",
    "Base.CannedSardines",
    "Base.CannedTomato",
}

function DB_getRandItem()
    local s = RandItems[ZombRandBetween(1, #RandItems)]
    --print("Item: " ..s)
    return s
end

