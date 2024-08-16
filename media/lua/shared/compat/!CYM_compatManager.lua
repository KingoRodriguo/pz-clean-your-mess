CYM_Compat = CYM_Compat or {}
CYM_Compat.SmarterStorage = CYM_Compat.SmarterStorage or false

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

SS_check()