local addon_name, addon = ...

local AceGUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_name)
local color = color
local helpers = addon.help_funcs

local function get_item_array(items)
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets

    if type(items) == "string" then
        local itemset
        if itemsets[items] ~= nil then
            itemset = itemsets[items]
        elseif global_itemsets[items] ~= nil then
            itemset = global_itemsets[items]
        end
        if itemset ~= nil then
            return itemset.items
        else
            return nil
        end
    else
        return items
    end
end

local function get_item_desc(items)
    local itemsets = addon.db.profile.itemsets
    local global_itemsets = addon.db.global.itemsets

    if type(items) == "string" then
        if itemsets[items] ~= nil then
            return string.format(L["a %s item set item"], color.WHITE .. itemsets[items].name .. color.RESET)
        elseif global_itemsets[items] ~= nil then
            return string.format(L["a %s item set item"], color.CYAN .. global_itemsets[items].name .. color.RESET)
        end
    elseif items and #items > 0 then
        local link = select(2, addon.getRetryCached(addon.longtermCache, GetItemInfo, items[1])) or items[1]
        if #items > 1 then
            return string.format(L["%s or %d others"], link, #items-1)
        else
            return link
        end
    end
    return nil
end

addon:RegisterCondition("EQUIPPED", {
    description = L["Have Item Equipped"],
    icon = "Interface\\Icons\\Ability_warrior_shieldbash",
    fields = { item = { "string", { "string", "number" } } },
    valid = function(_, value)
        return value.item ~= nil
    end,
    evaluate = function(value)
        for _, item in pairs(get_item_array(value.item)) do
            if addon.getCached(addon.combatCache, IsEquippedItem, item) then
                return true
            end
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["you have %s equipped"], addon.nullable(get_item_desc(value.item), L["<item>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
    end
})

addon:RegisterCondition("CARRYING", {
    description = L["Have Item In Bags"],
    icon = "Interface\\Icons\\inv_misc_bag_07",
    fields = { item = { "string", { "string", "number" } }, operator = "string", value = "number" },
    valid = function(_, value)
        return (value.item ~= nil and
                value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache)
        local itemid = addon:FindFirstItemOfItems(cache, get_item_array(value.item), false)
        local count = 0
        if itemid and addon.bagContents[itemid] then
            count = addon.bagContents[itemid].count
        end
        return addon.compare(value.operator, count, value.value)
    end,
    print = function(_, value)
        return addon.compareString(value.operator,
                string.format(L["the number of %s you are carrying"], addon.nullable(get_item_desc(value.item), L["<item>"])),
                addon.nullable(value.value, L["<quantity>"]))
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
            function() return true end,
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Quantity"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Have Item In Bags"], L["Quantity"],
            "The quantity of " .. color.BLIZ_YELLOW .. L["Item"] .. color.RESET .. " you are carrying in your bags.")
    end
})

addon:RegisterCondition("ITEM", {
    description = L["Item Available"],
    icon = "Interface\\Icons\\Inv_drink_05",
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    valid = function(_, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache, evalStart) -- Cooldown until the spell is available
        local itemId = addon:FindFirstItemOfItems(cache, get_item_array(value.item), true)
        if itemId == nil and value.notcarrying then
            itemId = addon:FindFirstItemInItems(get_item_array(value.item))
        end
        if itemId ~= nil then
            local minlevel = select(5, addon.getRetryCached(addon.longtermCache, GetItemInfo, itemId))
            -- Can't use it as we are too low level!
            if minlevel > addon.getCached(cache, UnitLevel, "player") then
                return false
            end
            local start, duration = addon.getCached(cache, GetItemCooldown, itemId)
            if start == 0 and duration == 0 then
                return true
            else
                -- A special spell that shows if the GCD is active ...
                local gcd_start, gcd_duration = addon.getCached(cache, GetSpellCooldown, 61304)
                if gcd_start ~= 0 and gcd_duration ~= 0 then
                    local time = GetTime()
                    local gcd_remain = addon.round(gcd_duration - (time - gcd_start), 3)
                    local remain = addon.round(duration - (time - start), 3)
                    if (remain <= gcd_remain) then
                        return true
                        -- We factor in a fuzziness because we don't know exactly when the spell cooldown calls
                        -- were made, so we say any value between now and the evaluation start is essentially 0
                    elseif (remain - gcd_remain <= time - evalStart) then
                        return true
                    else
                        return false
                    end
                end
                return false
            end
        else
            return false
        end
    end,
    print = function(_, value)
        return string.format(L["%s is available"], addon.nullable(get_item_desc(value.item), L["<item>"])) ..
                (value.notcarrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = AceGUI:Create("CheckBox")
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

addon:RegisterCondition("ITEM_RANGE", {
    description = L["Item In Range"],
    icon = "Interface\\Icons\\inv_misc_bandage_13",
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean" },
    valid = function(_, value)
        return value.item ~= nil
    end,
    evaluate = function(value, cache)
        local itemId = addon:FindFirstItemOfItems(cache, get_item_array(value.item), true)
        if itemId == nil and value.notcarrying then
            itemId = addon:FindFirstItemInItems(get_item_array(value.item))
        end
        if itemId ~= nil then
            return (addon.getCached(cache, IsItemInRange, itemId, "target") == 1)
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["%s is in range"], addon.nullable(get_item_desc(value.item), L["<item>"])) ..
            (value.notcarrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local notcarring = AceGUI:Create("CheckBox")
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})

addon:RegisterCondition("ITEM_COOLDOWN", {
    description = L["Item Cooldown"],
    icon = "Interface\\Icons\\Spell_holy_sealofsacrifice",
    fields = { item = { "string", { "string", "number" } }, notcarrying = "boolean", operator = "string", value = "number" },
    valid = function(_, value)
        return (value.operator ~= nil and addon.isin(addon.operators, value.operator) and
                value.item ~= nil and value.value ~= nil and value.value >= 0)
    end,
    evaluate = function(value, cache) -- Cooldown until the spell is available
        local itemId = addon:FindFirstItemOfItems(cache, get_item_array(value.item), true)
        if itemId == nil and value.notcarrying then
            itemId = addon:FindFirstItemInItems(get_item_array(value.item))
        end
        if itemId ~= nil then
            local cooldown = 0
            local start, duration = addon.getCached(cache, GetItemCooldown, itemId)
            if start ~= 0 and duration ~= 0 then
                cooldown = addon.round(duration - (GetTime() - start), 3)
                if (cooldown < 0) then cooldown = 0 end
            end
            return addon.compare(value.operator, cooldown, value.value)
        end
        return false
    end,
    print = function(_, value)
        return string.format(L["the %s"],
            addon.compareString(value.operator, string.format(L["cooldown on %s"], addon.nullable(get_item_desc(value.item), L["<item>"])),
                                string.format(L["%s seconds"], addon.nullable(value.value)))) ..
                (value.notcarrying and L[", even if you do not currently have one"] or "")
    end,
    widget = function(parent, spec, value)
        local top = parent:GetUserData("top")
        local root = top:GetUserData("root")
        local funcs = top:GetUserData("funcs")

        local icon_group = addon:Widget_ItemWidget(top, "Inventory_EditBox", value,
                function() return true end,
                function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(icon_group)

        local operator_group = addon:Widget_OperatorWidget(value, L["Seconds"],
            function() top:SetStatusText(funcs:print(root, spec)) end)
        parent:AddChild(operator_group)

        local notcarring = AceGUI:Create("CheckBox")
        notcarring:SetWidth(200)
        notcarring:SetLabel(L["Check If Not Carrying"])
        notcarring:SetValue(value.notcarrying)
        notcarring:SetCallback("OnValueChanged", function(_, _, v)
            value.notcarrying = v
            top:SetStatusText(funcs:print(root, spec))
        end)
        parent:AddChild(notcarring)
    end,
    help = function(frame)
        addon.layout_condition_itemwidget_help(frame)
        frame:AddChild(helpers.Gap())
        addon.layout_condition_operatorwidget_help(frame, L["Item Cooldown"], L["Seconds"],
            "The number of seconds before you can use the top item found in " .. color.BLIZ_YELLOW .. L["Item Set"] ..
            color.RESET .. ".  If you are not carrying any item in the item set, this condition will not be " ..
            "successful (regardless of the " .. color.BLIZ_YELLOW .. "Operator" .. color.RESET .. " used.)")
        frame:AddChild(helpers.Gap())
        frame:AddChild(helpers.CreateText(color.BLIZ_YELLOW .. L["Check If Not Carrying"] .. color.RESET .. " - " ..
                "Check the availability of the first item in the item set as if you were carrying it, even " ..
                "if you are not."))
    end
})
