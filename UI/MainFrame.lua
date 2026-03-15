local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Const = NS.Const
local FrameFactory = UI.Templates.FrameFactory
local ScrollBarSkin = UI.Templates.ScrollBarSkin
local IconButton = UI.Templates.IconButton
local HoverFadeFrame = UI.Templates.HoverFadeFrame

function UI.ShowAddonFrames()
    if NS.RefreshVisibility then
        NS.RefreshVisibility()
    end
end

function UI.HideAddonFrames()
    if UI.timerFrame then
        UI.timerFrame:Hide()
    end
    if UI.bossFrame then
        UI.bossFrame:Hide()
    end
end

local function BuildBossColumns()
    return {
        {
            name = "",
            width = UI.GetModelColumnWidth and UI.GetModelColumnWidth() or UI._modelWidth,
            align = "CENTER",
            DoCellUpdate = UI.Model_DoCellUpdate,
        },
        {
            name = "",
            width = 220,
            align = "LEFT",
            DoCellUpdate = UI.Boss_DoCellUpdate,
        },
        {
            name = "PB",
            width = UI._pbWidth,
            align = "CENTER",
            DoCellUpdate = UI.Num_DoCellUpdate,
            color = UI.PBColor,
        },
        {
            name = "Split",
            width = UI._splitWidth,
            align = "CENTER",
            DoCellUpdate = UI.Num_DoCellUpdate,
            color = UI.SplitColor,
        },
        {
            name = "Difference",
            width = UI._deltaWidth,
            align = "CENTER",
            DoCellUpdate = UI.Num_DoCellUpdate,
            color = UI.DeltaColor,
        },
    }
end

local function GetHeaderColorKey(index)
    return "turquoise"
end

function UI.EnsureUI()
    if UI.bossFrame and UI.timerFrame then
        return
    end

    UI.RestoreColWidths()

    local timerFrame = CreateFrame("Frame", "SpeedSplitsTimerFrame", UIParent, "BackdropTemplate")
    timerFrame:SetFrameStrata("MEDIUM")
    timerFrame:SetClampedToScreen(true)
    timerFrame:SetMovable(true)
    timerFrame:EnableMouse(true)
    timerFrame:RegisterForDrag("LeftButton")
    Util.ApplyResizeBounds(timerFrame, 120, 40, 900, 300)
    UI.SetHoverBackdrop(timerFrame, 0.60)
    timerFrame:SetBackdropColor(0, 0, 0, 0)
    timerFrame:SetBackdropBorderColor(1, 1, 1, 0)

    local timerRestored = UI.RestoreFrameGeom("timer", timerFrame, 140, 50)
    UI.timerFrame = timerFrame

    local pbShine = timerFrame:CreateTexture(nil, "OVERLAY")
    pbShine:SetAtlas("challenges-bannershine")
    pbShine:SetPoint("BOTTOM", timerFrame, "TOP", 0, -20)
    pbShine:SetSize(Const.PB_SHINE_WIDTH, Const.PB_SHINE_HEIGHT)
    pbShine:SetAlpha(0)
    UI.pbShine = pbShine

    local shineAG = pbShine:CreateAnimationGroup()
    local shineIn = shineAG:CreateAnimation("Alpha")
    shineIn:SetFromAlpha(0)
    shineIn:SetToAlpha(1)
    shineIn:SetDuration(0.3)
    shineIn:SetOrder(1)
    local shineHold = shineAG:CreateAnimation("Alpha")
    shineHold:SetFromAlpha(1)
    shineHold:SetToAlpha(1)
    shineHold:SetDuration(2.7)
    shineHold:SetOrder(2)
    local shineOut = shineAG:CreateAnimation("Alpha")
    shineOut:SetFromAlpha(1)
    shineOut:SetToAlpha(0)
    shineOut:SetDuration(1.5)
    shineOut:SetOrder(3)
    UI.pbShineAG = shineAG

    if not timerRestored then
        timerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    timerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SaveFrameGeom("timer", self)
    end)

    HoverFadeFrame.Attach(timerFrame, 0.60, function(alpha)
        if UI._timerResizeGrip then
            UI._timerResizeGrip:SetAlpha(alpha)
        end
    end)

    local timerTextSec = timerFrame:CreateFontString(nil, "OVERLAY")
    timerTextSec:SetPoint("RIGHT", timerFrame, "CENTER", -2, 0)
    timerTextSec:SetJustifyH("RIGHT")
    NS.ApplyFontToFS(timerTextSec, "timer")
    timerTextSec:SetText("0")

    local timerTextMin = timerFrame:CreateFontString(nil, "OVERLAY")
    timerTextMin:SetPoint("RIGHT", timerTextSec, "LEFT", 0, 0)
    timerTextMin:SetJustifyH("RIGHT")
    NS.ApplyFontToFS(timerTextMin, "timer")
    timerTextMin:SetText("")

    local timerTextMs = timerFrame:CreateFontString(nil, "OVERLAY")
    timerTextMs:SetPoint("LEFT", timerFrame, "CENTER", -2, 0)
    timerTextMs:SetJustifyH("LEFT")
    NS.ApplyFontToFS(timerTextMs, "timer")
    timerTextMs:SetText(".000")

    local timerDeltaText = timerFrame:CreateFontString(nil, "OVERLAY")
    timerDeltaText:SetPoint("TOP", timerFrame, "CENTER", 0, -18)
    NS.ApplyFontToFS(timerDeltaText, "num")
    timerDeltaText:SetText("")

    local timerToastBg = timerFrame:CreateTexture(nil, "BACKGROUND", nil, -5)
    timerToastBg:SetAllPoints(timerFrame)
    timerToastBg:SetAlpha(0)
    UI.timerToastBg = timerToastBg

    local toastAG = timerToastBg:CreateAnimationGroup()
    local toastIn = toastAG:CreateAnimation("Alpha")
    toastIn:SetFromAlpha(0)
    toastIn:SetToAlpha(1)
    toastIn:SetDuration(0.2)
    toastIn:SetOrder(1)
    local toastHold = toastAG:CreateAnimation("Alpha")
    toastHold:SetFromAlpha(1)
    toastHold:SetToAlpha(1)
    toastHold:SetDuration(3.0)
    toastHold:SetOrder(2)
    local toastOut = toastAG:CreateAnimation("Alpha")
    toastOut:SetFromAlpha(1)
    toastOut:SetToAlpha(0)
    toastOut:SetDuration(1.5)
    toastOut:SetOrder(3)
    UI.timerToastAG = toastAG

    timerTextSec:SetPoint("RIGHT", timerFrame, "CENTER", 0, 0)

    local bossFrame = CreateFrame("Frame", "SpeedSplitsBossFrame", UIParent, "BackdropTemplate")
    bossFrame:SetFrameStrata("MEDIUM")
    bossFrame:SetClampedToScreen(true)
    bossFrame:SetMovable(true)
    bossFrame:EnableMouse(true)
    bossFrame:RegisterForDrag("LeftButton")
    bossFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    bossFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SaveFrameGeom("boss", self)
    end)
    Util.ApplyResizeBounds(bossFrame, 450, Const.SPLITS_TABLE_MIN_HEIGHT, 1400, 1000)
    bossFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    bossFrame:SetBackdropColor(0, 0, 0, 0.9)
    bossFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)

    local bossRestored = UI.RestoreFrameGeom("boss", bossFrame, 520, 320)
    if not bossRestored then
        bossFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local titleBar = CreateFrame("Frame", nil, bossFrame)
    titleBar:SetHeight(Const.TOP_BAR_H)
    titleBar:SetPoint("TOPLEFT", bossFrame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", bossFrame, "TOPRIGHT", 0, 0)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        bossFrame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        bossFrame:StopMovingOrSizing()
        UI.SaveFrameGeom("boss", bossFrame)
    end)
    titleBar:Hide()

    local ST = Util.ResolveScrollingTable()
    if not ST and NS.Print then
        NS.Print("Missing lib-st (ScrollingTable). Load lib-st before Config/Packages/main_core.xml.")
    end

    local cols = BuildBossColumns()
    local st = ST and ST:CreateST(cols, 6, 24, nil, bossFrame)
    if st then
        st.frame:SetClipsChildren(true)
        if st.scrollframe then
            local scrollbar = _G[st.scrollframe:GetName() .. "ScrollBar"]
            if scrollbar then
                ScrollBarSkin.Apply(scrollbar, 10)
            end
        end
    end
    UI.st = st
    if st then
        st.frame:SetClipsChildren(true)
        UI.SetHoverBackdrop(st.frame, 0.85)
        st:SetDefaultHighlight(0.5, 0.5, 0.5, 0.25)
        st:RegisterEvents({
            ["OnClick"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, button)
                if button == "RightButton" and realrow then
                    local bossName = data[realrow].cols[1].value
                    local instanceName = NS.Run.instanceName or ""
                    if bossName and instanceName ~= "" then
                        local menu = {
                            { text = bossName, isTitle = true, notCheckable = true },
                            {
                                text = NS.IsBossIgnored(bossName) and "Stop ignoring this boss" or "Ignore this boss",
                                func = function()
                                    NS.DB.Settings.ignoredBosses[instanceName] = NS.DB.Settings.ignoredBosses
                                        [instanceName] or {}
                                    NS.DB.Settings.autoIgnoredBosses = NS.DB.Settings.autoIgnoredBosses or {}
                                    NS.DB.Settings.autoIgnoredBosses[instanceName] = NS.DB.Settings.autoIgnoredBosses
                                        [instanceName] or {}
                                    if NS.IsBossIgnored(bossName) then
                                        NS.DB.Settings.ignoredBosses[instanceName][bossName] = nil
                                        NS.DB.Settings.autoIgnoredBosses[instanceName][bossName] = nil
                                    else
                                        NS.DB.Settings.ignoredBosses[instanceName][bossName] = true
                                        NS.DB.Settings.autoIgnoredBosses[instanceName][bossName] = nil
                                    end
                                    if NS.RunLogic and NS.RunLogic.SyncAutoIgnoredBosses then
                                        NS.RunLogic.SyncAutoIgnoredBosses()
                                    end
                                    NS.RefreshAllUI()
                                end,
                                notCheckable = true,
                            },
                        }
                        local contextMenu = CreateFrame("Frame", "SpeedSplitsBossContextMenu", UIParent,
                            "UIDropDownMenuTemplate")
                        UIDropDownMenu_Initialize(contextMenu, function(self, level)
                            for _, item in ipairs(menu) do
                                UIDropDownMenu_AddButton(item, level)
                            end
                        end, "MENU")
                        ToggleDropDownMenu(1, nil, contextMenu, "cursor", 0, 0)
                    end
                end
            end,
        })

        if st.head then
            st.head:SetFrameStrata("HIGH")
            st.head:SetFrameLevel(100)
            if st.head.cols then
                for i = 1, #cols do
                    UI.StyleHeaderCell(st.head.cols[i], cols[i].align, 1.0, cols[i].name, GetHeaderColorKey(i))
                end
            end
        end
    end

    local bgFrame = FrameFactory.CreateHeaderStrip(bossFrame, Const.TOP_BAR_H, 0.4)
    bgFrame:SetFrameLevel(math.max(5, bossFrame:GetFrameLevel() + 2))
    bgFrame:SetClipsChildren(true)
    UI.titleTab = bgFrame

    local titleBg = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    titleBg:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", -200, 20)
    titleBg:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", 200, -20)
    UI.titleBg = titleBg

    if UI.st and UI.st.head then
        UI.st.head:SetParent(bgFrame)
        UI.st.head:SetAllPoints(bgFrame)
        UI.st.head:SetFrameLevel(bgFrame:GetFrameLevel() + 2)
        if UI.st.head.cols then
            for i = 1, #cols do
                UI.StyleHeaderCell(UI.st.head.cols[i], cols[i].align, 1.0, cols[i].name, GetHeaderColorKey(i))
            end
        end
    end

    local killCountCounterText = bgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    killCountCounterText:SetDrawLayer("OVERLAY", 7)
    killCountCounterText:SetPoint("LEFT", bgFrame, "LEFT", 10, 0)
    NS.ApplyFontToFS(killCountCounterText, "header", 1.1)
    killCountCounterText:SetJustifyH("LEFT")
    killCountCounterText:SetWordWrap(false)
    UI.killCountCounterText = killCountCounterText

    local killCountText = bgFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    killCountText:SetDrawLayer("OVERLAY", 7)
    killCountText:SetPoint("LEFT", killCountCounterText, "RIGHT", 4, 0)
    NS.ApplyFontToFS(killCountText, "header", 0.9)
    killCountText:SetJustifyH("LEFT")
    killCountText:SetJustifyV("MIDDLE")
    killCountText:SetWordWrap(true)
    if killCountText.SetMaxLines then
        killCountText:SetMaxLines(2)
    end
    UI.killCountText = killCountText

    local totalFrame = FrameFactory.CreateFooterStrip(bossFrame, 24)
    UI.totalFrame = totalFrame

    local totalBg = totalFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    totalBg:SetAllPoints(totalFrame)
    UI.totalBg = totalBg

    local logoText = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    logoText:SetPoint("LEFT", 10, 0)
    logoText:SetText("SpeedSplits")
    UI.logoText = logoText

    local historyButton = IconButton.Create(
        totalFrame,
        18 * Const.HISTORY_ICON_SCALE,
        18 * Const.HISTORY_ICON_SCALE,
        "perks-clock-large",
        "Run history",
        function()
            UI.ToggleHistoryFrame()
        end
    )
    historyButton:SetPoint("LEFT", logoText, "RIGHT", 8, 0)
    UI.historyButton = historyButton

    local totalPB = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalPB:SetJustifyH("RIGHT")
    totalPB:SetText("--:--.---")
    UI.totalPB = totalPB

    local totalSplit = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalSplit:SetJustifyH("RIGHT")
    totalSplit:SetText("--:--.---")
    UI.totalSplit = totalSplit

    local totalDelta = totalFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalDelta:SetJustifyH("RIGHT")
    totalDelta:SetText("--:--.---")
    UI.totalDelta = totalDelta

    local timerGrip = UI.SetupSizeGrip(timerFrame, function()
        UI.SaveFrameGeom("timer", timerFrame)
    end)
    timerGrip:SetAlpha(0)

    local bossGrip = UI.SetupSizeGrip(bossFrame, function()
        UI.SaveFrameGeom("boss", bossFrame)
        UI.ApplyTableLayout()
        UI.SaveColWidths()
    end)

    bossFrame:SetScript("OnSizeChanged", function()
        UI.ApplyTableLayout()
    end)

    UI.bossFrame = bossFrame
    UI.timerTextMin = timerTextMin
    UI.timerTextSec = timerTextSec
    UI.timerTextMs = timerTextMs
    UI.cols = cols
    UI.data = {}
    UI.rowByBossKey = {}
    UI.timerDeltaText = timerDeltaText
    UI.resizeGrip = bossGrip
    UI._timerResizeGrip = timerGrip

    local borderFrame = FrameFactory.CreateOverlayBorder(bossFrame, 30)
    UI.borderFrame = borderFrame

    UI.EnsureColGrips()
    UI.ApplyTableLayout()
    NS.RefreshAllUI()

    timerFrame:Hide()
    bossFrame:Hide()

    C_Timer.After(0.5, function()
        if NS.RefreshAllUI then
            NS.RefreshAllUI()
        end
    end)
end

function NS.UpdateColorsOnly()
    if not UI.bossFrame then
        return
    end
    if UI.logoText then
        UI.logoText:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 1)
    end
    if UI.killCountText then
        UI.killCountText:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 1)
    end
    if UI.killCountCounterText then
        UI.killCountCounterText:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 1)
    end
    if UI.logoGlow then
        UI.logoGlow:SetTextColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.6)
    end
    if UI.historyButton then
        local tex = UI.historyButton:GetNormalTexture()
        if tex then
            tex:SetVertexColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b)
        end
    end
    if UI.bossFrame then
        UI.bossFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    end
    if UI.borderFrame then
        UI.borderFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)
    end
    if UI.titleTab then
        UI.titleTab:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.5)
    end
    if UI.totalFrame then
        UI.totalFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.5)
    end
    if UI.totalBg then
        UI.totalBg:SetTexture(nil)
        UI.totalBg:SetColorTexture(0.2, 0.2, 0.2, 0.7)
    end
    if UI.titleBg then
        local texName = (NS.DB and NS.DB.Settings and NS.DB.Settings.titleTexture) or NS.TitleTextures[1]
        Util.ApplyBackgroundTexture(UI.titleBg, texName)
    end

    if UI.st and UI.st.head and UI.st.head.cols then
        for i = 1, #UI.st.head.cols do
            UI.StyleHeaderCell(UI.st.head.cols[i], UI.cols[i].align, 1.0, UI.cols[i].name, GetHeaderColorKey(i))
        end
    end
end

function NS.UpdateFontsOnly()
    if not UI.bossFrame then
        return
    end

    if UI.killCountCounterText then NS.ApplyFontToFS(UI.killCountCounterText, "counter", 0.95) end
    if UI.killCountText then NS.ApplyFontToFS(UI.killCountText, "header", 0.9) end
    if UI.totalPB then NS.ApplyFontToFS(UI.totalPB, "num") end
    if UI.totalSplit then NS.ApplyFontToFS(UI.totalSplit, "num") end
    if UI.totalDelta then NS.ApplyFontToFS(UI.totalDelta, "num") end
    if UI.timerTextMin then NS.ApplyFontToFS(UI.timerTextMin, "timer") end
    if UI.timerTextSec then NS.ApplyFontToFS(UI.timerTextSec, "timer") end
    if UI.timerTextMs then NS.ApplyFontToFS(UI.timerTextMs, "timer") end

    if UI.timerDeltaText then
        local f = NS.DB and NS.DB.Settings and NS.DB.Settings.fonts and NS.DB.Settings.fonts.timer
        local fontPath = f and f.font or "Fonts\\FRIZQT__.TTF"
        local fontSize = math.max(8, math.floor((f and f.size or 24) * 0.55))
        local fontFlags = f and f.flags or "OUTLINE"
        UI.timerDeltaText:SetFont(fontPath, fontSize, fontFlags)
    end

    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end
    if UI.st and UI.st.head and UI.st.head.cols then
        for i = 1, #UI.st.head.cols do
            UI.StyleHeaderCell(UI.st.head.cols[i], UI.cols[i].align, 1.0, UI.cols[i].name, GetHeaderColorKey(i))
        end
    end
end

function NS.RefreshAllUI()
    if not UI.bossFrame then
        return
    end

    NS.UpdateColorsFromSettings()
    NS.UpdateToastLayout()
    if NS.RefreshVisibility then
        NS.RefreshVisibility()
    end

    if UI.timerToastBg then
        if NS.Run.inInstance then
            UI.timerToastBg:SetAlpha(0.15)
        else
            UI.timerToastBg:SetAlpha(0)
        end
    end

    if UI.history and UI.history.st and UI.history.st.head and UI.history.st.head.cols then
        local historyScale = (NS.DB and NS.DB.Settings and NS.DB.Settings.historyScale) or 1.0
        for i = 1, #UI.history.st.head.cols do
            local cols = UI.history.st.cols
            if cols and cols[i] then
                UI.StyleHeaderCell(UI.history.st.head.cols[i], cols[i].align, historyScale)
            end
        end
    end

    UI.UpdateTimerFrameBounds()
    if NS.UpdateHistoryLayout then
        NS.UpdateHistoryLayout()
    end

    if NS.Run.entries and #NS.Run.entries > 0 then
        local node = NS.GetBestSplitsSubtable()
        local pbTable = node and node.Segments or {}
        UI.RenderBossTable(NS.Run.entries, pbTable)

        local runningPBTotal = 0
        for _, entry in ipairs(NS.Run.entries) do
            if not NS.IsBossIgnored(entry.name) then
                runningPBTotal = runningPBTotal + (pbTable[entry.name] or 0)
            end
            local splitCumulative = NS.Run.kills[entry.key]
            if splitCumulative then
                local prevCumulative = UI.GetPreviousKilledCumulativeInTableOrder(NS.Run, entry.key)
                local segTime = prevCumulative and (splitCumulative - prevCumulative) or splitCumulative
                local oldSegPB = pbTable[entry.name]
                local isGold = (not oldSegPB) or (segTime <= oldSegPB + 0.001)
                local delta = splitCumulative - runningPBTotal
                local r, g, b, hex = NS.GetPaceColor(delta, false)
                UI.SetRowKilled(entry.key, splitCumulative, runningPBTotal, delta, r, g, b, hex, isGold)
            end
        end
        UI.RefreshTotals(not NS.Run.active and NS.Run.endGameTime > 0)
    end

    if not NS.Run.active and NS.Run.endGameTime > 0 then
        UI.SetTimerText(NS.Run.endGameTime - NS.Run.startGameTime, true)
    end

    if NS.DB and NS.DB.Settings then
        NS.Run.speedrunMode = NS.DB.Settings.speedrunMode or "all"
        if NS.Run.active then
            local isRunComplete = false
            local completionTime
            if NS.Run.speedrunMode == "last" then
                local lastEntry = NS.Run.entries[#NS.Run.entries]
                if lastEntry and NS.Run.kills[lastEntry.key] then
                    isRunComplete = true
                    completionTime = NS.Run.startGameTime + NS.Run.kills[lastEntry.key]
                end
            else
                if (NS.Run.remainingCount or 0) == 0 and #NS.Run.entries > 0 then
                    isRunComplete = true
                    local maxKill = 0
                    for _, killTime in pairs(NS.Run.kills) do
                        if killTime > maxKill then
                            maxKill = killTime
                        end
                    end
                    completionTime = NS.Run.startGameTime + maxKill
                end
            end

            if isRunComplete then
                NS.RunLogic.StopRun(true, completionTime)
            end
        end
    end

    if UI.st and UI.st.Refresh then
        UI.st:Refresh()
    end

    -- Re-apply accent colors and fonts after potential table resets
    NS.UpdateColorsOnly()
    NS.UpdateFontsOnly()
end
