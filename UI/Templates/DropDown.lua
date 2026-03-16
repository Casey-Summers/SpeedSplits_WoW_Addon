local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local DropDown = {}
NS.UI.Templates.DropDown = DropDown

local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo

local function GetTextRegion(dropdown)
    if not dropdown then
        return nil
    end
    if dropdown.Text then
        return dropdown.Text
    end
    if dropdown.GetName then
        local name = dropdown:GetName()
        if name and _G[name .. "Text"] then
            return _G[name .. "Text"]
        end
    end
    local regions = { dropdown:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            return region
        end
    end
    return nil
end

function DropDown.SetSelection(dropdown, value, text)
    if not dropdown then
        return
    end
    if UIDropDownMenu_SetSelectedValue then
        UIDropDownMenu_SetSelectedValue(dropdown, value)
    end
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(dropdown, text or "")
    end
    local label = GetTextRegion(dropdown)
    if label then
        label:SetText(text or "")
        label:SetAlpha(1)
        label:Show()
    end
end

function DropDown.ResolveSelectedText(items, value, fallback)
    for _, item in ipairs(items or {}) do
        if item.value == value then
            return item.text
        end
    end
    return fallback or ""
end

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
                DropDown.SetSelection(dropdown, item.value, item.text)
                if onChanged then
                    onChanged(item.value)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

function DropDown.Refresh(dropdown, buildItems, getValue, fallbackText)
    if not dropdown or not buildItems or not getValue then
        return
    end
    local value = getValue()
    local text = DropDown.ResolveSelectedText(buildItems(), value, fallbackText)
    DropDown.SetSelection(dropdown, value, text)
end
