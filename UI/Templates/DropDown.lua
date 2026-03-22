local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local DropDown = {}
NS.UI.Templates.DropDown = DropDown

local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_SetSelectedValue = _G.UIDropDownMenu_SetSelectedValue
local UIDropDownMenu_SetSelectedName = _G.UIDropDownMenu_SetSelectedName
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local UIDropDownMenu_JustifyText = _G.UIDropDownMenu_JustifyText
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

function DropDown.Create(parent, width, scale, name)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    if UIDropDownMenu_SetWidth then
        UIDropDownMenu_SetWidth(dropdown, width or 120)
    end
    if UIDropDownMenu_JustifyText then
        UIDropDownMenu_JustifyText(dropdown, "LEFT")
    end
    dropdown:SetScale(scale or 1)
    return dropdown
end

function DropDown.SetSelection(dropdown, value, text)
    if not dropdown then
        return
    end
    if UIDropDownMenu_SetSelectedValue then
        UIDropDownMenu_SetSelectedValue(dropdown, value)
    end
    if UIDropDownMenu_SetSelectedName then
        UIDropDownMenu_SetSelectedName(dropdown, text or "")
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

function DropDown.Bind(dropdown, config)
    if not dropdown or type(config) ~= "table" then
        return
    end

    dropdown._ssConfig = config
    DropDown.Initialize(dropdown, config.buildItems, config.getValue, config.setValue, config.onChanged)
    DropDown.Refresh(dropdown, config.buildItems, config.getValue, config.fallbackText)
end

function DropDown.RefreshBound(dropdown)
    local config = dropdown and dropdown._ssConfig
    if not config then
        return
    end
    DropDown.Refresh(dropdown, config.buildItems, config.getValue, config.fallbackText)
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
