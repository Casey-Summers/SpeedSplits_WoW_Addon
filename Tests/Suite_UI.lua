local _, NS = ...

local System = NS.TestSystem

System.RegisterTest("EnsureUI creates main frames", "UI", function()
    NS.Database.EnsureDB()
    NS.UI.EnsureUI()
    System.Assert(NS.UI.timerFrame ~= nil, true, NS.UI.timerFrame ~= nil)
    System.Assert(NS.UI.bossFrame ~= nil, true, NS.UI.bossFrame ~= nil)
end)

System.RegisterTest("SetTotals updates footer text", "UI", function()
    NS.Database.EnsureDB()
    NS.UI.EnsureUI()
    NS.SetTotals(10, 12, 2, 1, 1, 1, "|cffffffff")
    System.Assert(NS.UI.totalPB:GetText() == "10.000", "10.000", NS.UI.totalPB:GetText())
end)

System.RegisterTest("Resize grip callback fires on mouse-up", "UI", function()
    local frame = CreateFrame("Frame", nil, UIParent)
    local called = false
    local grip = NS.UI.Templates.ResizeGrip.CreateFrameGrip(frame, function()
        called = true
    end)
    grip:GetScript("OnMouseUp")(grip)
    System.Assert(called == true, true, called)
end)

System.RegisterTest("Column grip clears OnUpdate on mouse-up", "UI", function()
    local grip = NS.UI.Templates.ResizeGrip.CreateColumnGrip(UIParent, 10, 10, nil, function() end, nil)
    grip:GetScript("OnMouseDown")(grip, "LeftButton")
    local before = grip:GetScript("OnUpdate") ~= nil
    grip:GetScript("OnMouseUp")(grip)
    local after = grip:GetScript("OnUpdate") == nil
    System.Assert(before == true, true, before)
    System.Assert(after == true, true, after)
end)

System.RegisterTest("Scrollbar skin applies thumb and width", "UI", function()
    local scroll = CreateFrame("Slider", "SpeedSplitsTestScrollBar", UIParent)
    scroll:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local up = CreateFrame("Button", "SpeedSplitsTestScrollBarScrollUpButton", UIParent)
    local down = CreateFrame("Button", "SpeedSplitsTestScrollBarScrollDownButton", UIParent)
    NS.UI.Templates.ScrollBarSkin.Apply(scroll, 10)
    System.Assert(scroll:GetWidth() == 10, 10, scroll:GetWidth())
    System.Assert(up:IsShown() == false, false, up:IsShown())
    System.Assert(down:IsShown() == false, false, down:IsShown())
end)

System.RegisterTest("Dropdown template updates value and callback", "UI", function()
    local dropdown = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
    local ok = pcall(NS.UI.Templates.DropDown.Initialize,
        dropdown,
        function()
            return {
                { text = "One", value = 1 },
            }
        end,
        function()
            return value
        end,
        function(v)
            value = v
        end,
        function(v)
            return v
        end
    )
    System.Assert(ok == true, true, ok)
end)

System.RegisterTest("History row template creates pooled row widgets", "UI", function()
    local row = NS.UI.Templates.HistoryRow.Create(UIParent, function() end)
    System.Assert(#row.cols == 8, 8, #row.cols)
    System.Assert(row.delBtn ~= nil, true, row.delBtn ~= nil)
    System.Assert(row.bg ~= nil, true, row.bg ~= nil)
end)

System.RegisterTest("Header cell template creates clickable header", "UI", function()
    local clicked = false
    local button = NS.UI.Templates.HeaderCell.Create(UIParent, "Test", "CENTER", function()
        clicked = true
    end)
    button:GetScript("OnClick")()
    System.Assert(button:GetFontString():GetText() == "Test", "Test", button:GetFontString():GetText())
    System.Assert(clicked == true, true, clicked)
end)

System.RegisterTest("Icon button template binds click callback", "UI", function()
    local clicked = false
    local button = NS.UI.Templates.IconButton.Create(UIParent, 16, 16, "perks-clock-large", "Clock", function()
        clicked = true
    end)
    button:GetScript("OnClick")()
    System.Assert(clicked == true, true, clicked)
end)
