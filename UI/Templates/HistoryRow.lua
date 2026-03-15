local _, NS = ...

NS.UI = NS.UI or {}
NS.UI.Templates = NS.UI.Templates or {}

local HistoryRow = {}
NS.UI.Templates.HistoryRow = HistoryRow

function HistoryRow.Create(parent, onDelete)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(24)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(0, 0, 0, 0)
    row.cols = {}

    for i = 1, 8 do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetHeight(24)
        if NS.Colors and NS.Colors.white then
            fs:SetTextColor(NS.Colors.white.r, NS.Colors.white.g, NS.Colors.white.b, NS.Colors.white.a or 1)
        end
        row.cols[i] = fs
        if i == 8 then
            local btn = CreateFrame("Button", nil, row)
            btn:SetSize(20, 20)
            btn:SetPoint("CENTER", fs, "CENTER")
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetAtlas("common-icon-delete")
            tex:SetVertexColor(0.8, 0.2, 0.2)
            tex:SetAllPoints()
            btn:SetNormalTexture(tex)
            btn:SetHighlightAtlas("common-icon-delete")
            btn:GetHighlightTexture():SetAlpha(0.4)
            btn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Delete", 1, 0, 0)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            btn:SetScript("OnClick", function(self)
                if self.record and onDelete then
                    onDelete(self.record)
                end
            end)
            row.delBtn = btn
        else
            fs:SetWordWrap(false)
            if fs.SetTextTruncate then
                fs:SetTextTruncate("REPLACE")
            end
        end
    end

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.03)

    return row
end
