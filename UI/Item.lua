-- Item.lua
-- @Author : Dencer (tdaddon@163.com)
-- @Link   : https://dengsir.github.io
-- @Date   : 9/17/2019, 12:05:58 AM

---- LUA
local _G = _G
local select = select
local next = next
local time = time
local floor = math.floor
local format = string.format

---- WOW
local BankButtonIDToInvSlotID = BankButtonIDToInvSlotID
local CreateFrame = CreateFrame
local CursorUpdate = CursorUpdate
local GetItemInfo = GetItemInfo
local GetItemFamily = GetItemFamily
local GetItemQualityColor = GetItemQualityColor
local IsBattlePayItem = IsBattlePayItem
local ResetCursor = ResetCursor

local IsNewItem = C_NewItems.IsNewItem
local RemoveNewItem = C_NewItems.RemoveNewItem

local ContainerFrame_UpdateCooldown = ContainerFrame_UpdateCooldown
local ContainerFrameItemButton_OnEnter = ContainerFrameItemButton_OnEnter
local CooldownFrame_Set = CooldownFrame_Set
local SetItemButtonCount = SetItemButtonCount
local SetItemButtonDesaturated = SetItemButtonDesaturated
local SetItemButtonTexture = SetItemButtonTexture

---- UI
local StackSplitFrame = StackSplitFrame
local GameTooltip = GameTooltip
local UIParent = UIParent

---- G
local ITEM_STARTS_QUEST = ITEM_STARTS_QUEST
local LE_ITEM_CLASS_QUESTITEM = LE_ITEM_CLASS_QUESTITEM
local LE_ITEM_QUALITY_COMMON = LE_ITEM_QUALITY_COMMON
local LE_ITEM_QUALITY_POOR = LE_ITEM_QUALITY_POOR
local NEW_ITEM_ATLAS_BY_QUALITY = NEW_ITEM_ATLAS_BY_QUALITY
local TEXTURE_ITEM_QUEST_BANG = TEXTURE_ITEM_QUEST_BANG
local MAX_CONTAINER_ITEMS = MAX_CONTAINER_ITEMS
local MAX_BLIZZARD_ITEMS = NUM_CONTAINER_FRAMES * MAX_CONTAINER_ITEMS

---@type ns
local ns = select(2, ...)
local Addon = ns.Addon
local Cache = ns.Cache
local Search = ns.Search
local Unfit = ns.Unfit
local ItemBase = ns.UI.ItemBase
local LibJunk = LibStub('LibJunk-1.0')

local EXPIRED = GRAY_FONT_COLOR:WrapTextInColorCode(ns.L['Expired'])
local MINUTE, HOUR, DAY = 60, 3600, ns.SECONDS_OF_DAY
local DEFAULT_SLOT_COLOR = {r = 1, g = 1, b = 1}

---@class tdBag2Item: tdBag2ItemBase
---@field private meta tdBag2FrameMeta
---@field private bag number
---@field private slot number
---@field private hasItem boolean
---@field private notMatched boolean
---@field private info tdBag2CacheItemData
---@field private Overlay Frame
---@field private newitemglowAnim AnimationGroup
---@field private flashAnim AnimationGroup
---@field private Timeout FontString
local Item = ns.Addon:NewClass('UI.Item', ItemBase)
Item.pool = {}
Item.GenerateName = ns.NameGenerator('tdBag2Item')

function Item:Constructor()
    local name = self:GetName()
    self.Cooldown = _G[name .. 'Cooldown']
    self.Timeout = _G[name .. 'Stock']

    self.Cooldown:ClearAllPoints()
    self.Cooldown:SetAllPoints(true)

    self.NewItemTexture:SetTexture([[Interface\Buttons\UI-ActionButton-Border]])
    self.NewItemTexture:SetBlendMode('ADD')
    self.NewItemTexture:ClearAllPoints()
    self.NewItemTexture:SetPoint('CENTER')
    self.NewItemTexture:SetSize(67, 67)

    self.BattlepayItemTexture:Hide()

    self.nt = self:GetNormalTexture()

    self.UpdateTooltip = self.OnEnter
    self:SetScript('OnShow', self.OnShow)
    self:SetScript('OnHide', self.OnHide)
    self:SetScript('OnEnter', self.OnEnter)
    self:SetScript('OnLeave', self.OnLeave)
    self:SetScript('OnEvent', nil)
end

local index = 0
function Item:Create()
    if index < MAX_BLIZZARD_ITEMS then
        index = index + 1

        local i = floor(index / MAX_CONTAINER_ITEMS) + 1
        local j = index % MAX_CONTAINER_ITEMS + 1
        local item = _G[format('ContainerFrame%dItem%d', i, j)]
        if item then
            return Item:Bind(item, UIParent)
        end
    end
    return Item:Bind(CreateFrame('Button', Item:GenerateName(), UIParent, 'ContainerFrameItemButtonTemplate'))
end

function Item:OnHide()
    if self.hasStackSplit == 1 then
        StackSplitFrame:Hide()
    end

    if self:IsNew() then
        RemoveNewItem(self.bag, self.slot)
    end
end

function Item:Update()
    self:UpdateInfo()
    self:UpdateItem()
    self:UpdateSearch()
    self:UpdateLocked()
    self:UpdateBorder()
    self:UpdateCooldown()
    self:UpdateFocus()
    self:UpdateSlotColor()
end

function Item:UpdateLocked()
    SetItemButtonDesaturated(self, self.hasItem and (self.info.locked or self.notMatched))
end

function Item:UpdateBorder()
    local sets = self.meta.sets
    local id = self.info.id
    local quality = self.info.quality
    local new = sets.glowNew and self:IsNew()
    local r, g, b

    if id then
        if sets.glowEquipSet and Search:InSet(self.info.link) then
            r, g, b = 0.1, 1, 1
        elseif sets.glowQuest and self:IsQuestItem() then
            r, g, b = 1, 0.82, 0.2
        elseif sets.glowUnusable and Unfit:IsItemUnusable(id) then
            r, g, b = 1, 0.1, 0.1
        elseif sets.glowQuality and quality and quality > LE_ITEM_QUALITY_COMMON then
            r, g, b = GetItemQualityColor(quality)
        end
    end

    if new then
        if not self.newitemglowAnim:IsPlaying() then
            self.newitemglowAnim:Play()
            self.flashAnim:Play()
        end

        local paid = self:IsPaid()

        self.BattlepayItemTexture:SetShown(paid)
        self.NewItemTexture:SetShown(not paid)
        self.NewItemTexture:SetVertexColor(r or 1, g or 1, b or 1)
    else
        if self.newitemglowAnim:IsPlaying() or self.flashAnim:IsPlaying() then
            self.flashAnim:Stop()
            self.newitemglowAnim:Stop()
        end

        self.BattlepayItemTexture:Hide()
        self.NewItemTexture:Hide()
    end

    self.IconBorder:SetVertexColor(r, g, b, sets.glowAlpha)
    self.IconBorder:SetShown(r and not new)
    self.QuestBorder:SetShown(sets.iconQuestStarter and self:IsQuestStarter())
    self.JunkIcon:SetShown(sets.iconJunk and self:IsJunk())
end

function Item:UpdateSlotColor()
    local color = DEFAULT_SLOT_COLOR
    local alpha = self.hasItem and 1 or self.meta.sets.emptyAlpha

    if self.meta.sets.colorSlots and not self.hasItem then
        local family = self:GetBagFamily()
        local key = ns.BAG_FAMILY_KEYS[family]
        if key then
            color = self.meta.sets[key]
        else
            color = self.meta.sets.colorNormal
        end
    end

    self.nt:SetVertexColor(color.r, color.g, color.b, alpha)
    self.icon:SetVertexColor(color.r, color.g, color.b, alpha)
end

function Item:UpdateCooldown()
    if self.hasItem and not self:IsCached() then
        ContainerFrame_UpdateCooldown(self.bag, self)
    else
        -- self.Cooldown:Hide()
        CooldownFrame_Set(self.Cooldown, 0, 0, 0)
    end
end

function Item:UpdateSearch()
    local isNew = self.newitemglowAnim:IsPlaying()
    if isNew then
        self.newitemglowAnim:Stop()
        self.flashAnim:Stop()
    end

    ItemBase.UpdateSearch(self)

    if isNew then
        self.newitemglowAnim:Play()
    end
end

function Item:IsNew()
    return self.bag and ns.IsContainerBag(self.bag) and not self:IsCached() and IsNewItem(self.bag, self.slot)
end

function Item:IsPaid()
    return IsBattlePayItem(self.bag, self.slot)
end
