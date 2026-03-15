local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local DropDown = {}
NS.UI.Templates.DropDown = DropDown

local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo

function DropDown.Initialize(dropdown, buildItems, getValue, setValue, onChanged)
    if not dropdown or not UIDropDownMenu_Initialize then
        return
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local items = buildItems()
        if not items then
            return
        end
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.value = item.value
            info.checked = (getValue() == item.value)
            info.func = function()
                setValue(item.value)
                UIDropDownMenu_SetText(dropdown, item.text)
                if onChanged then
                    onChanged(item.value)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end
