local addon = _G.RotationMaster

local AceGUI = LibStub("AceGUI-3.0")
do
	local Type = "Totem_EditBox"
	local Version = 1
	local playerSpells = {}
	local frame
	
	local function spellFilter(self, spellID)
		local spec = self:GetUserData("spec")
		return playerSpells[spec][spellID]
	end
	
	local function loadPlayerSpells()
        -- Only wipe out the current spec, so you can still see everything for an off spec.
		-- It's a little nicity since WoW doesn't let you see talented spells when not on spec.
    	local currentSpec = 0
		if (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
			currentSpec = GetSpecializationInfo(addon:GetSpecialization())
			if currentSpec == nil then
				return
			end
		elseif (LE_EXPANSION_LEVEL_CURRENT >= 2) then
			currentSpec = addon:GetSpecialization()
		end
		if playerSpells[currentSpec] == nil then
			playerSpells[currentSpec] = {}
        else
			table.wipe(playerSpells[currentSpec])
        end

    	for tab=2, GetNumSpellTabs() do
			local _, _, offset, numEntries, _, offspecId = GetSpellTabInfo(tab)
			if offspecId == 0 then
				offspecId = currentSpec
			end
			if playerSpells[offspecId] == nil then
				playerSpells[offspecId] = {}
            end
            for i=1,numEntries do
                local name, _, spellID = GetSpellBookItemName(i+offset, BOOKTYPE_SPELL)
				if string.find(name, "Totem") then
                    playerSpells[offspecId][spellID] = true
                end
            end
		end
	end
	
	-- I know theres a better way of doing this than this, but not sure for the time being, works fine though!
	local function Constructor()
		local self = AceGUI:Create("Predictor_Base")
		self.spellFilter = spellFilter

		if( not frame ) then
			frame = CreateFrame("Frame")
			frame:RegisterEvent("SPELLS_CHANGED")
			frame:SetScript("OnEvent", loadPlayerSpells)
			frame.tooltip = self.tooltip
			
			loadPlayerSpells(frame)
		end

		return self
	end
	
	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end
