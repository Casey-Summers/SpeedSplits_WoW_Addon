local _, NS = ...

local System = NS.TestSystem

System.RegisterTest({
    id = "ui_ensure_main_frames",
    suite = "UI",
    subcategory = "Bootstrap",
    name = "Creates the main timer and boss frames",
    func = function()
        NS.Database.EnsureDB()
        System.BeginSection("Create the main addon frames")
        NS.UI.EnsureUI()
        System.AssertTrue(NS.UI.timerFrame ~= nil, "Timer frame exists after EnsureUI", NS.UI.timerFrame ~= nil)
        System.AssertTrue(NS.UI.bossFrame ~= nil, "Boss frame exists after EnsureUI", NS.UI.bossFrame ~= nil)
        System.EndSection("Create the main addon frames", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_totals_footer_text",
    suite = "UI",
    subcategory = "Footer",
    name = "Updates totals footer text",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()
        System.BeginSection("Write totals into the footer")
        NS.SetTotals(10, 12, 2, 1, 1, 1, "|cffffffff")
        System.AssertEqual(NS.UI.totalPB:GetText(), "10.000", "Footer PB text matches the formatted total")
        System.EndSection("Write totals into the footer", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_header_colors_follow_accent",
    suite = "UI",
    subcategory = "Header",
    name = "Applies the UI accent color to all splits table headers",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()
        System.BeginSection("Read header colours from the boss table")
        local bossHeader = NS.UI.st.head.cols[2]:GetFontString()
        local pbHeader = NS.UI.st.head.cols[3]:GetFontString()
        local br, bg, bb = bossHeader:GetTextColor()
        local pr, pg, pb = pbHeader:GetTextColor()

        System.AssertNear(br, NS.Colors.turquoise.r, 0.01, "Boss header red channel matches the accent color")
        System.AssertNear(bg, NS.Colors.turquoise.g, 0.01, "Boss header green channel matches the accent color")
        System.AssertNear(bb, NS.Colors.turquoise.b, 0.01, "Boss header blue channel matches the accent color")
        System.AssertNear(pr, NS.Colors.turquoise.r, 0.01, "PB header red channel matches the accent color")
        System.AssertNear(pg, NS.Colors.turquoise.g, 0.01, "PB header green channel matches the accent color")
        System.AssertNear(pb, NS.Colors.turquoise.b, 0.01, "PB header blue channel matches the accent color")
        System.EndSection("Read header colours from the boss table", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_column_separator_baseline",
    suite = "UI",
    subcategory = "Column Grips",
    name = "Keeps the baseline separator texture on column grips",
    func = function()
        System.BeginSection("Apply the baseline column separator")
        local grip = CreateFrame("Frame", nil, UIParent)
        NS.UI.ApplyThinSeparator(grip)
        System.AssertTrue(grip._line ~= nil, "Column grips receive the thin baseline separator", grip._line ~= nil)
        System.EndSection("Apply the baseline column separator", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_resize_grip_callback",
    suite = "UI",
    subcategory = "Resize Grip",
    name = "Fires the frame resize grip callback on mouse-up",
    func = function()
        System.BeginSection("Create and exercise a frame resize grip")
        local frame = CreateFrame("Frame", nil, UIParent)
        local called = false
        local grip = NS.UI.Templates.ResizeGrip.CreateFrameGrip(frame, function()
            called = true
        end)
        grip:GetScript("OnMouseUp")(grip)
        System.AssertTrue(called == true, "Mouse-up triggers the resize callback", called)
        System.EndSection("Create and exercise a frame resize grip", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_column_grip_clears_update",
    suite = "UI",
    subcategory = "Column Grips",
    name = "Clears column grip OnUpdate handlers on mouse-up",
    func = function()
        System.BeginSection("Create and release a column grip drag")
        local grip = NS.UI.Templates.ResizeGrip.CreateColumnGrip(UIParent, 10, 10, nil, function() end, nil)
        grip:GetScript("OnMouseDown")(grip, "LeftButton")
        local before = grip:GetScript("OnUpdate") ~= nil
        grip:GetScript("OnMouseUp")(grip)
        local after = grip:GetScript("OnUpdate") == nil
        System.AssertTrue(before == true, "Mouse-down assigns an OnUpdate handler", before)
        System.AssertTrue(after == true, "Mouse-up clears the OnUpdate handler", after)
        System.EndSection("Create and release a column grip drag", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_scrollbar_skin",
    suite = "UI",
    subcategory = "Scrollbar",
    name = "Applies the scrollbar skin and hides arrow buttons",
    func = function()
        System.BeginSection("Skin a synthetic scrollbar")
        local scroll = CreateFrame("Slider", "SpeedSplitsTestScrollBar", UIParent)
        scroll:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local up = CreateFrame("Button", "SpeedSplitsTestScrollBarScrollUpButton", UIParent)
        local down = CreateFrame("Button", "SpeedSplitsTestScrollBarScrollDownButton", UIParent)
        NS.UI.Templates.ScrollBarSkin.Apply(scroll, 10)
        System.AssertEqual(scroll:GetWidth(), 10, "Scrollbar width matches the requested skin width")
        System.AssertTrue(up:IsShown() == false, "The up arrow is hidden by the skin", up:IsShown())
        System.AssertTrue(down:IsShown() == false, "The down arrow is hidden by the skin", down:IsShown())
        System.EndSection("Skin a synthetic scrollbar", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_dropdown_template_value_updates",
    suite = "UI",
    subcategory = "Dropdown",
    name = "Updates values through the dropdown template",
    func = function()
        System.BeginSection("Initialize a template dropdown")
        local dropdown = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
        local currentValue = nil
        local ok = pcall(NS.UI.Templates.DropDown.Initialize,
            dropdown,
            function()
                return {
                    { text = "One", value = 1 },
                }
            end,
            function()
                return currentValue
            end,
            function(value)
                currentValue = value
            end,
            function(value)
                return value
            end
        )
        System.AssertTrue(ok == true, "DropDown.Initialize completes without throwing", ok)
        System.EndSection("Initialize a template dropdown", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_history_row_template",
    suite = "UI",
    subcategory = "History Row",
    name = "Builds pooled history row widgets",
    func = function()
        System.BeginSection("Create a pooled history row")
        local row = NS.UI.Templates.HistoryRow.Create(UIParent, function() end)
        System.AssertEqual(#row.cols, 8, "History rows create eight columns")
        System.AssertTrue(row.delBtn ~= nil, "History rows create a delete button", row.delBtn ~= nil)
        System.AssertTrue(row.bg ~= nil, "History rows create an alternating background texture", row.bg ~= nil)
        System.EndSection("Create a pooled history row", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_header_cell_template_clicks",
    suite = "UI",
    subcategory = "Header Cell",
    name = "Creates clickable header cell templates",
    func = function()
        System.BeginSection("Create and click a header cell")
        local clicked = false
        local button = NS.UI.Templates.HeaderCell.Create(UIParent, "Test", "CENTER", function()
            clicked = true
        end)
        button:GetScript("OnClick")()
        System.AssertEqual(button:GetFontString():GetText(), "Test", "Header cells retain their label text")
        System.AssertTrue(clicked == true, "Header cell click handlers fire", clicked)
        System.EndSection("Create and click a header cell", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_icon_button_template_clicks",
    suite = "UI",
    subcategory = "Icon Button",
    name = "Binds clicks through the icon button template",
    func = function()
        System.BeginSection("Create and click an icon button")
        local clicked = false
        local button = NS.UI.Templates.IconButton.Create(UIParent, 16, 16, "perks-clock-large", "Clock", function()
            clicked = true
        end)
        button:GetScript("OnClick")()
        System.AssertTrue(clicked == true, "Icon button click handlers fire", clicked)
        System.EndSection("Create and click an icon button", "PASS")
    end,
})
