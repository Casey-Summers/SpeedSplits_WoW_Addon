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
        NS.SetTotals(10, 12, 2, NS.Colors.white, NS.Colors.white)
        System.AssertEqual(NS.UI.totalPB:GetText(), "10.000", "Footer PB text matches the formatted total")
        local entry = NS.UI.totalPB._ssNumericCellParts and NS.UI.totalPB._ssNumericCellParts.summary
        System.AssertTrue(entry ~= nil, "Footer PB uses the aligned time-group helper", entry ~= nil)
        if entry then
            System.AssertTrue(entry.minute:IsShown() == false, "Footer PB hides the minute slot for sub-minute values",
                entry.minute:IsShown())
            System.AssertTrue(entry.colon:IsShown() == false, "Footer PB hides the colon for sub-minute values",
                entry.colon:IsShown())
            System.AssertEqual(entry.second:GetText(), "10", "Footer PB keeps the seconds in the fixed second slot")
            System.AssertEqual(entry.decimal:GetText(), ".", "Footer PB uses a dedicated decimal glyph")
            System.AssertEqual(entry.millis:GetText(), "000", "Footer PB keeps the milliseconds in the millis slot")
        end
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
        local bossHeader = NS.UI.customBossHeaders[1]:GetFontString()
        local pbHeader = NS.UI.customBossHeaders[2]:GetFontString()
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
                    { value = "01:00.000", rawSeconds = 60, displayKind = "time", placeholderMillis = 3 },
                    { value = "01:05.000", rawSeconds = 65, displayKind = "time", placeholderMillis = 3 },
                    { value = "+00:05.000", rawSeconds = 5, displayKind = "delta", placeholderMillis = 3, color = NS.Colors.gold },
                },
            },
        }
        NS.UI.rowByBossKey = { boss_a = 1 }
        NS.UI.st:SetData(NS.UI.data, true)
        NS.UI.st:Refresh()

        local row = NS.UI.st.rows[1]
        System.AssertEqual(row.cols[1].text:GetText(), "Boss A", "Boss name remains in the boss-name display column")
        local entry = row.cols[4]._ssNumericCellParts and row.cols[4]._ssNumericCellParts.num
        System.AssertTrue(entry ~= nil, "Difference display column uses the aligned time-group widget", entry ~= nil)
        System.AssertEqual(row.cols[4].text:GetText(), "", "The stock cell font string is cleared to avoid overlap")
        if entry then
            System.AssertEqual(entry.sign:GetText(), "+", "Difference cells keep the sign in a dedicated sign slot")
            System.AssertTrue(entry.minute:IsShown() == false, "Difference cells hide the minute slot for sub-minute values",
                entry.minute:IsShown())
            System.AssertTrue(entry.colon:IsShown() == false, "Difference cells hide the colon for sub-minute values",
                entry.colon:IsShown())
            System.AssertEqual(entry.second:GetText(), "5", "Difference cells keep the seconds in the second slot")
            System.AssertEqual(entry.decimal:GetText(), ".", "Difference cells use a dedicated decimal glyph")
            System.AssertEqual(entry.millis:GetText(), "000", "Difference cells keep the milliseconds in the millis slot")
            local signPoint, signRelative, _, signX = entry.sign:GetPoint(1)
            System.AssertEqual(signPoint, "TOPRIGHT", "Difference sign anchors from its right edge")
            System.AssertTrue(signRelative == entry.second,
                "Difference sign attaches to the first visible numeric section for sub-minute values", signRelative)
            System.AssertEqual(signX, -(NS.UI.GetAlignedTimeSpec("diff").signPad or 0),
                "Difference sign uses the layout sign padding constant")
        end
        System.EndSection("Populate a synthetic boss row", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_custom_headers_replace_lib_headers",
    suite = "UI",
    subcategory = "Header",
    name = "Uses custom splits headers instead of the lib-st header row",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()
        System.BeginSection("Inspect the custom header strip")
        System.AssertTrue(NS.UI.customBossHeaders ~= nil, "Custom boss headers are created", NS.UI.customBossHeaders ~= nil)
        System.AssertEqual(NS.UI.customBossHeaders[2]:GetFontString():GetText(), "PB", "The PB custom header uses the expected label")
        System.AssertTrue(NS.UI.st.head:IsShown() == false or NS.UI.st.head:GetAlpha() == 0,
            "The lib-st header row is hidden for the splits table", NS.UI.st.head:GetAlpha())
        System.EndSection("Inspect the custom header strip", "PASS")
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
    id = "ui_refresh_boss_table_uses_snapshot_values",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Builds the PB column from the supplied snapshot values",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        System.BeginSection("Render a single row with a supplied PB snapshot")
        NS.UI.RefreshBossTableData({
            { key = "A", name = "Boss A" },
        }, {
            ["Boss A"] = 45,
        })

        System.AssertEqual(NS.UI.data[1].cols[2].value, NS.Util.FormatTime(45),
            "The PB column reflects the supplied frozen snapshot value")
        System.EndSection("Render a single row with a supplied PB snapshot", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_diff_column_tracks_cell_bounds_when_resized",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Keeps the Diff text anchored to its cell when the column and scrollbar layout change",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        local oldDeltaWidth = NS.UI._deltaWidth

        System.WithCleanup(function()
            System.BeginSection("Render enough rows to force the scrollbar lane")
            local entries = {}
            local presentation = { rowsByKey = {}, summary = {} }
            for i = 1, 20 do
                local key = "B:" .. i
                entries[#entries + 1] = { key = key, name = "Boss " .. i }
                presentation.rowsByKey[key] = {
                    pbTime = i * 10,
                    splitTime = i * 12,
                    diffTime = i * 2,
                    color = { r = 1, g = 1, b = 1, hex = "|cffffffff" },
                }
            end

            NS.UI.RefreshBossTableData(entries, presentation)
            NS.UI.ApplyTableLayout()

            System.AssertTrue(NS.UI._bossScrollLaneVisible == true,
                "The test data is large enough to enable the scrollbar lane",
                NS.UI._bossScrollLaneVisible)

            local firstRow = NS.UI.st and NS.UI.st.rows and NS.UI.st.rows[1]
            local diffCell = firstRow and firstRow.cols and firstRow.cols[4]
            System.AssertTrue(diffCell ~= nil, "The first visible Diff cell exists", diffCell ~= nil)

            local beforeWidth = diffCell and diffCell:GetWidth() or 0
            local entry = diffCell._ssNumericCellParts and diffCell._ssNumericCellParts.num
            local spec = NS.UI.GetAlignedTimeSpec and NS.UI.GetAlignedTimeSpec("diff") or nil
            System.AssertTrue(entry ~= nil, "The Diff cell creates the aligned time-group font strings", entry ~= nil)
            System.AssertTrue(spec ~= nil, "The Diff column publishes a layout spec", spec ~= nil)
            if entry and spec then
                local signPoint, signRelative, _, signX = entry.sign:GetPoint(1)
                local minutePoint, minuteRelative, _, minuteX = entry.minute:GetPoint(1)
                local secondPoint, secondRelative, _, secondX = entry.second:GetPoint(1)
                local decimalPoint, decimalRelative, _, decimalX = entry.decimal:GetPoint(1)
                local millisPoint, millisRelative, _, millisX = entry.millis:GetPoint(1)
                System.AssertEqual(signPoint, "TOPRIGHT", "The sign slot anchors from its right edge")
                System.AssertEqual(minutePoint, "TOPLEFT", "The minute slot anchors from the host origin")
                System.AssertEqual(secondPoint, "TOPLEFT", "The second slot anchors from the host origin")
                System.AssertEqual(decimalPoint, "TOPLEFT", "The decimal slot anchors from the host origin")
                System.AssertEqual(millisPoint, "TOPLEFT", "The millis slot anchors from the host origin")
                System.AssertTrue(signRelative == entry.second,
                    "The sign attaches to the second slot when minutes are hidden", signRelative)
                System.AssertTrue(minuteRelative == diffCell, "The minute slot is attached to the Diff cell", minuteRelative)
                System.AssertTrue(secondRelative == diffCell, "The second slot is attached to the Diff cell", secondRelative)
                System.AssertTrue(decimalRelative == diffCell, "The decimal slot is attached to the Diff cell", decimalRelative)
                System.AssertTrue(millisRelative == diffCell, "The millis slot is attached to the Diff cell", millisRelative)
                System.AssertEqual(signX, -spec.signPad, "The sign uses the configured sign padding")
                System.AssertEqual(minuteX, spec.minuteRight - spec.minuteBaseWidth,
                    "The minute slot uses the layout-owned left edge")
                System.AssertEqual(secondX, spec.secondLeft, "The second slot uses the layout-owned left edge")
                System.AssertEqual(decimalX, spec.decimalLeft, "The decimal slot uses the layout-owned left edge")
                System.AssertEqual(millisX, spec.millisLeft, "The millis slot uses the layout-owned left edge")
                System.AssertEqual(spec.decimalCenterX, math.floor(beforeWidth / 2 + 0.5),
                    "The decimal spine stays centered on the live column width")
                System.AssertEqual(spec.groupType, "delta", "The Diff column uses the delta layout group")
                System.AssertTrue((spec.signPad or 0) > 0, "The Diff layout exposes a dedicated sign padding constant",
                    spec.signPad)
                System.AssertTrue((spec.symbolPad or 0) > 0, "The Diff layout exposes a shared symbol padding constant",
                    spec.symbolPad)
            end

            System.EndSection("Render enough rows to force the scrollbar lane", "PASS")

            System.BeginSection("Resize the Diff column and confirm the cell width updates")
            NS.UI._deltaWidth = oldDeltaWidth + 40
            NS.UI.ApplyTableLayout()

            firstRow = NS.UI.st and NS.UI.st.rows and NS.UI.st.rows[1]
            diffCell = firstRow and firstRow.cols and firstRow.cols[4]
            local afterWidth = diffCell and diffCell:GetWidth() or 0
            System.AssertTrue(afterWidth ~= beforeWidth, "Changing the Diff width changes the live cell width", afterWidth)

            entry = diffCell._ssNumericCellParts and diffCell._ssNumericCellParts.num
            spec = NS.UI.GetAlignedTimeSpec and NS.UI.GetAlignedTimeSpec("diff") or nil
            if entry and spec then
                local signPoint, signRelative, _, signX = entry.sign:GetPoint(1)
                local minutePoint, minuteRelative, _, minuteX = entry.minute:GetPoint(1)
                local secondPoint, secondRelative, _, secondX = entry.second:GetPoint(1)
                local decimalPoint, decimalRelative, _, decimalX = entry.decimal:GetPoint(1)
                local millisPoint, millisRelative, _, millisX = entry.millis:GetPoint(1)
                System.AssertTrue(signRelative == entry.second, "The sign remains attached after resizing", signRelative)
                System.AssertTrue(minuteRelative == diffCell, "The minute slot remains attached after resizing", minuteRelative)
                System.AssertTrue(secondRelative == diffCell, "The second slot remains attached after resizing", secondRelative)
                System.AssertTrue(decimalRelative == diffCell, "The decimal slot remains attached after resizing", decimalRelative)
                System.AssertTrue(millisRelative == diffCell, "The millis slot remains attached after resizing", millisRelative)
                System.AssertEqual(signX, -spec.signPad, "The sign keeps the configured padding after resizing")
                System.AssertEqual(minuteX, spec.minuteRight - spec.minuteBaseWidth,
                    "The minute slot keeps the updated layout-owned left edge")
                System.AssertEqual(secondX, spec.secondLeft, "The second slot keeps the updated layout-owned left edge")
                System.AssertEqual(decimalX, spec.decimalLeft, "The decimal slot keeps the updated layout-owned left edge")
                System.AssertEqual(millisX, spec.millisLeft, "The millis slot keeps the updated layout-owned left edge")
                System.AssertEqual(spec.decimalCenterX, math.floor(afterWidth / 2 + 0.5),
                    "The decimal spine moves with the resized cell midpoint")
            end
            System.EndSection("Resize the Diff column and confirm the cell width updates", "PASS")
        end, function()
            NS.UI._deltaWidth = oldDeltaWidth
            if NS.UI.ApplyTableLayout then
                NS.UI.ApplyTableLayout()
            end
        end)
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
    id = "ui_management_buttons_wire_to_handlers",
    suite = "UI",
    subcategory = "Settings",
    name = "Wires management buttons to the expected handlers",
    func = function()
        NS.Database.EnsureDB()
        NS.CreateSettingsPanel()

        local panel = _G.SpeedSplitsOptionsPanel
        local oldSaveDefaultLayout = NS.SaveDefaultLayout
        local oldResetLayout = NS.ResetLayout
        local oldStaticPopupShow = StaticPopup_Show
        local saved = false
        local reset = false
        local popupKey

        System.WithCleanup(function()
            System.BeginSection("Trigger settings management buttons")
            NS.SaveDefaultLayout = function()
                saved = true
            end
            NS.ResetLayout = function()
                reset = true
            end
            StaticPopup_Show = function(key)
                popupKey = key
            end

            panel._buttons.saveDefaultLayout:GetScript("OnClick")()
            System.AssertTrue(saved == true, "Save Default Layout button calls the layout save handler", saved)

            panel._buttons.resetLayout:GetScript("OnClick")()
            System.AssertTrue(reset == true, "Reset Layout button calls the layout reset handler", reset)

            panel._buttons.wipeAllRecords:GetScript("OnClick")()
            System.AssertEqual(popupKey, "SPEEDSPLITS_WIPE_CONFIRM", "Wipe button opens the wipe confirmation popup")

            panel._buttons.resetFactory:GetScript("OnClick")()
            System.AssertEqual(popupKey, "SPEEDSPLITS_FACTORY_RESET",
                "Factory reset button opens the factory reset popup")
            System.EndSection("Trigger settings management buttons", "PASS")
        end, function()
            NS.SaveDefaultLayout = oldSaveDefaultLayout
            NS.ResetLayout = oldResetLayout
            StaticPopup_Show = oldStaticPopupShow
        end)
    end,
})

System.RegisterTest({
    id = "ui_decimal_aligned_cell_splits_time_text",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Builds slot-based numeric cells for PB, Split, and Diff",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        System.BeginSection("Render slot-based numeric cells")
        NS.UI.data = {
            {
                key = "boss_decimal",
                cols = {
                    { value = "Boss Decimal" },
                    { value = "1:05.123", rawSeconds = 65.123, displayKind = "time", placeholderMillis = 3, color = NS.Colors.gold },
                    { value = "--:--.---", rawSeconds = nil, displayKind = "placeholder", placeholderMillis = 3, color = NS.Colors.white },
                    { value = "+00:05.123", rawSeconds = 5.123, displayKind = "delta", placeholderMillis = 3, color = NS.Colors.gold },
                },
            },
        }
        NS.UI.rowByBossKey = { boss_decimal = 1 }
        NS.UI.st:SetData(NS.UI.data, true)
        NS.UI.st:Refresh()

        local row = NS.UI.st.rows[1]
        local pbEntry = row.cols[2]._ssNumericCellParts and row.cols[2]._ssNumericCellParts.num
        local splitEntry = row.cols[3]._ssNumericCellParts and row.cols[3]._ssNumericCellParts.num
        local diffEntry = row.cols[4]._ssNumericCellParts and row.cols[4]._ssNumericCellParts.num
        local diffSpec = NS.UI.GetAlignedTimeSpec and NS.UI.GetAlignedTimeSpec("diff") or nil

        System.AssertTrue(pbEntry ~= nil, "PB cells create an aligned time-group entry", pbEntry ~= nil)
        System.AssertTrue(splitEntry ~= nil, "Split cells create an aligned time-group entry", splitEntry ~= nil)
        System.AssertTrue(diffEntry ~= nil, "Diff cells create an aligned time-group entry", diffEntry ~= nil)
        System.AssertEqual(row.cols[2].text:GetText(), "", "PB stock text is cleared after custom rendering")
        if pbEntry and splitEntry and diffEntry then
            System.AssertEqual(pbEntry.minute:GetText(), "1", "PB minutes render in the fixed minute slot")
            System.AssertEqual(pbEntry.second:GetText(), "05", "PB seconds render in the fixed second slot")
            System.AssertEqual(pbEntry.decimal:GetText(), ".", "PB uses a dedicated decimal glyph")
            System.AssertEqual(pbEntry.millis:GetText(), "123", "PB milliseconds render in the fixed millis slot")
            System.AssertEqual(splitEntry.minute:GetText(), "--", "Placeholder minutes render in the minute slot")
            System.AssertEqual(splitEntry.second:GetText(), "--", "Placeholder seconds render in the second slot")
            System.AssertEqual(splitEntry.decimal:GetText(), ".", "Placeholder values keep the decimal glyph")
            System.AssertEqual(splitEntry.millis:GetText(), "---", "Placeholder milliseconds render in the millis slot")
            System.AssertEqual(diffEntry.sign:GetText(), "+", "Diff sign renders in the sign slot")
            System.AssertTrue(diffEntry.minute:IsShown() == false, "Diff hides the minute slot for sub-minute values",
                diffEntry.minute:IsShown())
            System.AssertTrue(diffEntry.colon:IsShown() == false, "Diff hides the colon for sub-minute values",
                diffEntry.colon:IsShown())
            System.AssertEqual(diffEntry.second:GetText(), "5", "Diff seconds render in the fixed second slot")
            System.AssertEqual(diffEntry.decimal:GetText(), ".", "Diff keeps the decimal glyph")
            System.AssertEqual(diffEntry.millis:GetText(), "123", "Diff milliseconds render in the millis slot")
            if diffSpec then
                local signPoint, signRelative, _, signX = diffEntry.sign:GetPoint(1)
                System.AssertEqual(signPoint, "TOPRIGHT", "Diff sign anchors from its right edge")
                System.AssertTrue(signRelative == diffEntry.second,
                    "Diff sign attaches to the visible second slot when minutes are hidden", signRelative)
                System.AssertEqual(signX, -diffSpec.signPad, "Diff sign uses the layout sign padding")
                System.AssertEqual(diffSpec.groupType, "delta", "Diff values use the delta group type")
            end
        end
        System.EndSection("Render slot-based numeric cells", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_footer_decimal_alignment_tracks_column_center",
    suite = "UI",
    subcategory = "Footer",
    name = "Keeps footer totals anchored on the numeric column layout spec after resize",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        local oldDeltaWidth = NS.UI._deltaWidth

        System.WithCleanup(function()
            System.BeginSection("Resize the Diff column and verify the footer layout spec updates")
            NS.SetTotals(100, 120, 5, NS.Colors.white, NS.Colors.gold)
            local beforeSpec = NS.UI.GetAlignedTimeSpec and NS.UI.GetAlignedTimeSpec("footerDiff") or nil
            NS.UI._deltaWidth = oldDeltaWidth + 40
            NS.UI.ApplyTableLayout()
            local afterSpec = NS.UI.GetAlignedTimeSpec and NS.UI.GetAlignedTimeSpec("footerDiff") or nil
            local entry = NS.UI.totalDelta._ssNumericCellParts and NS.UI.totalDelta._ssNumericCellParts.summary

            System.AssertTrue(beforeSpec ~= nil, "The footer diff publishes a layout spec before resizing", beforeSpec ~= nil)
            System.AssertTrue(afterSpec ~= nil, "The footer diff publishes a layout spec after resizing", afterSpec ~= nil)
            System.AssertTrue(entry ~= nil, "The footer diff uses the aligned time-group widget", entry ~= nil)
            if beforeSpec and afterSpec and entry then
                local signPoint, signRelative, _, signX = entry.sign:GetPoint(1)
                local decimalPoint, decimalRelative, _, decimalX = entry.decimal:GetPoint(1)
                local secondPoint, secondRelative, _, secondX = entry.second:GetPoint(1)
                local minutePoint, minuteRelative, _, minuteX = entry.minute:GetPoint(1)
                System.AssertTrue(afterSpec.decimalCenterX ~= beforeSpec.decimalCenterX,
                    "The footer decimal spine moves when the column width changes", afterSpec.decimalCenterX)
                System.AssertEqual(afterSpec.hostWidth, NS.UI._deltaWidth, "The footer diff spec tracks the host width")
                System.AssertEqual(afterSpec.decimalCenterX, math.floor(NS.UI._deltaWidth / 2 + 0.5),
                    "The footer decimal spine stays centered inside the host")
                System.AssertEqual(signPoint, "TOPRIGHT", "The footer sign anchors from its right edge")
                System.AssertEqual(decimalPoint, "TOPLEFT", "The footer decimal slot anchors from the host origin")
                System.AssertEqual(secondPoint, "TOPLEFT", "The footer second slot anchors from the host origin")
                System.AssertEqual(minutePoint, "TOPLEFT", "The footer minute slot anchors from the host origin")
                System.AssertTrue(signRelative == entry.second, "The footer sign remains attached to the visible number",
                    signRelative)
                System.AssertTrue(decimalRelative == NS.UI.totalDelta, "The footer decimal remains attached to the host",
                    decimalRelative)
                System.AssertTrue(secondRelative == NS.UI.totalDelta, "The footer second slot remains attached to the host",
                    secondRelative)
                System.AssertTrue(minuteRelative == NS.UI.totalDelta, "The footer minute slot remains attached to the host",
                    minuteRelative)
                System.AssertEqual(signX, -afterSpec.signPad, "The footer sign uses the updated sign padding")
                System.AssertEqual(decimalX, afterSpec.decimalLeft, "The footer decimal slot uses the updated left edge")
                System.AssertEqual(secondX, afterSpec.secondLeft, "The footer second slot uses the updated left edge")
                System.AssertEqual(minuteX, afterSpec.minuteRight - afterSpec.minuteBaseWidth,
                    "The footer minute slot uses the updated left edge")
            end
            System.EndSection("Resize the Diff column and verify the footer layout spec updates", "PASS")
        end, function()
            NS.UI._deltaWidth = oldDeltaWidth
            NS.UI.ApplyTableLayout()
        end)
    end,
})

System.RegisterTest({
    id = "ui_scrollbar_gutter_keeps_numeric_widths_stable",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Keeps numeric column widths stable when the scrollbar lane activates",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        local beforePB = NS.UI.cols[2].width
        local beforeSplit = NS.UI.cols[3].width
        local beforeDiff = NS.UI.cols[4].width

        System.BeginSection("Toggle enough rows to activate the scrollbar lane")
        NS.UI.RefreshBossTableData({
            { key = "A", name = "Boss A" },
        }, {
            ["Boss A"] = 30,
        })
        local withoutScrollPB = NS.UI.cols[2].width
        local withoutScrollSplit = NS.UI.cols[3].width
        local withoutScrollDiff = NS.UI.cols[4].width

        local entries = {}
        local presentation = { rowsByKey = {}, summary = {} }
        for i = 1, 20 do
            local key = "Scroll:" .. i
            entries[#entries + 1] = { key = key, name = "Boss " .. i }
            presentation.rowsByKey[key] = {
                pbTime = i * 10,
                splitTime = i * 11,
                diffTime = i,
                color = NS.Colors.white,
            }
        end
        NS.UI.RefreshBossTableData(entries, presentation)
        NS.UI.ApplyTableLayout()

        System.AssertTrue(NS.UI._bossScrollLaneVisible == true, "The scrollbar lane becomes visible with many rows",
            NS.UI._bossScrollLaneVisible)
        System.AssertEqual(NS.UI.cols[2].width, withoutScrollPB, "PB width does not change when the scrollbar appears")
        System.AssertEqual(NS.UI.cols[3].width, withoutScrollSplit,
            "Split width does not change when the scrollbar appears")
        System.AssertEqual(NS.UI.cols[4].width, withoutScrollDiff, "Diff width does not change when the scrollbar appears")
        System.AssertEqual(NS.UI._rightInset, NS.UI._bossScrollLaneWidth,
            "The reserved right gutter matches the scrollbar lane width")
        System.EndSection("Toggle enough rows to activate the scrollbar lane", "PASS")

        NS.UI._pbWidth = beforePB
        NS.UI._splitWidth = beforeSplit
        NS.UI._deltaWidth = beforeDiff
        NS.UI.ApplyTableLayout()
    end,
})

System.RegisterTest({
    id = "ui_footer_placeholders_visible_without_entries",
    suite = "UI",
    subcategory = "Footer",
    name = "Shows footer placeholders even when no run entries exist",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        System.BeginSection("Refresh totals without any run summary")
        NS.SetTotals(nil, nil, nil)
        local pbEntry = NS.UI.totalPB._ssNumericCellParts and NS.UI.totalPB._ssNumericCellParts.summary
        local splitEntry = NS.UI.totalSplit._ssNumericCellParts and NS.UI.totalSplit._ssNumericCellParts.summary
        local diffEntry = NS.UI.totalDelta._ssNumericCellParts and NS.UI.totalDelta._ssNumericCellParts.summary

        System.AssertEqual(NS.UI.totalPB:GetText(), "--:--.--", "PB footer host retains the placeholder text")
        System.AssertTrue(pbEntry ~= nil, "PB footer placeholder renders through the numeric widget", pbEntry ~= nil)
        System.AssertTrue(splitEntry ~= nil, "Split footer placeholder renders through the numeric widget", splitEntry ~= nil)
        System.AssertTrue(diffEntry ~= nil, "Diff footer placeholder renders through the numeric widget", diffEntry ~= nil)
        if pbEntry and splitEntry and diffEntry then
            System.AssertEqual(pbEntry.minute:GetText(), "--", "PB placeholder keeps the minute slot text")
            System.AssertEqual(pbEntry.second:GetText(), "--", "PB placeholder keeps the second slot text")
            System.AssertEqual(pbEntry.millis:GetText(), "--", "PB placeholder keeps the two-digit millis text")
            System.AssertEqual(pbEntry.decimal:GetText(), ".", "PB placeholder keeps the decimal glyph")
            System.AssertEqual(splitEntry.decimal:GetText(), ".", "Split placeholder keeps the decimal glyph")
            System.AssertEqual(diffEntry.decimal:GetText(), ".", "Diff placeholder keeps the decimal glyph")
        end
        System.EndSection("Refresh totals without any run summary", "PASS")
    end,
})

System.RegisterTest({
    id = "ui_diff_subsecond_values_use_zero_second_lead_without_colon",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Formats sub-second Diff values as sign plus zero-second lead without a colon",
    func = function()
        NS.Database.EnsureDB()
        NS.UI.EnsureUI()

        System.BeginSection("Render sub-second Diff values")
        NS.UI.data = {
            {
                key = "boss_subsecond",
                cols = {
                    { value = "Boss Subsecond" },
                    { value = "0.424", rawSeconds = 0.424, displayKind = "time", placeholderMillis = 3, color = NS.Colors.gold },
                    { value = "0.424", rawSeconds = 0.424, displayKind = "time", placeholderMillis = 3, color = NS.Colors.white },
                    { value = "+0.424", rawSeconds = 0.424, displayKind = "delta", placeholderMillis = 3, color = NS.Colors.white },
                },
            },
        }
        NS.UI.rowByBossKey = { boss_subsecond = 1 }
        NS.UI.st:SetData(NS.UI.data, true)
        NS.UI.st:Refresh()

        local row = NS.UI.st.rows[1]
        local entry = row.cols[4]._ssNumericCellParts and row.cols[4]._ssNumericCellParts.num
        local spec = NS.UI.GetAlignedTimeSpec and NS.UI.GetAlignedTimeSpec("diff") or nil
        System.AssertTrue(entry ~= nil, "Sub-second Diff cells still use the aligned widget", entry ~= nil)
        if entry and spec then
            local signPoint, signRelative, _, signX = entry.sign:GetPoint(1)
            System.AssertEqual(entry.sign:GetText(), "+", "Sub-second Diff keeps the sign")
            System.AssertTrue(entry.minute:IsShown() == false, "Sub-second Diff hides the minute slot", entry.minute:IsShown())
            System.AssertTrue(entry.colon:IsShown() == false, "Sub-second Diff does not show a colon", entry.colon:IsShown())
            System.AssertEqual(entry.second:GetText(), "0", "Sub-second Diff uses a single zero second lead")
            System.AssertEqual(entry.decimal:GetText(), ".", "Sub-second Diff keeps the decimal glyph")
            System.AssertEqual(entry.millis:GetText(), "424", "Sub-second Diff keeps the milliseconds")
            System.AssertEqual(signPoint, "TOPRIGHT", "Sub-second Diff sign anchors from its right edge")
            System.AssertTrue(signRelative == entry.second, "Sub-second Diff sign attaches to the second slot", signRelative)
            System.AssertEqual(signX, -spec.signPad, "Sub-second Diff sign uses the sign padding constant")
        end
        System.EndSection("Render sub-second Diff values", "PASS")
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
System.RegisterTest({
    id = "ui_settings_npc_models_beta_label",
    suite = "UI",
    subcategory = "Settings",
    name = "Includes (BETA) in the Show NPC View Models setting label",
    func = function()
        NS.Database.EnsureDB()
        NS.CreateSettingsPanel()
        
        local found = false
        local panel = _G.SpeedSplitsOptionsPanel
        for i = 1, panel:GetNumChildren() do
            local child = select(i, panel:GetChildren())
            if child and child.Text and child.Text.GetText then
                local text = child.Text:GetText()
                if text and text:find("Show NPC View Models %(BETA%)") then
                    found = true
                    break
                end
            end
        end
        
        System.AssertTrue(found == true, "The (BETA) label is present in the settings panel", found)
    end,
})

System.RegisterTest({
    id = "ui_boss_model_placeholder_id",
    suite = "UI",
    subcategory = "Boss Table",
    name = "Uses the correct placeholder ID (10045) for boss models",
    func = function()
System.AssertEqual(NS.Const.BOSS_MODEL.PLACEHOLDER_ID, 10045, "The boss model display ID matches the placeholder 10045")
    end,
})
