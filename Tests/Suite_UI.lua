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
        local bossHeader = NS.UI.st.head.cols[1]:GetFontString()
        local pbHeader = NS.UI.st.head.cols[2]:GetFontString()
        local br, bg, bb = bossHeader:GetTextColor()
        local pr, pg, pb = pbHeader:GetTextColor()

        System.AssertNear(br, NS.Colors.turquoise.r, 0.01, "Initial Boss header red channel matches")
        
        -- Trigger a full UI refresh which previously caused headers to turn white
        NS.RefreshAllUI()
        
        local br2, bg2, bb2 = bossHeader:GetTextColor()
        System.AssertNear(br2, NS.Colors.turquoise.r, 0.01, "Boss header color persists after NS.RefreshAllUI")
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
    id = "ui_model_column_respects_setting",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Collapses the NPC model column when view models are disabled",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        local oldValue = NS.DB.Settings.showNPCViewModels
        System.WithCleanup(function()
            System.BeginSection("Disable NPC view models and reflow the table")
            local enabledBossWidth = NS.UI.cols[1].width
            NS.DB.Settings.showNPCViewModels = false
            NS.UI.ApplyTableLayout()
            System.AssertEqual(NS.UI.GetModelColumnWidth(), 0, "The model region width collapses to zero when disabled")
            System.AssertTrue(NS.UI.cols[1].width >= enabledBossWidth,
                "The boss data column remains visible when models are disabled", NS.UI.cols[1].width)
            System.EndSection("Disable NPC view models and reflow the table", "PASS")
        end, function()
            NS.DB.Settings.showNPCViewModels = oldValue
            NS.UI.ApplyTableLayout()
        end)
    end,
})

System.RegisterTest({
    id = "ui_difference_column_mapping",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Maps the difference payload into the Difference display column",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        System.BeginSection("Populate a synthetic boss row")
        NS.UI.data = {
            {
                key = "boss_a",
                cols = {
                    { value = "Boss A" },
                    { value = "01:00.000" },
                    { value = "01:05.000" },
                    { value = "+00:05.000", color = NS.Colors.gold },
                },
            },
        }
        NS.UI.rowByBossKey = { boss_a = 1 }
        NS.UI.st:SetData(NS.UI.data, true)
        NS.UI.st:Refresh()

        local row = NS.UI.st.rows[1]
        System.AssertEqual(row.cols[1].text:GetText(), "Boss A", "Boss name remains in the boss-name display column")
        System.AssertEqual(row.cols[4].text:GetText(), "+00:05.000", "Difference display column reads the difference payload")
        System.EndSection("Populate a synthetic boss row", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_refresh_boss_table_does_not_duplicate_rows",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Rebuilds the boss table without appending duplicate rows",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        local entries = {
            { key = "A", name = "Boss A" },
            { key = "B", name = "Boss B" },
        }
        local pbSegments = {
            ["Boss A"] = 30,
            ["Boss B"] = 40,
        }

        System.BeginSection("Refresh the splits table twice with the same data")
        NS.UI.RefreshBossTableData(entries, pbSegments)
        NS.UI.RefreshBossTableData(entries, pbSegments)
        System.AssertEqual(#NS.UI.data, 2, "Repeated refreshes keep exactly one row per boss")
        System.AssertEqual(NS.UI.data[1].key, "A", "The first boss row stays stable after repeated refreshes")
        System.EndSection("Refresh the splits table twice with the same data", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_ignored_bosses_move_to_bottom",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Moves ignored bosses to the bottom while keeping them visible",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        local instanceName = "Ignored Boss UI Test"
        local oldInstanceName = NS.Run.instanceName
        local oldIgnored = NS.Util.CopyTable(NS.DB.Settings.ignoredBosses)
        local oldAutoIgnored = NS.Util.CopyTable(NS.DB.Settings.autoIgnoredBosses)

        System.WithCleanup(function()
            System.BeginSection("Build a table with one manually ignored boss")
            NS.Run.instanceName = instanceName
            NS.DB.Settings.ignoredBosses[instanceName] = { ["Boss B"] = true }
            NS.DB.Settings.autoIgnoredBosses[instanceName] = {}

            NS.UI.RefreshBossTableData({
                { key = "A", name = "Boss A" },
                { key = "B", name = "Boss B" },
                { key = "C", name = "Boss C" },
            }, {
                ["Boss A"] = 10,
                ["Boss B"] = 20,
                ["Boss C"] = 30,
            })

            System.AssertEqual(NS.UI.data[1].cols[1].value, "Boss A", "Non-ignored bosses stay at the top")
            System.AssertEqual(NS.UI.data[2].cols[1].value, "Boss C", "Other non-ignored bosses preserve encounter order")
            System.AssertEqual(NS.UI.data[3].cols[1].value, "Boss B", "Ignored bosses move to the bottom")
            System.EndSection("Build a table with one manually ignored boss", "PASS")
        end, function()
            NS.Run.instanceName = oldInstanceName
            NS.DB.Settings.ignoredBosses = oldIgnored
            NS.DB.Settings.autoIgnoredBosses = oldAutoIgnored
        end)
    end,
})

System.RegisterTest({
    id = "ui_column_grip_parent_matches_archive",
    suite = "UI",
    subcategory = "Column Grips",
    name = "Parents column grips to the scrolling-table frame like the working archive",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        System.BeginSection("Inspect the active column grip hierarchy")
        local grip = NS.UI._colGrips and NS.UI._colGrips[1]
        System.AssertTrue(grip ~= nil, "A column grip is created for the splits table", grip ~= nil)
        if grip then
            System.AssertTrue(grip:GetParent() == NS.UI.st.frame,
                "Column grips are parented to the scrolling-table frame", grip:GetParent())
            System.AssertTrue(grip:GetFrameLevel() > NS.UI.st.frame:GetFrameLevel(),
                "Column grip frame level stays above the table frame", grip:GetFrameLevel())
        end
        System.EndSection("Inspect the active column grip hierarchy", "PASS")
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
