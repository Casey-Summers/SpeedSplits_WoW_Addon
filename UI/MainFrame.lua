local _, NS = ...

local UI = NS.UI
local Util = NS.Util
local Const = NS.Const
local FrameFactory = UI.Templates.FrameFactory
local ScrollBarSkin = UI.Templates.ScrollBarSkin
local IconButton = UI.Templates.IconButton
local HoverFadeFrame = UI.Templates.HoverFadeFrame
local HeaderCell = UI.Templates.HeaderCell

local BOSS_HEADER_LABELS = { "", "PB", "Split", "Diff" }

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
            width = 220,
            align = "LEFT",
            DoCellUpdate = UI.Boss_DoCellUpdate,
        },
        {
            name = "",
            width = UI._pbWidth,
            align = "CENTER",
            DoCellUpdate = UI.Num_DoCellUpdate,
            color = UI.PBColor,
        },
        {
            name = "",
            width = UI._splitWidth,
            align = "CENTER",
            DoCellUpdate = UI.Num_DoCellUpdate,
            color = UI.SplitColor,
        },
        {
            name = "",
            width = UI._deltaWidth,
            align = "CENTER",
            DoCellUpdate = UI.Num_DoCellUpdate,
            color = UI.DeltaColor,
        },
    }
end

function UI.RestyleBossTableHeaders(scale)
    if UI.st and UI.st.head then
        UI.st.head:SetAlpha(0)
        UI.st.head:Hide()
        UI.st.head:EnableMouse(false)
    end

    if not (UI.customBossHeaders and UI.cols) then
        return
    end

    for i = 1, #UI.customBossHeaders do
        local align = (UI.cols[i] and UI.cols[i].align) or "CENTER"
        local text = BOSS_HEADER_LABELS[i] or ""
        if UI.cols[i] and UI.customBossHeaders[i] then
            UI.StyleHeaderCell(UI.customBossHeaders[i], align, scale or 1.0, text, "turquoise")
            UI.customBossHeaders[i]:EnableMouse(false)
        end
    end
end

local function EnsureBossHeaderCells(parent)
    if UI.customBossHeaders or not parent then
        return
    end

    UI.customBossHeaders = {}
    for i = 1, #BOSS_HEADER_LABELS do
        local cell = HeaderCell.Create(parent, BOSS_HEADER_LABELS[i], "CENTER")
        cell:SetFrameLevel(parent:GetFrameLevel() + 3)
        cell:EnableMouse(false)
        UI.customBossHeaders[i] = cell
    end
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

    UI.timerFrame = timerFrame
    if UI.RegisterManagedFrame then
        UI.RegisterManagedFrame("timer", timerFrame)
    end

    local pbShine = timerFrame:CreateTexture(nil, "OVERLAY")
    pbShine:SetAtlas("challenges-bannershine")
    pbShine:SetPoint("BOTTOM", timerFrame, "TOP", 0, -20)
    pbShine:SetSize(Const.PB_TOAST.SHINE_WIDTH, Const.PB_TOAST.SHINE_HEIGHT)
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

    timerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    timerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if UI.SaveFrameLayout then
            UI.SaveFrameLayout("timer", self)
        end
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
        if UI.SaveFrameLayout then
            UI.SaveFrameLayout("boss", self)
        end
    end)
    Util.ApplyResizeBounds(bossFrame, 450, Const.SPLITS_LAYOUT.MIN_HEIGHT, 1400, 1000)
    bossFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    bossFrame:SetBackdropColor(0, 0, 0, 0.9)
    bossFrame:SetBackdropBorderColor(NS.Colors.turquoise.r, NS.Colors.turquoise.g, NS.Colors.turquoise.b, 0.8)

    local ST = Util.ResolveScrollingTable()
    if not ST and NS.Print then
        NS.Print("Missing lib-st (ScrollingTable). Load lib-st before Config/Packages/main_core.xml.")
    end

    local cols = BuildBossColumns()
    UI.cols = cols
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
                local rowData = realrow and data and data[realrow] or nil

                if button == "LeftButton" and rowData and NS.TestsSimulation and NS.TestsSimulation.HandleRowClick then
                    local handled = NS.TestsSimulation.HandleRowClick(rowData, button)
                    if handled then
                        return
                    end
                end

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
                                    if NS.RunLogic and NS.RunLogic.HandleIgnoreStateChange then
                                        NS.RunLogic.HandleIgnoreStateChange()
                                    end
                                    NS.RefreshAllUI()
                                end,
                                notCheckable = true,
                            },
                        }
                        UI.bossContextMenu = UI.bossContextMenu or CreateFrame("Frame", nil, UIParent,
                            "UIDropDownMenuTemplate")
                        UIDropDownMenu_Initialize(UI.bossContextMenu, function(self, level)
                            for _, item in ipairs(menu) do
                                UIDropDownMenu_AddButton(item, level)
                            end
                        end, "MENU")
                        ToggleDropDownMenu(1, nil, UI.bossContextMenu, "cursor", 0, 0)
                    end
                end
            end,
        })

        if st.head then
            st.head:SetAlpha(0)
            st.head:Hide()
            st.head:EnableMouse(false)
        end

        local scrollLane = CreateFrame("Frame", nil, st.frame, "BackdropTemplate")
        scrollLane:EnableMouse(false)
        scrollLane:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        scrollLane:SetBackdropColor(0, 0, 0, 0.35)
        scrollLane:SetBackdropBorderColor(1, 1, 1, 0.08)
        scrollLane:Hide()
        UI.scrollLane = scrollLane

        local laneDivider = scrollLane:CreateTexture(nil, "ARTWORK")
        laneDivider:SetPoint("TOPLEFT", scrollLane, "TOPLEFT", 0, 0)
        laneDivider:SetPoint("BOTTOMLEFT", scrollLane, "BOTTOMLEFT", 0, 0)
        laneDivider:SetWidth(1)
        laneDivider:SetColorTexture(1, 1, 1, 0.12)
        scrollLane._divider = laneDivider

        if st.scrollframe then
            local scrollbar = _G[st.scrollframe:GetName() .. "ScrollBar"]
            local trough = _G[st.frame:GetName() .. "ScrollTrough"]
            local troughBorder = _G[st.frame:GetName() .. "ScrollTroughBorder"]
            if scrollbar then
                scrollbar._ssAnchorParent = scrollLane
                scrollbar._ssTrough = trough
                scrollbar._ssTroughBorder = troughBorder
            end
        end
    end

    local bgFrame = FrameFactory.CreateHeaderStrip(bossFrame, Const.SPLITS_LAYOUT.TOP_BAR_H, 0.4)
    bgFrame:SetFrameLevel(math.max(5, bossFrame:GetFrameLevel() + 2))
    bgFrame:SetClipsChildren(true)
    UI.titleTab = bgFrame

    local titleBg = bgFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    titleBg:SetPoint("TOPLEFT", bgFrame, "TOPLEFT", -200, 20)
    titleBg:SetPoint("BOTTOMRIGHT", bgFrame, "BOTTOMRIGHT", 200, -20)
    UI.titleBg = titleBg

    EnsureBossHeaderCells(bgFrame)
    UI.RestyleBossTableHeaders(1.0)

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
        18 * Const.RUN_HISTORY.HISTORY_ICON_SCALE,
        18 * Const.RUN_HISTORY.HISTORY_ICON_SCALE,
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
        if UI.SaveFrameLayout then
            UI.SaveFrameLayout("timer", timerFrame)
        end
    end)
    timerGrip:SetAlpha(0)

    local bossGrip = UI.SetupSizeGrip(bossFrame, function()
        if UI.SaveFrameLayout then
            UI.SaveFrameLayout("boss", bossFrame)
        end
        UI.ApplyTableLayout()
    end)

    bossFrame:SetScript("OnSizeChanged", function()
        UI.ApplyTableLayout()
    end)

    UI.bossFrame = bossFrame
    UI.timerTextMin = timerTextMin
    UI.timerTextSec = timerTextSec
    UI.timerTextMs = timerTextMs
    UI.data = {}
    UI.rowByBossKey = {}
    UI.timerDeltaText = timerDeltaText
    UI.resizeGrip = bossGrip
    UI._timerResizeGrip = timerGrip
    if UI.RegisterManagedFrame then
        UI.RegisterManagedFrame("boss", bossFrame)
    end

    local borderFrame = FrameFactory.CreateOverlayBorder(bossFrame, 30)
    UI.borderFrame = borderFrame

    UI.EnsureColGrips()
    if UI.ApplyAllLayouts then
        UI.ApplyAllLayouts()
    else
        UI.ApplyTableLayout()
    end
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

    if UI.customBossHeaders then
        UI.RestyleBossTableHeaders(1.0)
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
    if UI.customBossHeaders then
        UI.RestyleBossTableHeaders(1.0)
    end
end

function NS.RefreshAllUI()
    if not UI.bossFrame then
        return
    end

    NS.UpdateColorsFromSettings()
    NS.UpdateColorsOnly()
    NS.UpdateFontsOnly()
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

    UI.UpdateTimerFrameBounds()
    if NS.UpdateHistoryLayout then
        NS.UpdateHistoryLayout()
    end

    local presentation = NS.Run.presentation
    if NS.RunLogic and NS.RunLogic.BuildRunPresentation then
        presentation = NS.RunLogic.BuildRunPresentation(NS.Run, NS.Run.pbSegmentsSnapshot or {})
        NS.Run.presentation = presentation
    end
    UI.RefreshBossTableData(NS.Run.entries or {}, presentation)

    if NS.Run.entries and #NS.Run.entries > 0 then
        UI.RefreshTotals(not NS.Run.active and NS.Run.endGameTime > 0)
    end

    if not NS.Run.active and NS.Run.endGameTime > 0 then
        UI.SetTimerText(NS.Run.endGameTime - NS.Run.startGameTime, true)
    end

    if NS.DB and NS.DB.Settings then
        NS.Run.speedrunMode = NS.DB.Settings.speedrunMode or "all"
        if NS.Run.active then
            local isRunComplete, completionTime = NS.RunLogic.GetRunCompletionState(NS.Run)
            if isRunComplete then
                NS.RunLogic.StopRun(true, completionTime)
            end
        end
    end

    if UI.RefreshBossTablePresentation then
        UI.RefreshBossTablePresentation()
    end
end
