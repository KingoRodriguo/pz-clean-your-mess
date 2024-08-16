require "CYM_main"

Events.OnTick.Add(CYM_UpdateCleaner) -- Update the Cleaner Process
Events.OnFillWorldObjectContextMenu.Add(CYM_createContextOption) -- Add the context menu option to the world objects
