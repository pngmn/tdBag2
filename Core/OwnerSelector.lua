-- OwnerSelector.lua
-- @Author : Dencer (tdaddon@163.com)
-- @Link   : https://dengsir.github.io
-- @Date   : 10/18/2019, 10:26:06 AM

---- LUA
local tinsert = table.insert
local select = select

---- WOW
local CreateFrame = CreateFrame
local EasyMenu_Initialize = EasyMenu_Initialize
local HideDropDownMenu = HideDropDownMenu
local ToggleDropDownMenu = ToggleDropDownMenu

---- UI
local GameTooltip = GameTooltip
local UIParent = UIParent

---- G
local CHARACTER = CHARACTER
local DELETE = DELETE

---@type ns
local ns = select(2, ...)
local L = ns.L
local Addon = ns.Addon
local Cache = ns.Cache

---@class tdBag2OwnerSelector: Button
---@field private meta tdBag2FrameMeta
local OwnerSelector = ns.Addon:NewClass('UI.OwnerSelector', 'Button')

function OwnerSelector:Constructor(_, meta)
    self.meta = meta
    self:SetScript('OnClick', self.OnClick)
    self:SetScript('OnEnter', self.OnEnter)
    self:SetScript('OnLeave', self.OnLeave)
    self:SetScript('OnShow', self.Update)
end

function OwnerSelector:OnClick(button)
    if button == 'RightButton' then
        Addon:SetOwner(self.meta.bagId, nil)
    else
        self:OnLeave()
        ToggleDropDownMenu(1, nil, self:GetDropMenu(), self, 8, 0, self:CreateMenu())
    end
end

function OwnerSelector:OnEnter()
    ns.AnchorTooltip(self)
    GameTooltip:SetText(CHARACTER)
    GameTooltip:AddLine(ns.LeftButtonTip(L.TOOLTIP_CHANGE_PLAYER))
    GameTooltip:AddLine(ns.RightButtonTip(L.TOOLTIP_RETURN_TO_SELF))
    GameTooltip:Show()
end

function OwnerSelector:OnLeave()
    GameTooltip:Hide()
end

function OwnerSelector:Update()
    if not self:HasMultiOwners() then
        self:Hide()
    end
end

function OwnerSelector:HasMultiOwners()
    local iter = Cache:IterateOwners()
    return iter() and iter()
end

function OwnerSelector:GetDropMenu()
    if not self.DropMenu then
        local frame = CreateFrame('Frame', 'tdBag2OwnerDropMenuFrame', UIParent, 'UIDropDownMenuTemplate')
        frame.displayMode = 'MENU'
        frame.initialize = EasyMenu_Initialize
        OwnerSelector.DropMenu = frame
    end
    return self.DropMenu
end

function OwnerSelector:CreateMenu()
    local menuList = {self:CreateOwnerMenu()}
    for name in Cache:IterateOwners() do
        if not ns.IsSelf(name) then
            tinsert(menuList, self:CreateOwnerMenu(name))
        end
    end
    return menuList
end

function OwnerSelector:CreateOwnerMenu(name)
    local info = Cache:GetOwnerInfo(name)
    local isSelf = not name
    local isCurrent = name == self.meta.owner
    local hasArrow = not isSelf and not isCurrent

    return {
        text = ns.GetOwnerColoredName(info),
        checked = isCurrent,
        hasArrow = hasArrow,
        menuList = hasArrow and {
            {
                notCheckable = true,
                text = DELETE,
                func = function()
                    Cache:DeleteOwnerInfo(name)
                    HideDropDownMenu(1)
                end,
            },
        },
        func = function()
            Addon:SetOwner(self.meta.bagId, not isSelf and name or nil)
        end,
    }
end
