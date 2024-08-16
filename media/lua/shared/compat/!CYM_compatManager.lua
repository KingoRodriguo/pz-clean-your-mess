CYM_Compat = CYM_Compat or {}
CYM_Compat.SmarterStorage = CYM_Compat.SmarterStorage or false
CYM_Compat.ManageContainers = CYM_Compat.ManageContainers or false

-- check if Smarter Storage is active
function SS_check()
    local ModInfo = getModInfoByID("SmarterStorage") or nil
    if ModInfo then 
        local active = isModActive(ModInfo)
        if active then
            CYM_Compat.SmarterStorage = true
            print("CYM: Smarter Storage is active")
        else
            CYM_Compat.SmarterStorage = false
            print("CYM: Smarter Storage is not active")
        end
    else
        CYM_Compat.SmarterStorage = false
        print("CYM: Smarter Storage is not found")
    end
end

-- check if Manage Containers is active
function MC_check()
    local ModInfo = getModInfoByID("ManageContainers") or nil
    if ModInfo then 
        local active = isModActive(ModInfo)
        if active then
            CYM_Compat.ManageContainers = true
            print("CYM: Manage Containers is active")
        else
            CYM_Compat.ManageContainers = false
            print("CYM: Manage Containers is not active")
        end
    else
        CYM_Compat.ManageContainers = false
        print("CYM: Manage Containers is not found")
    end
end

SS_check()
MC_check()