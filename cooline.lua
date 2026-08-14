-- Cooline 1.9.5

local VERSION = GetAddOnMetadata("Cooline", "Version") or "Unknown"

local DEFAULTS = {
	length = 360,
	width = 18,
	iconoversize = 4,
	style = "classic",
	x = 0,
	y = -240,
	vertical = false,
	reverse = false,
	inactivealpha = 0.5,
	activealpha = 1.0,
	cooldownanimate = 150,
}

local STYLE_PRESETS = {
	classic = {
		name = "Classic",
		barTexture = [[Interface\TargetingFrame\UI-StatusBar]],
		barColor = { 0, 0, 0, 0.5 },
		borderTexture = [[Interface\DialogFrame\UI-DialogBox-Border]],
		borderSize = 16,
		borderInset = 4,
		borderColor = { 1, 1, 1, 1 },
	},
	flat = {
		name = "Flat",
		barTexture = [[Interface\Tooltips\UI-Tooltip-Background]],
		barColor = { 0.10, 0.10, 0.10, 0.85 },
		borderTexture = [[Interface\Tooltips\UI-Tooltip-Border]],
		borderSize = 10,
		borderInset = 2,
		borderColor = { 0.55, 0.55, 0.55, 1 },
	},
	dark = {
		name = "Dark",
		barTexture = [[Interface\TargetingFrame\UI-StatusBar]],
		barColor = { 0.02, 0.02, 0.02, 0.90 },
		borderTexture = [[Interface\Tooltips\UI-Tooltip-Border]],
		borderSize = 10,
		borderInset = 2,
		borderColor = { 0.20, 0.20, 0.20, 1 },
	},
	borderless = {
		name = "Borderless",
		barTexture = [[Interface\TargetingFrame\UI-StatusBar]],
		barColor = { 0, 0, 0, 0.65 },
		borderTexture = [[Interface\Tooltips\UI-Tooltip-Border]],
		borderSize = 8,
		borderInset = 0,
		borderColor = { 0, 0, 0, 0 },
	},
}


local bar = CreateFrame("Frame", "CoolineBar", UIParent)
local cooldowns = {}
local initialised = false
local ToggleOptions
local ApplyBarLockState
local UpdateMinimapButton
local pendingItemUse
local itemCooldownLocks = {}
local ITEM_INTENT_WINDOW = 1.0

local function CapturePendingItem(name, texture)
	if not name or name == "" then
		return
	end

	pendingItemUse = {
		name = name,
		texture = texture,
		time = GetTime(),
	}
end

local scanElapsed = 0
local SCAN_INTERVAL = 0.50
local visuals
local GetSpellCount

local function ApplyDefaults(target, defaults)
	local k, v
	for k, v in pairs(defaults) do
		if target[k] == nil then
			target[k] = v
		end
	end
end

local function InitialiseSettings()
	CoolineDB = CoolineDB or {}
	CoolineDB.visuals = CoolineDB.visuals or {}

	if CoolineDB.showMinimapButton == nil then
		CoolineDB.showMinimapButton = true
	end
	if CoolineDB.minimapX == nil then
		CoolineDB.minimapX = -78
	end
	if CoolineDB.minimapY == nil then
		CoolineDB.minimapY = 0
	end

	-- Migrate early 1.9.1 width/height settings to length/width.
	if CoolineDB.visuals.length == nil and CoolineDB.visuals.height ~= nil then
		if CoolineDB.visuals.vertical then
			CoolineDB.visuals.length = CoolineDB.visuals.height
		else
			CoolineDB.visuals.length = CoolineDB.visuals.width
			CoolineDB.visuals.width = CoolineDB.visuals.height
		end
		CoolineDB.visuals.height = nil
	end

	ApplyDefaults(CoolineDB.visuals, DEFAULTS)

	CoolineCharDB = CoolineCharDB or {}
	if CoolineCharDB.useCharacterVisuals == nil then
		CoolineCharDB.useCharacterVisuals = false
	end

	if CoolineCharDB.locked == nil then
		CoolineCharDB.locked = false
	end

	CoolineCharDB.filters = CoolineCharDB.filters or {}
	if CoolineCharDB.filters.mode == nil then
		CoolineCharDB.filters.mode = "blacklist"
	end
	if CoolineCharDB.filters.blacklist == nil then
		CoolineCharDB.filters.blacklist = {}
	end
	if CoolineCharDB.filters.whitelist == nil then
		CoolineCharDB.filters.whitelist = {}
	end

	CoolineCharDB.itemFilters = CoolineCharDB.itemFilters or {}
	if CoolineCharDB.itemFilters.mode == nil then
		CoolineCharDB.itemFilters.mode = "blacklist"
	end
	if CoolineCharDB.itemFilters.blacklist == nil then
		CoolineCharDB.itemFilters.blacklist = {}
	end
	if CoolineCharDB.itemFilters.whitelist == nil then
		CoolineCharDB.itemFilters.whitelist = {}
	end

	if CoolineCharDB.spellIconOverride == nil then
		CoolineCharDB.spellIconOverride = false
	end
	if CoolineCharDB.itemIconOverride == nil then
		CoolineCharDB.itemIconOverride = false
	end

	if CoolineCharDB.useCharacterVisuals then
		CoolineCharDB.visuals = CoolineCharDB.visuals or {}

		if CoolineCharDB.visuals.length == nil and CoolineCharDB.visuals.height ~= nil then
			if CoolineCharDB.visuals.vertical then
				CoolineCharDB.visuals.length = CoolineCharDB.visuals.height
			else
				CoolineCharDB.visuals.length = CoolineCharDB.visuals.width
				CoolineCharDB.visuals.width = CoolineCharDB.visuals.height
			end
			CoolineCharDB.visuals.height = nil
		end

		ApplyDefaults(CoolineCharDB.visuals, CoolineDB.visuals)
		visuals = CoolineCharDB.visuals
	else
		visuals = CoolineDB.visuals
	end
end

local function SelectVisualScope(useCharacter)
	if useCharacter then
		if not CoolineCharDB.visuals then
			CoolineCharDB.visuals = {}
			ApplyDefaults(CoolineCharDB.visuals, CoolineDB.visuals)
		end
		ApplyDefaults(CoolineCharDB.visuals, DEFAULTS)
		CoolineCharDB.useCharacterVisuals = true
		visuals = CoolineCharDB.visuals
	else
		CoolineCharDB.useCharacterVisuals = false
		visuals = CoolineDB.visuals
	end
end


local function Trim(text)
	if not text then return "" end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	return text
end

local function ListContainsSpell(list, name)
	local i, entry

	if not list or not name then return false end

	for i, entry in ipairs(list) do
		if type(entry) == "string" and strupper(entry) == strupper(name) then
			return true
		end
	end

	return false
end

local function SpellAllowed(name)
	local filters = CoolineCharDB.filters

	if filters.mode == "whitelist" then
		return ListContainsSpell(filters.whitelist, name)
	end

	return not ListContainsSpell(filters.blacklist, name)
end

local function GetActiveFilterList()
	if CoolineCharDB.filters.mode == "whitelist" then
		return CoolineCharDB.filters.whitelist
	end

	return CoolineCharDB.filters.blacklist
end

local function ResolveSpellNameAndIcon(typedName)
	local count = GetSpellCount and GetSpellCount() or 0
	local i
	local name
	local texture
	local resolvedName

	-- Highest learned rank wins because spellbook entries are scanned in order.
	-- We keep updating the match so the final result is the highest learned rank.
	for i = 1, count do
		name = GetSpellName(i, BOOKTYPE_SPELL)
		if name and strupper(name) == strupper(typedName) then
			resolvedName = name
			texture = GetSpellTexture(i, BOOKTYPE_SPELL)
		end
	end

	return resolvedName, texture
end


local function ItemAllowed(name)
	local filters = CoolineCharDB.itemFilters

	if filters.mode == "whitelist" then
		return ListContainsSpell(filters.whitelist, name)
	end

	return not ListContainsSpell(filters.blacklist, name)
end

local function GetActiveItemFilterList()
	if CoolineCharDB.itemFilters.mode == "whitelist" then
		return CoolineCharDB.itemFilters.whitelist
	end

	return CoolineCharDB.itemFilters.blacklist
end

local function SafeItemName(link)
	local _, _, name

	if not link or type(link) ~= "string" then
		return nil
	end

	_, _, name = strfind(link, "|h%[([^]]+)%]|h")
	return name
end

local OriginalUseContainerItem = UseContainerItem
if OriginalUseContainerItem then
	UseContainerItem = function(bag, slot, onSelf)
		local link = GetContainerItemLink(bag, slot)
		local name = SafeItemName(link)
		local texture = GetContainerItemInfo(bag, slot)

		if name then
			CapturePendingItem(name, texture)
		end

		return OriginalUseContainerItem(bag, slot, onSelf)
	end
end

local OriginalUseInventoryItem = UseInventoryItem
if OriginalUseInventoryItem then
	UseInventoryItem = function(slot)
		local link = GetInventoryItemLink("player", slot)
		local name = SafeItemName(link)
		local texture = GetInventoryItemTexture("player", slot)

		if name then
			CapturePendingItem(name, texture)
		end

		return OriginalUseInventoryItem(slot)
	end
end



local function GetStylePreset()
	return STYLE_PRESETS[visuals.style] or STYLE_PRESETS.classic
end

local function ApplyBarStyle()
	local style

	if not bar.bg or not bar.border then
		return
	end

	style = GetStylePreset()

	bar.bg:SetTexture(style.barTexture)
	bar.bg:SetVertexColor(unpack(style.barColor))

	bar.border:ClearAllPoints()
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -style.borderInset, style.borderInset)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", style.borderInset, -style.borderInset)
	bar.border:SetBackdrop({
		edgeFile = style.borderTexture,
		edgeSize = style.borderSize,
	})
	bar.border:SetBackdropBorderColor(unpack(style.borderColor))
end

local function GetIconOversizeForKey(key)
	if string.sub(key, 1, 6) == "spell:" and CoolineCharDB.spellIconOverride then
		return CoolineCharDB.spellIconOversize or visuals.iconoversize
	elseif string.sub(key, 1, 5) == "item:" and CoolineCharDB.itemIconOverride then
		return CoolineCharDB.itemIconOversize or visuals.iconoversize
	end

	return visuals.iconoversize
end

local function GetIconSizeForKey(key)
	return max(2, visuals.width + GetIconOversizeForKey(key))
end

local function TimelineOffset(timeLeft)
	local span = visuals.length
	local section = span / 6

	if timeLeft <= 0 then
		return 0
	elseif timeLeft < 1 then
		return section * timeLeft
	elseif timeLeft < 3 then
		return section * (1 + ((timeLeft - 1) / 2))
	elseif timeLeft < 10 then
		return section * (2 + ((timeLeft - 3) / 7))
	elseif timeLeft < 30 then
		return section * (3 + ((timeLeft - 10) / 20))
	elseif timeLeft < 120 then
		return section * (4 + ((timeLeft - 30) / 90))
	elseif timeLeft < 360 then
		return section * (5 + ((timeLeft - 120) / 240))
	end

	return span
end
local function PlaceOnTimeline(frame, offset)
	frame:ClearAllPoints()

	if visuals.vertical then
		if visuals.reverse then
			frame:SetPoint("CENTER", bar, "BOTTOM", 0, visuals.length - offset)
		else
			frame:SetPoint("CENTER", bar, "BOTTOM", 0, offset)
		end
	else
		if visuals.reverse then
			frame:SetPoint("CENTER", bar, "LEFT", visuals.length - offset, 0)
		else
			frame:SetPoint("CENTER", bar, "LEFT", offset, 0)
		end
	end
end

local function LayoutLabels()
	local span = visuals.length
	local section = span / 6
	local i
	local data
	local offset

	for i, data in ipairs(bar.labels) do
		offset = data.offset * section
		data.frame:ClearAllPoints()

		if visuals.vertical then
			if data.edge == "START" then
				if visuals.reverse then
					data.frame:SetPoint("TOP", bar, "TOP", 0, -1)
				else
					data.frame:SetPoint("BOTTOM", bar, "BOTTOM", 0, 1)
				end
			elseif data.edge == "END" then
				if visuals.reverse then
					data.frame:SetPoint("BOTTOM", bar, "BOTTOM", 0, 1)
				else
					data.frame:SetPoint("TOP", bar, "TOP", 0, -1)
				end
			else
				if visuals.reverse then
					data.frame:SetPoint("CENTER", bar, "BOTTOM", 0, visuals.length - offset)
				else
					data.frame:SetPoint("CENTER", bar, "BOTTOM", 0, offset)
				end
			end
		else
			if data.edge == "START" then
				if visuals.reverse then
					data.frame:SetPoint("RIGHT", bar, "RIGHT", -1, 0)
				else
					data.frame:SetPoint("LEFT", bar, "LEFT", 1, 0)
				end
			elseif data.edge == "END" then
				if visuals.reverse then
					data.frame:SetPoint("LEFT", bar, "LEFT", 1, 0)
				else
					data.frame:SetPoint("RIGHT", bar, "RIGHT", -1, 0)
				end
			else
				if visuals.reverse then
					data.frame:SetPoint("CENTER", bar, "LEFT", visuals.length - offset, 0)
				else
					data.frame:SetPoint("CENTER", bar, "LEFT", offset, 0)
				end
			end
		end
	end
end

local function ApplyVisualLayout()
	local name, cd

	bar:ClearAllPoints()
	bar:SetPoint("CENTER", UIParent, "CENTER", visuals.x, visuals.y)

	if visuals.vertical then
		bar:SetWidth(visuals.width)
		bar:SetHeight(visuals.length)
		bar.bg:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	else
		bar:SetWidth(visuals.length)
		bar:SetHeight(visuals.width)
		bar.bg:SetTexCoord(0, 1, 0, 1)
	end

	ApplyBarStyle()

	for name, cd in pairs(cooldowns) do
		local size = GetIconSizeForKey(name)
		cd:SetWidth(size)
		cd:SetHeight(size)
	end

	LayoutLabels()
end

local function UpdateBarAlpha(active)
	local alpha
	local i

	if active then
		alpha = visuals.activealpha
	else
		alpha = visuals.inactivealpha
	end

	-- Keep the root frame fully active for mouse handling and explicitly
	-- control every visible component. Vanilla can be inconsistent about
	-- inherited alpha on children created after the parent alpha was set.
	bar:SetAlpha(1)

	if bar.bg then
		bar.bg:SetAlpha(alpha)
	end

	-- Cooldown icons are children of bar.border, so this controls the border
	-- and all active cooldown frames together.
	if bar.border then
		bar.border:SetAlpha(alpha)
	end

	if bar.labels then
		for i = 1, table.getn(bar.labels) do
			if bar.labels[i] and bar.labels[i].frame then
				bar.labels[i].frame:SetAlpha(alpha)
			end
		end
	end
end


local minimapButton

local function PositionMinimapButton()
	if not minimapButton then
		return
	end

	minimapButton:ClearAllPoints()
	minimapButton:SetPoint(
		"CENTER",
		Minimap,
		"CENTER",
		CoolineDB.minimapX or -78,
		CoolineDB.minimapY or 0
	)
end

UpdateMinimapButton = function()
	if not minimapButton then
		return
	end

	if CoolineDB.showMinimapButton then
		minimapButton:Show()
	else
		minimapButton:Hide()
	end
end

ApplyBarLockState = function()
	if not bar.clickOverlay then
		return
	end

	if CoolineCharDB.locked then
		bar.clickOverlay:Hide()
		bar.clickOverlay:EnableMouse(false)
	else
		bar.clickOverlay:Show()
		bar.clickOverlay:EnableMouse(true)
	end

	if optionsFrame and optionsFrame.lockBar then
		optionsFrame.updating = true
		optionsFrame.lockBar:SetChecked(CoolineCharDB.locked and 1 or nil)
		optionsFrame.updating = false
	end
end

local function BuildMinimapButton()
	local icon
	local border

	if minimapButton then
		return
	end

	minimapButton = CreateFrame("Button", "CoolineMinimapButton", Minimap)
	minimapButton:SetWidth(31)
	minimapButton:SetHeight(31)
	minimapButton:SetFrameStrata("MEDIUM")
	minimapButton:SetMovable(true)
	minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	minimapButton:RegisterForDrag("LeftButton")

	icon = minimapButton:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(20)
	icon:SetHeight(20)
	icon:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
	icon:SetTexture([[Interface\Icons\INV_Qiraj_JewelGlyphed]])
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	minimapButton.icon = icon

	border = minimapButton:CreateTexture(nil, "OVERLAY")
	border:SetWidth(53)
	border:SetHeight(53)
	border:SetPoint("TOPLEFT", minimapButton, "TOPLEFT", 0, 0)
	border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
	minimapButton.border = border

	minimapButton:SetHighlightTexture(
		[[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]]
	)

	minimapButton:SetScript("OnClick", function()
		if arg1 == "RightButton" then
			CoolineCharDB.locked = not CoolineCharDB.locked
			ApplyBarLockState()
		else
			ToggleOptions()
		end
	end)

	minimapButton:SetScript("OnDragStart", function()
		this:StartMoving()
	end)

	minimapButton:SetScript("OnDragStop", function()
		local x, y
		local mx, my

		this:StopMovingOrSizing()

		x, y = this:GetCenter()
		mx, my = Minimap:GetCenter()

		if x and y and mx and my then
			CoolineDB.minimapX = floor((x - mx) + 0.5)
			CoolineDB.minimapY = floor((y - my) + 0.5)
		end
	end)

	minimapButton:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:AddLine("Cooline", 1, 0.82, 0)
		GameTooltip:AddLine("Left-click: Options", 1, 1, 1)
		GameTooltip:AddLine("Right-click: Lock / Unlock", 1, 1, 1)
		GameTooltip:AddLine("Drag: Move button", 1, 1, 1)
		GameTooltip:Show()
	end)

	minimapButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	PositionMinimapButton()
	UpdateMinimapButton()
end

local function BuildBar()
	local s = visuals
	local labels = {
		{ text = "0", offset = 0, edge = "START" },
		{ text = "1", offset = 1 },
		{ text = "3", offset = 2 },
		{ text = "10", offset = 3 },
		{ text = "30", offset = 4 },
		{ text = "2m", offset = 5 },
		{ text = "6m", offset = 6, edge = "END" },
	}
	local i, data, fs

	if s.vertical then
		bar:SetWidth(s.width)
		bar:SetHeight(s.length)
	else
		bar:SetWidth(s.length)
		bar:SetHeight(s.width)
	end
	bar:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
	bar:SetMovable(true)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)

	bar.border = CreateFrame("Frame", nil, bar)

	bar.labels = {}

	for i, data in ipairs(labels) do
		fs = bar:CreateFontString(nil, "OVERLAY")
		fs:SetFont([[Fonts\FRIZQT__.TTF]], 10)
		fs:SetTextColor(1, 1, 1, 0.8)
		fs:SetShadowColor(0, 0, 0, 0.5)
		fs:SetShadowOffset(1, -1)
		fs:SetText(data.text)
		fs:SetWidth(30)
		fs:SetHeight(12)
		fs:SetJustifyH("CENTER")

		data.frame = fs
		bar.labels[i] = data
	end

	ApplyVisualLayout()

	bar.clickOverlay = CreateFrame("Button", nil, bar)
	bar.clickOverlay:SetAllPoints(bar)
	bar.clickOverlay:SetFrameLevel(30)
	bar.clickOverlay:RegisterForDrag("LeftButton")

	bar.clickOverlay:SetScript("OnMouseUp", function()
		if arg1 == "RightButton" and ToggleOptions then
			ToggleOptions()
		end
	end)

	bar.clickOverlay:SetScript("OnDragStart", function()
		if IsAltKeyDown() then
			bar:StartMoving()
		end
	end)

	bar.clickOverlay:SetScript("OnDragStop", function()
		local x, y, ux, uy

		bar:StopMovingOrSizing()
		x, y = bar:GetCenter()
		ux, uy = UIParent:GetCenter()

		if x and y and ux and uy then
			visuals.x = floor(x - ux + 0.5)
			visuals.y = floor(y - uy + 0.5)
		end
	end)

	UpdateBarAlpha(false)
	ApplyBarLockState()

	initialised = true
end

GetSpellCount = function()
	local tabs = GetNumSpellTabs() or 0
	local i
	local _, _, offset, num
	local highest = 0

	for i = 1, tabs do
		_, _, offset, num = GetSpellTabInfo(i)
		if offset and num and offset + num > highest then
			highest = offset + num
		end
	end

	return highest
end

local function EnsureCooldown(key)
	local cd = cooldowns[key]
	local size

	if not cd then
		cd = CreateFrame("Frame", nil, bar.border)
		size = GetIconSizeForKey(key)
		cd:SetWidth(size)
		cd:SetHeight(size)
		cd:SetBackdrop({
			bgFile = [[Interface\AddOns\Cooline\artwork\backdrop.tga]]
		})
		cd:SetBackdropColor(0.8, 0.4, 0, 1)

		cd.icon = cd:CreateTexture(nil, "ARTWORK")
		cd.icon:SetPoint("TOPLEFT", cd, "TOPLEFT", 1, -1)
		cd.icon:SetPoint("BOTTOMRIGHT", cd, "BOTTOMRIGHT", -1, 1)
		cd.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

		cooldowns[key] = cd
	end

	return cd
end

local function ScanItems(seen)
	local candidates = {}
	local now = GetTime()
	local bag, slot, slots
	local startTime, duration, enabled
	local link, name, texture
	local i, candidate
	local signature
	local key
	local lockedName

	local function AddCandidate(itemName, itemTexture, startValue, durationValue)
		if not itemName or not ItemAllowed(itemName) then
			return
		end

		signature = tostring(floor((startValue or 0) * 10 + 0.5)) .. ":" ..
		            tostring(floor((durationValue or 0) * 10 + 0.5))

		candidates[table.getn(candidates) + 1] = {
			name = itemName,
			texture = itemTexture,
			startTime = startValue,
			duration = durationValue,
			endTime = startValue + durationValue,
			signature = signature,
		}

	end

	-- Bags.
	for bag = 0, 4 do
		slots = GetContainerNumSlots(bag) or 0

		for slot = 1, slots do
			startTime, duration, enabled = GetContainerItemCooldown(bag, slot)

			if enabled == 1 and duration and duration > 2.5 and (startTime + duration) > now then
				link = GetContainerItemLink(bag, slot)
				name = SafeItemName(link)

				if name then
					texture = GetContainerItemInfo(bag, slot)
					AddCandidate(name, texture, startTime, duration)
				end
			end
		end
	end

	-- Equipped items.
	for slot = 0, 19 do
		startTime, duration, enabled = GetInventoryItemCooldown("player", slot)

		if enabled == 1 and duration and duration > 2.5 and (startTime + duration) > now then
			link = GetInventoryItemLink("player", slot)
			name = SafeItemName(link)

			if name then
				texture = GetInventoryItemTexture("player", slot)
				AddCandidate(name, texture, startTime, duration)
			end
		end
	end

	-- Highest priority: exact Vanilla use intent captured before cooldown begins.
	if pendingItemUse and (now - pendingItemUse.time) <= ITEM_INTENT_WINDOW then
		for i = 1, table.getn(candidates) do
			candidate = candidates[i]

			if strupper(candidate.name) == strupper(pendingItemUse.name) then
				itemCooldownLocks[candidate.signature] = pendingItemUse.name

				key = "item:" .. pendingItemUse.name
				local cd = EnsureCooldown(key)
				cd.startTime = candidate.startTime
				cd.duration = candidate.duration
				cd.endTime = candidate.endTime
				cd.icon:SetTexture(pendingItemUse.texture or candidate.texture)
				cd:SetBackdropColor(0, 0, 0, 1)
				cd:Show()
				seen[key] = true

				pendingItemUse = nil
				break
			end
		end
	end

	if pendingItemUse and (now - pendingItemUse.time) > ITEM_INTENT_WINDOW then
		pendingItemUse = nil
	end

	-- Preserve locked identities. Shared cooldown candidates may update timing,
	-- but they never replace the locked name/icon.
	for i = 1, table.getn(candidates) do
		candidate = candidates[i]
		lockedName = itemCooldownLocks[candidate.signature]

		if lockedName then
			key = "item:" .. lockedName

			if not seen[key] then
				local cd = cooldowns[key]

				if cd and cd.endTime then
					cd.startTime = candidate.startTime
					cd.duration = candidate.duration
					cd.endTime = candidate.endTime
					cd:Show()
					seen[key] = true
				end
			end
		end
	end

	-- Fallback for uses we could not directly capture:
	-- choose exactly one representative for a new cooldown signature, then lock it.
	for i = 1, table.getn(candidates) do
		candidate = candidates[i]

		if not itemCooldownLocks[candidate.signature] then
			itemCooldownLocks[candidate.signature] = candidate.name

			key = "item:" .. candidate.name
			local cd = EnsureCooldown(key)
			cd.startTime = candidate.startTime
			cd.duration = candidate.duration
			cd.endTime = candidate.endTime
			cd.icon:SetTexture(candidate.texture)
			cd:SetBackdropColor(0, 0, 0, 1)
			cd:Show()
			seen[key] = true

			-- Do not create another fallback identity for the same shared cooldown.
		end
	end

	-- Remove locks once their cooldown signature has disappeared entirely.
	local activeSignatures = {}
	for i = 1, table.getn(candidates) do
		activeSignatures[candidates[i].signature] = true
	end

	for signature, lockedName in pairs(itemCooldownLocks) do
		if not activeSignatures[signature] then
			itemCooldownLocks[signature] = nil
		end
	end
end

local function CooldownKeyAllowed(key)
	local prefix
	local name

	if not key then
		return false
	end

	prefix = string.sub(key, 1, 6)
	if prefix == "spell:" then
		name = string.sub(key, 7)
		return SpellAllowed(name)
	end

	if string.sub(key, 1, 5) == "item:" then
		name = string.sub(key, 6)
		return ItemAllowed(name)
	end

	return true
end

local function ReconcileAllCooldowns()
	local seen = {}
	local name, cd
	local now = GetTime()

	-- Re-scan spells into the same active set.
	local spellCount = GetSpellCount()
	local id
	local spellName
	local startTime, duration, enabled
	local texture
	local key

	for id = 1, spellCount do
		spellName = GetSpellName(id, BOOKTYPE_SPELL)

		if spellName then
			startTime, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)

			if SpellAllowed(spellName) and enabled == 1 and duration and duration > 2.5 then
				if (startTime + duration) > now then
					key = "spell:" .. spellName
					cd = EnsureCooldown(key)
					texture = GetSpellTexture(id, BOOKTYPE_SPELL)

					cd.startTime = startTime
					cd.duration = duration
					cd.endTime = startTime + duration
					cd.icon:SetTexture(texture)
					cd:SetBackdropColor(0.8, 0.4, 0, 1)
					cd:Show()
					seen[key] = true
				end
			end
		end
	end

	ScanItems(seen)

	for name, cd in pairs(cooldowns) do
		if not CooldownKeyAllowed(name) then
			cd:Hide()
			cd.endTime = nil
			cd.pulseStart = nil
		elseif not seen[name] and (not cd.endTime or cd.endTime <= now) then
			cd:Hide()
			cd.endTime = nil
			cd.pulseStart = nil
		end
	end
end

local COOLDOWN_PULSE_DURATION = 0.26

local function TriggerCooldownPulse(spellName)
	local cd
	local key
	local name, candidate
	local now

	if not spellName or not visuals or not visuals.cooldownanimate then
		return
	end

	if visuals.cooldownanimate == 100 then
		return
	end

	key = "spell:" .. spellName
	cd = cooldowns[key]

	if not cd then
		for name, candidate in pairs(cooldowns) do
			if string.sub(name, 1, 6) == "spell:" and
			   strupper(string.sub(name, 7)) == strupper(spellName) then
				cd = candidate
				break
			end
		end
	end

	now = GetTime()

	if cd and cd.endTime and cd.endTime > now then
		-- Every failed cast restarts the pulse.
		cd.pulseStart = now
	end
end

local function Render()
	local now = GetTime()
	local anyActive = false
	local name, cd
	local remaining
	local offset
	local level = 2
	local baseSize
	local drawSize
	local progress
	local pulse
	local targetScale

	for name, cd in pairs(cooldowns) do
		if cd.endTime then
			remaining = cd.endTime - now

			if remaining > 0 then
				anyActive = true
				offset = TimelineOffset(remaining)

				cd:SetFrameLevel(level)
				level = level + 1

				baseSize = GetIconSizeForKey(name)
				drawSize = baseSize

				if cd.pulseStart then
					progress = (now - cd.pulseStart) / COOLDOWN_PULSE_DURATION

					if progress >= 1 then
						cd.pulseStart = nil
					elseif progress >= 0 then
						-- Smooth triangle: normal -> selected scale -> normal.
						if progress < 0.5 then
							pulse = progress * 2
						else
							pulse = (1 - progress) * 2
						end

						targetScale = visuals.cooldownanimate / 100
						drawSize = baseSize * (1 + ((targetScale - 1) * pulse))
					end
				end

				-- Only protect the frame API from invalid dimensions.
				if drawSize < 1 then
					drawSize = 1
				end

				cd:SetWidth(drawSize)
				cd:SetHeight(drawSize)
				PlaceOnTimeline(cd, offset)
				cd:SetAlpha(1)
				cd:Show()
			else
				cd:Hide()
				cd.endTime = nil
				cd.pulseStart = nil
			end
		end
	end

	UpdateBarAlpha(anyActive)
end


-- ============================================================================
-- Options
-- ============================================================================

local optionsFrame
local RefreshAppearanceOptions
local sliderCount = 0
local SPELL_ROW_HEIGHT = 28
local SPELL_VISIBLE_ROWS = 7
local ITEM_VISIBLE_ROWS = 7

local function MakeText(parent, text, x, y, size, title)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fs:SetFont([[Fonts\FRIZQT__.TTF]], size or 11)
	if title then
		fs:SetTextColor(1, 0.82, 0)
	else
		fs:SetTextColor(0.9, 0.9, 0.9)
	end
	fs:SetText(text or "")
	return fs
end

local function MakeButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetWidth(width)
	button:SetHeight(22)
	button:SetText(text)
	return button
end

local function MakeBinarySlider(parent, leftText, rightText, x, y, width)
	local slider
	local left
	local right
	local name

	sliderCount = sliderCount + 1
	name = "CoolineBinarySlider" .. sliderCount

	slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	slider:SetWidth(width)
	slider:SetHeight(16)
	slider:SetMinMaxValues(0, 1)
	slider:SetValueStep(1)

	getglobal(name .. "Text"):SetText("")
	getglobal(name .. "Low"):SetText("")
	getglobal(name .. "High"):SetText("")

	left = parent:CreateFontString(nil, "OVERLAY")
	left:SetPoint("RIGHT", slider, "LEFT", -12, 0)
	left:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	left:SetTextColor(0.9, 0.9, 0.9)
	left:SetText(leftText)

	right = parent:CreateFontString(nil, "OVERLAY")
	right:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	right:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	right:SetTextColor(0.9, 0.9, 0.9)
	right:SetText(rightText)

	return slider
end


local function MakeCheckbox(parent, text, x, y)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	local label

	check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	check:SetWidth(24)
	check:SetHeight(24)

	label = check:CreateFontString(nil, "OVERLAY")
	label:SetPoint("LEFT", check, "RIGHT", 2, 1)
	label:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	label:SetTextColor(0.9, 0.9, 0.9)
	label:SetText(text)
	check.label = label

	return check
end

local function MakeEditBox(parent, x, y, width)
	local edit = CreateFrame("EditBox", nil, parent)

	edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	edit:SetWidth(width)
	edit:SetHeight(20)
	edit:SetAutoFocus(false)
	edit:SetFontObject(GameFontHighlightSmall)
	edit:SetJustifyH("CENTER")

	edit:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 8,
		edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	edit:SetBackdropColor(0, 0, 0, 0.85)
	edit:SetBackdropBorderColor(0.45, 0.52, 0.60, 1)

	return edit
end

local function MakeValueSlider(parent, label, x, y, width, low, high, step)
	local slider
	local name

	sliderCount = sliderCount + 1
	name = "CoolineValueSlider" .. sliderCount

	MakeText(parent, label, x, y, 11, false)

	slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 24)
	slider:SetWidth(width)
	slider:SetHeight(16)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)

	getglobal(name .. "Text"):SetText("")
	getglobal(name .. "Low"):SetText(tostring(low))
	getglobal(name .. "High"):SetText(tostring(high))

	slider.edit = MakeEditBox(parent, x + width + 12, y - 27, 58)

	return slider
end

local function SetValueControlEnabled(slider, enabled)
	slider:EnableMouse(enabled)
	slider.edit:EnableMouse(enabled)

	if enabled then
		slider:SetAlpha(1)
		slider.edit:SetAlpha(1)
	else
		slider:SetAlpha(0.45)
		slider.edit:SetAlpha(0.45)
		slider.edit:ClearFocus()
	end
end

local function SetValueControlDimmed(slider, dimmed)
	if dimmed then
		slider:SetAlpha(0.45)
		slider.edit:SetAlpha(0.45)
	else
		slider:SetAlpha(1)
		slider.edit:SetAlpha(1)
	end
end

local function MakeStylePreview(parent, styleKey, x, y)
	local style = STYLE_PRESETS[styleKey]
	local button = CreateFrame("Button", nil, parent)
	local preview
	local previewBorder
	local label

	button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	button:SetWidth(112)
	button:SetHeight(48)
	button:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true, tileSize = 8, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	button:SetBackdropColor(0.04, 0.05, 0.07, 0.9)
	button:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)

	preview = button:CreateTexture(nil, "ARTWORK")
	preview:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -9)
	preview:SetWidth(92)
	preview:SetHeight(12)
	preview:SetTexture(style.barTexture)
	preview:SetVertexColor(unpack(style.barColor))

	previewBorder = CreateFrame("Frame", nil, button)
	previewBorder:SetPoint("TOPLEFT", preview, "TOPLEFT", -style.borderInset, style.borderInset)
	previewBorder:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", style.borderInset, -style.borderInset)
	previewBorder:SetBackdrop({
		edgeFile = style.borderTexture,
		edgeSize = style.borderSize,
	})
	previewBorder:SetBackdropBorderColor(unpack(style.borderColor))

	label = button:CreateFontString(nil, "OVERLAY")
	label:SetPoint("BOTTOM", button, "BOTTOM", 0, 5)
	label:SetFont([[Fonts\FRIZQT__.TTF]], 10)
	label:SetTextColor(0.9, 0.9, 0.9)
	label:SetText(style.name)

	button.styleKey = styleKey

	button:SetScript("OnClick", function()
		visuals.style = this.styleKey
		ApplyVisualLayout()
		RefreshAppearanceOptions()
	end)

	return button
end



local function MakeRowValueSlider(parent, x, y, width, low, high, step)
	local slider
	local name

	sliderCount = sliderCount + 1
	name = "CoolineRowValueSlider" .. sliderCount

	slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	slider:SetWidth(width)
	slider:SetHeight(16)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)

	getglobal(name .. "Text"):SetText("")
	getglobal(name .. "Low"):SetText(tostring(low))
	getglobal(name .. "High"):SetText(tostring(high))

	slider.edit = MakeEditBox(parent, x + width + 12, y - 3, 58)

	return slider
end

local function ReadInteger(edit, minimum)
	local value = tonumber(edit:GetText())
	if not value then
		return nil
	end

	value = floor(value + 0.5)
	if value < minimum then
		value = minimum
	end

	return value
end

RefreshAppearanceOptions = function()
	if not optionsFrame then return end

	optionsFrame.updating = true

	optionsFrame.scope:SetValue(CoolineCharDB.useCharacterVisuals and 1 or 0)
	optionsFrame.lockBar:SetChecked(CoolineCharDB.locked and 1 or nil)
	optionsFrame.minimapToggle:SetChecked(CoolineDB.showMinimapButton and 1 or nil)
	optionsFrame.direction:SetValue(visuals.vertical and 1 or 0)
	optionsFrame.iconDirection:SetValue(visuals.reverse and 1 or 0)

	optionsFrame.length:SetValue(min(visuals.length, 1000))
	optionsFrame.length.edit:SetText(tostring(visuals.length))

	optionsFrame.width:SetValue(min(visuals.width, 100))
	optionsFrame.width.edit:SetText(tostring(visuals.width))

	optionsFrame.oversize:SetValue(min(max(visuals.iconoversize, -50), 50))
	if visuals.iconoversize > 0 then
		optionsFrame.oversize.edit:SetText("+" .. visuals.iconoversize)
	else
		optionsFrame.oversize.edit:SetText(tostring(visuals.iconoversize))
	end

	local active = floor((visuals.activealpha * 100) + 0.5)
	local inactive = floor((visuals.inactivealpha * 100) + 0.5)

	optionsFrame.active:SetValue(min(active, 100))
	optionsFrame.active.edit:SetText(active .. "%")
	optionsFrame.inactive:SetValue(min(inactive, 100))
	optionsFrame.inactive.edit:SetText(inactive .. "%")

	local animate = visuals.cooldownanimate or 150
	optionsFrame.cooldownAnimate:SetValue(min(max(animate, 100), 200))
	optionsFrame.cooldownAnimate.edit:SetText(animate .. "%")
	SetValueControlDimmed(optionsFrame.cooldownAnimate, animate == 100)

	if optionsFrame.styleButtons then
		local styleKey, button
		for styleKey, button in pairs(optionsFrame.styleButtons) do
			if visuals.style == styleKey then
				button:SetBackdropBorderColor(1, 0.82, 0, 1)
			else
				button:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)
			end
		end
	end

	optionsFrame.updating = false
end


local function ResolveItemNameAndIcon(typedName)
	local bag, slot, slots
	local link, name, texture

	-- Bags first.
	for bag = 0, 4 do
		slots = GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			link = GetContainerItemLink(bag, slot)
			name = SafeItemName(link)
			if name and strupper(name) == strupper(typedName) then
				texture = GetContainerItemInfo(bag, slot)
				return name, texture
			end
		end
	end

	-- Then equipped items.
	for slot = 0, 19 do
		link = GetInventoryItemLink("player", slot)
		name = SafeItemName(link)
		if name and strupper(name) == strupper(typedName) then
			texture = GetInventoryItemTexture("player", slot)
			return name, texture
		end
	end

	return nil, nil
end


local function RefreshSpellIconOptions()
	if not optionsFrame or not optionsFrame.spellIconOverrideCheck then return end

	optionsFrame.updating = true
	optionsFrame.spellIconOverrideCheck:SetChecked(CoolineCharDB.spellIconOverride and 1 or nil)

	local value = CoolineCharDB.spellIconOversize
	if value == nil then value = visuals.iconoversize end

	optionsFrame.spellOversize:SetValue(min(max(value, -50), 50))
	if value > 0 then
		optionsFrame.spellOversize.edit:SetText("+" .. value)
	else
		optionsFrame.spellOversize.edit:SetText(tostring(value))
	end

	SetValueControlEnabled(optionsFrame.spellOversize, CoolineCharDB.spellIconOverride)
	optionsFrame.updating = false
end

local function RefreshItemIconOptions()
	if not optionsFrame or not optionsFrame.itemIconOverrideCheck then return end

	optionsFrame.updating = true
	optionsFrame.itemIconOverrideCheck:SetChecked(CoolineCharDB.itemIconOverride and 1 or nil)

	local value = CoolineCharDB.itemIconOversize
	if value == nil then value = visuals.iconoversize end

	optionsFrame.itemOversize:SetValue(min(max(value, -50), 50))
	if value > 0 then
		optionsFrame.itemOversize.edit:SetText("+" .. value)
	else
		optionsFrame.itemOversize.edit:SetText(tostring(value))
	end

	SetValueControlEnabled(optionsFrame.itemOversize, CoolineCharDB.itemIconOverride)
	optionsFrame.updating = false
end

local function FindSpellRowByName(name)
	local i
	local row

	for i = 1, table.getn(optionsFrame.spellRows) do
		row = optionsFrame.spellRows[i]
		if row.spellName and strupper(row.spellName) == strupper(name) then
			return row
		end
	end

	return nil
end

local function FlashSpellRow(row)
	if not row then return end

	row.flashTime = 0.55
	row.highlight:Show()
	row.highlight:SetAlpha(0.55)
end

local function RemoveSpellAtIndex(index)
	local list = GetActiveFilterList()

	if index >= 1 and index <= table.getn(list) then
		tremove(list, index)
	end
end

local function RefreshSpellRows()
	local list = GetActiveFilterList()
	local total = table.getn(list)
	local maxOffset = max(0, total - SPELL_VISIBLE_ROWS)
	local offset = optionsFrame.spellOffset or 0
	local i
	local dataIndex
	local row
	local spellName
	local resolvedName
	local texture

	if offset > maxOffset then
		offset = maxOffset
		optionsFrame.spellOffset = offset
	end

	for i = 1, SPELL_VISIBLE_ROWS do
		row = optionsFrame.spellRows[i]
		dataIndex = offset + i

		if dataIndex <= total then
			spellName = list[dataIndex]
			resolvedName, texture = ResolveSpellNameAndIcon(spellName)

			row.dataIndex = dataIndex
			row.spellName = spellName
			row.name:SetText(resolvedName or spellName)

			if texture then
				row.icon:SetTexture(texture)
				row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			else
				row.icon:SetTexture([[Interface\Icons\INV_Misc_QuestionMark]])
				row.icon:SetTexCoord(0, 1, 0, 1)
			end

			row:Show()
		else
			row.dataIndex = nil
			row.spellName = nil
			row:Hide()
		end
	end

	if total > SPELL_VISIBLE_ROWS then
		optionsFrame.spellScroll:Show()
		optionsFrame.spellScroll:SetMinMaxValues(0, maxOffset)
		optionsFrame.spellScroll:SetValue(offset)
	else
		optionsFrame.spellScroll:Hide()
		optionsFrame.spellOffset = 0
	end
end

local function AddSpellFromBox()
	local typed = Trim(optionsFrame.spellAdd:GetText())
	local list
	local existing
	local resolvedName
	local texture
	local storedName

	if typed == "" then
		return
	end

	list = GetActiveFilterList()
	existing = FindSpellRowByName(typed)

	if not existing then
		local i
		for i = 1, table.getn(list) do
			if strupper(list[i]) == strupper(typed) then
				existing = true
				break
			end
		end
	end

	if existing then
		RefreshSpellRows()
		FlashSpellRow(FindSpellRowByName(typed))
		optionsFrame.spellAdd:SetText("")
		return
	end

	resolvedName, texture = ResolveSpellNameAndIcon(typed)
	storedName = resolvedName or typed

	tinsert(list, storedName)
	optionsFrame.spellAdd:SetText("")

	-- Move the list to the new row if it is beyond the viewport.
	if table.getn(list) > SPELL_VISIBLE_ROWS then
		optionsFrame.spellOffset = table.getn(list) - SPELL_VISIBLE_ROWS
	end

	RefreshSpellRows()
	FlashSpellRow(FindSpellRowByName(storedName))

	-- Reconcile immediately so filter changes take effect now.
	ReconcileAllCooldowns()
end


local function FindItemRowByName(name)
	local i
	local row

	for i = 1, table.getn(optionsFrame.itemRows) do
		row = optionsFrame.itemRows[i]
		if row.itemName and strupper(row.itemName) == strupper(name) then
			return row
		end
	end

	return nil
end

local function RefreshItemRows()
	local list = GetActiveItemFilterList()
	local total = table.getn(list)
	local maxOffset = max(0, total - ITEM_VISIBLE_ROWS)
	local offset = optionsFrame.itemOffset or 0
	local i, dataIndex, row, itemName, resolvedName, texture

	if offset > maxOffset then
		offset = maxOffset
		optionsFrame.itemOffset = offset
	end

	for i = 1, ITEM_VISIBLE_ROWS do
		row = optionsFrame.itemRows[i]
		dataIndex = offset + i

		if dataIndex <= total then
			itemName = list[dataIndex]
			resolvedName, texture = ResolveItemNameAndIcon(itemName)

			row.dataIndex = dataIndex
			row.itemName = itemName
			row.name:SetText(resolvedName or itemName)

			if texture then
				row.icon:SetTexture(texture)
				row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			else
				row.icon:SetTexture([[Interface\Icons\INV_Misc_QuestionMark]])
				row.icon:SetTexCoord(0, 1, 0, 1)
			end

			row:Show()
		else
			row.dataIndex = nil
			row.itemName = nil
			row:Hide()
		end
	end

	if total > ITEM_VISIBLE_ROWS then
		optionsFrame.itemScroll:Show()
		optionsFrame.itemScroll:SetMinMaxValues(0, maxOffset)
		optionsFrame.itemScroll:SetValue(offset)
	else
		optionsFrame.itemScroll:Hide()
		optionsFrame.itemOffset = 0
	end
end

local function RemoveItemAtIndex(index)
	local list = GetActiveItemFilterList()
	if index >= 1 and index <= table.getn(list) then
		tremove(list, index)
	end
end

local function AddItemFromBox()
	local typed = Trim(optionsFrame.itemAdd:GetText())
	local list
	local i
	local resolvedName, texture
	local storedName

	if typed == "" then return end

	list = GetActiveItemFilterList()

	for i = 1, table.getn(list) do
		if strupper(list[i]) == strupper(typed) then
			RefreshItemRows()
			FlashSpellRow(FindItemRowByName(typed))
			optionsFrame.itemAdd:SetText("")
			return
		end
	end

	resolvedName, texture = ResolveItemNameAndIcon(typed)
	storedName = resolvedName or typed

	tinsert(list, storedName)
	optionsFrame.itemAdd:SetText("")

	if table.getn(list) > ITEM_VISIBLE_ROWS then
		optionsFrame.itemOffset = table.getn(list) - ITEM_VISIBLE_ROWS
	end

	RefreshItemRows()
	FlashSpellRow(FindItemRowByName(storedName))
	ReconcileAllCooldowns()
end

local function ShowOptionsPage(page)
	optionsFrame.appearancePage:Hide()
	optionsFrame.spellsPage:Hide()
	optionsFrame.itemsPage:Hide()

	if page == "spells" then
		optionsFrame.spellsPage:Show()
		RefreshSpellIconOptions()
		RefreshSpellRows()
	elseif page == "items" then
		optionsFrame.itemsPage:Show()
		RefreshItemIconOptions()
		RefreshItemRows()
	else
		optionsFrame.appearancePage:Show()
		RefreshAppearanceOptions()
	end
end

local function MakeTab(parent, text, width)
	local tab = CreateFrame("Button", nil, parent)
	local label

	tab:SetWidth(width)
	tab:SetHeight(28)
	tab:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 8,
		edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	tab:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
	tab:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)

	label = tab:CreateFontString(nil, "OVERLAY")
	label:SetPoint("CENTER", tab, "CENTER", 0, 0)
	label:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	label:SetTextColor(1, 0.82, 0)
	label:SetText(text)
	tab.label = label

	return tab
end

local function SelectOptionsTab(selected)
	local tabs = {
		optionsFrame.appearanceTab,
		optionsFrame.spellsTab,
		optionsFrame.itemsTab,
	}
	local i, tab

	for i = 1, table.getn(tabs) do
		tab = tabs[i]

		if tab == selected then
			tab:SetBackdropColor(0.08, 0.10, 0.13, 1)
			tab:SetBackdropBorderColor(1, 0.82, 0, 1)
			tab.label:SetTextColor(1, 0.82, 0)
		else
			tab:SetBackdropColor(0.04, 0.05, 0.07, 0.90)
			tab:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)
			tab.label:SetTextColor(0.9, 0.9, 0.9)
		end
	end
end

local OptionsDeps = {
	VERSION = VERSION,
	ApplyBarLockState = ApplyBarLockState,
	UpdateMinimapButton = UpdateMinimapButton,
	SelectVisualScope = SelectVisualScope,
	ApplyVisualLayout = ApplyVisualLayout,
	ReconcileAllCooldowns = ReconcileAllCooldowns,
	RefreshAppearanceOptions = RefreshAppearanceOptions,
	SPELL_ROW_HEIGHT = SPELL_ROW_HEIGHT,
	SPELL_VISIBLE_ROWS = SPELL_VISIBLE_ROWS,
	ITEM_VISIBLE_ROWS = ITEM_VISIBLE_ROWS,
	MakeText = MakeText,
	MakeButton = MakeButton,
	MakeBinarySlider = MakeBinarySlider,
	MakeCheckbox = MakeCheckbox,
	MakeEditBox = MakeEditBox,
	MakeValueSlider = MakeValueSlider,
	SetValueControlDimmed = SetValueControlDimmed,
	MakeStylePreview = MakeStylePreview,
	MakeRowValueSlider = MakeRowValueSlider,
	ReadInteger = ReadInteger,
	RefreshSpellIconOptions = RefreshSpellIconOptions,
	RefreshItemIconOptions = RefreshItemIconOptions,
	RemoveSpellAtIndex = RemoveSpellAtIndex,
	RefreshSpellRows = RefreshSpellRows,
	AddSpellFromBox = AddSpellFromBox,
	RefreshItemRows = RefreshItemRows,
	RemoveItemAtIndex = RemoveItemAtIndex,
	AddItemFromBox = AddItemFromBox,
	ShowOptionsPage = ShowOptionsPage,
	MakeTab = MakeTab,
	SelectOptionsTab = SelectOptionsTab,
}

local function BuildOptions()
	local close
	local panel
	local appearanceTab
	local spellsTab
	local itemsTab
	local page
	local spells
	local items
	local addButton
	local itemAddButton
	local listFrame
	local scroll
	local i
	local row

	if optionsFrame then return end

	optionsFrame = CreateFrame("Frame", "CoolineOptionsFrame", UIParent)
	optionsFrame:SetWidth(540)
	optionsFrame:SetHeight(760)
	optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	optionsFrame:SetFrameStrata("DIALOG")
	optionsFrame:SetMovable(true)
	optionsFrame:EnableMouse(true)
	optionsFrame:RegisterForDrag("LeftButton")
	optionsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
	optionsFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	optionsFrame:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true, tileSize = 32, edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	optionsFrame:SetBackdropColor(0.08, 0.10, 0.13, 0.98)
	optionsFrame:SetBackdropBorderColor(0.45, 0.52, 0.60, 1)
	optionsFrame:Hide()

	tinsert(UISpecialFrames, "CoolineOptionsFrame")

	local headerIcon = optionsFrame:CreateTexture(nil, "ARTWORK")
	headerIcon:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 18, -13)
	headerIcon:SetWidth(24)
	headerIcon:SetHeight(24)
	headerIcon:SetTexture([[Interface\Icons\INV_Qiraj_JewelGlyphed]])
	headerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	OptionsDeps.MakeText(optionsFrame, "Cooline", 50, -16, 14, true)
	OptionsDeps.MakeText(optionsFrame, "v" .. OptionsDeps.VERSION, 107, -18, 10, false)

	optionsFrame.lockBar = OptionsDeps.MakeCheckbox(optionsFrame, "Lock Bar", 245, -12)
	optionsFrame.minimapToggle = OptionsDeps.MakeCheckbox(
		optionsFrame,
		"Minimap Button",
		345,
		-12
	)

	close = OptionsDeps.MakeButton(optionsFrame, "X", 24)
	close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -11)
	close:SetScript("OnClick", function() optionsFrame:Hide() end)

	appearanceTab = OptionsDeps.MakeTab(optionsFrame, "Appearance", 112)
	appearanceTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 26, -50)
	optionsFrame.appearanceTab = appearanceTab

	spellsTab = OptionsDeps.MakeTab(optionsFrame, "Spells", 90)
	spellsTab:SetPoint("LEFT", appearanceTab, "RIGHT", 4, 0)
	optionsFrame.spellsTab = spellsTab

	itemsTab = OptionsDeps.MakeTab(optionsFrame, "Items", 90)
	itemsTab:SetPoint("LEFT", spellsTab, "RIGHT", 4, 0)
	optionsFrame.itemsTab = itemsTab

	panel = CreateFrame("Frame", nil, optionsFrame)
	panel:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 16, -72)
	panel:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 16)
	panel:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	panel:SetBackdropColor(0.04, 0.05, 0.07, 0.88)
	panel:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)

	-- Appearance page
	page = CreateFrame("Frame", nil, panel)
	page:SetAllPoints(panel)
	optionsFrame.appearancePage = page

	OptionsDeps.MakeText(page, "Appearance", 18, -18, 14, true)
	optionsFrame.scope = OptionsDeps.MakeBinarySlider(page, "Account Wide", "Per Character", 360, -20, 42)

	OptionsDeps.MakeText(page, "Style", 18, -50, 12, true)
	optionsFrame.styleButtons = {}
	optionsFrame.styleButtons.classic = OptionsDeps.MakeStylePreview(page, "classic", 20, -72)
	optionsFrame.styleButtons.flat = OptionsDeps.MakeStylePreview(page, "flat", 137, -72)
	optionsFrame.styleButtons.dark = OptionsDeps.MakeStylePreview(page, "dark", 254, -72)
	optionsFrame.styleButtons.borderless = OptionsDeps.MakeStylePreview(page, "borderless", 371, -72)

	OptionsDeps.MakeText(page, "Animate on Cooldown", 28, -145, 11, false)
	optionsFrame.cooldownAnimate = OptionsDeps.MakeRowValueSlider(
		page, 244, -145, 170, 100, 200, 10
	)

	OptionsDeps.MakeText(page, "Layout", 18, -194, 12, true)

	OptionsDeps.MakeText(page, "Bar Direction", 28, -229, 11, false)
	optionsFrame.direction = OptionsDeps.MakeBinarySlider(
		page, "Horizontal", "Vertical", 244, -226, 170
	)

	OptionsDeps.MakeText(page, "Icon Direction", 28, -271, 11, false)
	optionsFrame.iconDirection = OptionsDeps.MakeBinarySlider(
		page, "Ascending", "Descending", 244, -268, 170
	)

	OptionsDeps.MakeText(page, "Sizes", 18, -316, 12, true)

	OptionsDeps.MakeText(page, "Bar Length", 28, -351, 11, false)
	optionsFrame.length = OptionsDeps.MakeRowValueSlider(
		page, 244, -351, 170, 100, 1000, 10
	)

	OptionsDeps.MakeText(page, "Bar Width", 28, -393, 11, false)
	optionsFrame.width = OptionsDeps.MakeRowValueSlider(
		page, 244, -393, 170, 2, 100, 2
	)

	OptionsDeps.MakeText(page, "Icon Oversize", 28, -435, 11, false)
	optionsFrame.oversize = OptionsDeps.MakeRowValueSlider(
		page, 244, -435, 170, -50, 50, 2
	)

	OptionsDeps.MakeText(page, "Opacity", 18, -480, 12, true)

	OptionsDeps.MakeText(page, "Bar Active", 28, -515, 11, false)
	optionsFrame.active = OptionsDeps.MakeRowValueSlider(
		page, 244, -515, 170, 0, 100, 10
	)

	OptionsDeps.MakeText(page, "Bar Inactive", 28, -557, 11, false)
	optionsFrame.inactive = OptionsDeps.MakeRowValueSlider(
		page, 244, -557, 170, 0, 100, 10
	)

	-- Spells page
	spells = CreateFrame("Frame", nil, panel)
	spells:SetAllPoints(panel)
	spells:Hide()
	optionsFrame.spellsPage = spells

	OptionsDeps.MakeText(spells, "Spells", 18, -18, 14, true)

	OptionsDeps.MakeText(spells, "Icon Size", 18, -54, 12, true)
	optionsFrame.spellIconOverrideCheck = OptionsDeps.MakeCheckbox(
		spells,
		"Spell Only Icon Oversize",
		28,
		-78
	)
	optionsFrame.spellOversize = OptionsDeps.MakeValueSlider(spells, "Icon Oversize", 28, -116, 350, -50, 50, 2)

	OptionsDeps.MakeText(spells, "Filter Type", 18, -176, 12, true)
	optionsFrame.filterType = OptionsDeps.MakeBinarySlider(spells, "Blacklist", "Whitelist", 174, -202, 140)

	OptionsDeps.MakeText(spells, "Add Spell", 18, -242, 12, true)
	optionsFrame.spellAdd = OptionsDeps.MakeEditBox(spells, 28, -272, 330)
	optionsFrame.spellAdd:SetJustifyH("LEFT")
	optionsFrame.spellAdd:SetTextInsets(6, 6, 0, 0)

	addButton = OptionsDeps.MakeButton(spells, "Add", 70)
	addButton:SetPoint("TOPLEFT", spells, "TOPLEFT", 372, -271)

	OptionsDeps.MakeText(spells, "Filtered Spells", 18, -316, 12, true)

	listFrame = CreateFrame("Frame", nil, spells)
	listFrame:SetPoint("TOPLEFT", spells, "TOPLEFT", 28, -344)
	listFrame:SetWidth(440)
	listFrame:SetHeight(OptionsDeps.SPELL_ROW_HEIGHT * OptionsDeps.SPELL_VISIBLE_ROWS)
	listFrame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	listFrame:SetBackdropColor(0, 0, 0, 0.35)
	listFrame:SetBackdropBorderColor(0.22, 0.26, 0.31, 1)

	optionsFrame.spellRows = {}

	for i = 1, OptionsDeps.SPELL_VISIBLE_ROWS do
		row = CreateFrame("Frame", nil, listFrame)
		row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4 - ((i - 1) * OptionsDeps.SPELL_ROW_HEIGHT))
		row:SetWidth(410)
		row:SetHeight(OptionsDeps.SPELL_ROW_HEIGHT)

		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetAllPoints(row)
		row.highlight:SetTexture(1, 0.82, 0, 0.55)
		row.highlight:Hide()

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.icon:SetWidth(22)
		row.icon:SetHeight(22)

		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
		row.name:SetWidth(320)
		row.name:SetHeight(22)
		row.name:SetJustifyH("LEFT")
		row.name:SetFont([[Fonts\FRIZQT__.TTF]], 11)
		row.name:SetTextColor(0.9, 0.9, 0.9)

		row.remove = OptionsDeps.MakeButton(row, "X", 24)
		row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.remove:SetScript("OnClick", function()
			if this:GetParent().dataIndex then
				OptionsDeps.RemoveSpellAtIndex(this:GetParent().dataIndex)
				OptionsDeps.RefreshSpellRows()
				OptionsDeps.ReconcileAllCooldowns()
			end
		end)

		row:SetScript("OnUpdate", function()
			if this.flashTime and this.flashTime > 0 then
				this.flashTime = this.flashTime - arg1
				if this.flashTime <= 0 then
					this.flashTime = nil
					this.highlight:Hide()
				else
					this.highlight:SetAlpha(min(0.55, this.flashTime))
				end
			end
		end)

		row:Hide()
		optionsFrame.spellRows[i] = row
	end

	scroll = CreateFrame("Slider", "CoolineSpellScrollBar", listFrame, "UIPanelScrollBarTemplate")
	scroll:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -2, -18)
	scroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -2, 18)
	scroll:SetMinMaxValues(0, 0)
	scroll:SetValueStep(1)
	scroll:SetValue(0)
	scroll:Hide()
	optionsFrame.spellScroll = scroll
	optionsFrame.spellOffset = 0

	scroll:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		optionsFrame.spellOffset = floor(this:GetValue() + 0.5)
		OptionsDeps.RefreshSpellRows()
	end)

	optionsFrame.filterType:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end

		if this:GetValue() >= 0.5 then
			CoolineCharDB.filters.mode = "whitelist"
		else
			CoolineCharDB.filters.mode = "blacklist"
		end

		optionsFrame.spellOffset = 0
		OptionsDeps.RefreshSpellRows()
		OptionsDeps.ReconcileAllCooldowns()
	end)

	optionsFrame.spellAdd:SetScript("OnEnterPressed", function()
		OptionsDeps.AddSpellFromBox()
		this:ClearFocus()
	end)

	optionsFrame.spellAdd:SetScript("OnEscapePressed", function()
		this:ClearFocus()
	end)

	addButton:SetScript("OnClick", function()
		OptionsDeps.AddSpellFromBox()
	end)

	optionsFrame.lockBar:SetScript("OnClick", function()
		if optionsFrame.updating then return end

		CoolineCharDB.locked = this:GetChecked() and true or false
		OptionsDeps.ApplyBarLockState()
	end)

	optionsFrame.minimapToggle:SetScript("OnClick", function()
		if optionsFrame.updating then return end

		CoolineDB.showMinimapButton = this:GetChecked() and true or false
		OptionsDeps.UpdateMinimapButton()
	end)

	appearanceTab:SetScript("OnClick", function()
		OptionsDeps.SelectOptionsTab(appearanceTab)
		OptionsDeps.ShowOptionsPage("appearance")
	end)

	spellsTab:SetScript("OnClick", function()
		OptionsDeps.SelectOptionsTab(spellsTab)
		optionsFrame.updating = true
		optionsFrame.filterType:SetValue(CoolineCharDB.filters.mode == "whitelist" and 1 or 0)
		optionsFrame.updating = false
		OptionsDeps.ShowOptionsPage("spells")
	end)


	-- Items page
	items = CreateFrame("Frame", nil, panel)
	items:SetAllPoints(panel)
	items:Hide()
	optionsFrame.itemsPage = items

	OptionsDeps.MakeText(items, "Items", 18, -18, 14, true)

	OptionsDeps.MakeText(items, "Icon Size", 18, -54, 12, true)
	optionsFrame.itemIconOverrideCheck = OptionsDeps.MakeCheckbox(
		items,
		"Item Only Icon Oversize",
		28,
		-78
	)
	optionsFrame.itemOversize = OptionsDeps.MakeValueSlider(items, "Icon Oversize", 28, -116, 350, -50, 50, 2)

	OptionsDeps.MakeText(items, "Filter Type", 18, -176, 12, true)
	optionsFrame.itemFilterType = OptionsDeps.MakeBinarySlider(items, "Blacklist", "Whitelist", 174, -202, 140)

	OptionsDeps.MakeText(items, "Add Item", 18, -242, 12, true)
	optionsFrame.itemAdd = OptionsDeps.MakeEditBox(items, 28, -272, 330)
	optionsFrame.itemAdd:SetJustifyH("LEFT")
	optionsFrame.itemAdd:SetTextInsets(6, 6, 0, 0)

	itemAddButton = OptionsDeps.MakeButton(items, "Add", 70)
	itemAddButton:SetPoint("TOPLEFT", items, "TOPLEFT", 372, -271)

	OptionsDeps.MakeText(items, "Filtered Items", 18, -316, 12, true)

	local itemListFrame = CreateFrame("Frame", nil, items)
	itemListFrame:SetPoint("TOPLEFT", items, "TOPLEFT", 28, -344)
	itemListFrame:SetWidth(440)
	itemListFrame:SetHeight(OptionsDeps.SPELL_ROW_HEIGHT * OptionsDeps.ITEM_VISIBLE_ROWS)
	itemListFrame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	itemListFrame:SetBackdropColor(0, 0, 0, 0.35)
	itemListFrame:SetBackdropBorderColor(0.22, 0.26, 0.31, 1)

	optionsFrame.itemRows = {}

	for i = 1, OptionsDeps.ITEM_VISIBLE_ROWS do
		row = CreateFrame("Frame", nil, itemListFrame)
		row:SetPoint("TOPLEFT", itemListFrame, "TOPLEFT", 4, -4 - ((i - 1) * OptionsDeps.SPELL_ROW_HEIGHT))
		row:SetWidth(410)
		row:SetHeight(OptionsDeps.SPELL_ROW_HEIGHT)

		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetAllPoints(row)
		row.highlight:SetTexture(1, 0.82, 0, 0.55)
		row.highlight:Hide()

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
		row.icon:SetWidth(22)
		row.icon:SetHeight(22)

		row.name = row:CreateFontString(nil, "OVERLAY")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
		row.name:SetWidth(320)
		row.name:SetHeight(22)
		row.name:SetJustifyH("LEFT")
		row.name:SetFont([[Fonts\FRIZQT__.TTF]], 11)
		row.name:SetTextColor(0.9, 0.9, 0.9)

		row.remove = OptionsDeps.MakeButton(row, "X", 24)
		row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.remove:SetScript("OnClick", function()
			if this:GetParent().dataIndex then
				OptionsDeps.RemoveItemAtIndex(this:GetParent().dataIndex)
				OptionsDeps.RefreshItemRows()
				OptionsDeps.ReconcileAllCooldowns()
			end
		end)

		row:SetScript("OnUpdate", function()
			if this.flashTime and this.flashTime > 0 then
				this.flashTime = this.flashTime - arg1
				if this.flashTime <= 0 then
					this.flashTime = nil
					this.highlight:Hide()
				else
					this.highlight:SetAlpha(min(0.55, this.flashTime))
				end
			end
		end)

		row:Hide()
		optionsFrame.itemRows[i] = row
	end

	local itemScroll = CreateFrame("Slider", "CoolineItemScrollBar", itemListFrame, "UIPanelScrollBarTemplate")
	itemScroll:SetPoint("TOPRIGHT", itemListFrame, "TOPRIGHT", -2, -18)
	itemScroll:SetPoint("BOTTOMRIGHT", itemListFrame, "BOTTOMRIGHT", -2, 18)
	itemScroll:SetMinMaxValues(0, 0)
	itemScroll:SetValueStep(1)
	itemScroll:SetValue(0)
	itemScroll:Hide()
	optionsFrame.itemScroll = itemScroll
	optionsFrame.itemOffset = 0

	itemScroll:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		optionsFrame.itemOffset = floor(this:GetValue() + 0.5)
		OptionsDeps.RefreshItemRows()
	end)

	optionsFrame.itemFilterType:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		if this:GetValue() >= 0.5 then
			CoolineCharDB.itemFilters.mode = "whitelist"
		else
			CoolineCharDB.itemFilters.mode = "blacklist"
		end
		optionsFrame.itemOffset = 0
		OptionsDeps.RefreshItemRows()
		OptionsDeps.ReconcileAllCooldowns()
	end)

	optionsFrame.itemAdd:SetScript("OnEnterPressed", function()
		OptionsDeps.AddItemFromBox()
		this:ClearFocus()
	end)

	optionsFrame.itemAdd:SetScript("OnEscapePressed", function()
		this:ClearFocus()
	end)

	itemAddButton:SetScript("OnClick", function()
		OptionsDeps.AddItemFromBox()
	end)

	itemsTab:SetScript("OnClick", function()
		OptionsDeps.SelectOptionsTab(itemsTab)
		optionsFrame.updating = true
		optionsFrame.itemFilterType:SetValue(CoolineCharDB.itemFilters.mode == "whitelist" and 1 or 0)
		optionsFrame.updating = false
		OptionsDeps.ShowOptionsPage("items")
	end)


	optionsFrame.spellIconOverrideCheck:SetScript("OnClick", function()
		if optionsFrame.updating then return end

		CoolineCharDB.spellIconOverride = this:GetChecked() and true or false

		if CoolineCharDB.spellIconOverride and CoolineCharDB.spellIconOversize == nil then
			CoolineCharDB.spellIconOversize = visuals.iconoversize
		end

		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshSpellIconOptions()
	end)

	optionsFrame.spellOversize:SetScript("OnValueChanged", function()
		if optionsFrame.updating or not CoolineCharDB.spellIconOverride then return end

		local value = floor(this:GetValue() + 0.5)
		CoolineCharDB.spellIconOversize = value

		if value > 0 then
			this.edit:SetText("+" .. value)
		else
			this.edit:SetText(tostring(value))
		end

		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.spellOversize.edit:SetScript("OnEnterPressed", function()
		local value = OptionsDeps.ReadInteger(this, -50)
		this:ClearFocus()

		if not value then
			OptionsDeps.RefreshSpellIconOptions()
			return
		end

		CoolineCharDB.spellIconOverride = true
		CoolineCharDB.spellIconOversize = value
		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshSpellIconOptions()
	end)

	optionsFrame.spellOversize.edit:SetScript("OnEscapePressed", function()
		this:ClearFocus()
		OptionsDeps.RefreshSpellIconOptions()
	end)

	optionsFrame.itemIconOverrideCheck:SetScript("OnClick", function()
		if optionsFrame.updating then return end

		CoolineCharDB.itemIconOverride = this:GetChecked() and true or false

		if CoolineCharDB.itemIconOverride and CoolineCharDB.itemIconOversize == nil then
			CoolineCharDB.itemIconOversize = visuals.iconoversize
		end

		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshItemIconOptions()
	end)

	optionsFrame.itemOversize:SetScript("OnValueChanged", function()
		if optionsFrame.updating or not CoolineCharDB.itemIconOverride then return end

		local value = floor(this:GetValue() + 0.5)
		CoolineCharDB.itemIconOversize = value

		if value > 0 then
			this.edit:SetText("+" .. value)
		else
			this.edit:SetText(tostring(value))
		end

		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.itemOversize.edit:SetScript("OnEnterPressed", function()
		local value = OptionsDeps.ReadInteger(this, -50)
		this:ClearFocus()

		if not value then
			OptionsDeps.RefreshItemIconOptions()
			return
		end

		CoolineCharDB.itemIconOverride = true
		CoolineCharDB.itemIconOversize = value
		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshItemIconOptions()
	end)

	optionsFrame.itemOversize.edit:SetScript("OnEscapePressed", function()
		this:ClearFocus()
		OptionsDeps.RefreshItemIconOptions()
	end)

	optionsFrame.cooldownAnimate:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end

		local value = floor(this:GetValue() + 0.5)
		visuals.cooldownanimate = value
		this.edit:SetText(value .. "%")
		OptionsDeps.SetValueControlDimmed(this, value == 100)
	end)

	optionsFrame.cooldownAnimate.edit:SetScript("OnEnterPressed", function()
		local text = string.gsub(this:GetText(), "%%", "")
		local value = tonumber(text)

		this:ClearFocus()

		if not value or value <= 0 then
			OptionsDeps.RefreshAppearanceOptions()
			return
		end

		value = floor(value + 0.5)
		visuals.cooldownanimate = value

		optionsFrame.updating = true
		optionsFrame.cooldownAnimate:SetValue(min(max(value, 100), 200))
		optionsFrame.updating = false

		OptionsDeps.RefreshAppearanceOptions()
	end)

	optionsFrame.cooldownAnimate.edit:SetScript("OnEscapePressed", function()
		this:ClearFocus()
		OptionsDeps.RefreshAppearanceOptions()
	end)

	-- Appearance scripts
	optionsFrame.scope:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		OptionsDeps.SelectVisualScope(this:GetValue() >= 0.5)
		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshAppearanceOptions()
	end)

	optionsFrame.direction:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.vertical = this:GetValue() >= 0.5
		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.iconDirection:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.reverse = this:GetValue() >= 0.5
		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.length:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.length = floor(this:GetValue() + 0.5)
		this.edit:SetText(tostring(visuals.length))
		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.width:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.width = floor(this:GetValue() + 0.5)
		this.edit:SetText(tostring(visuals.width))
		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.oversize:SetScript("OnValueChanged", function()
		local value
		if optionsFrame.updating then return end
		value = floor(this:GetValue() + 0.5)
		visuals.iconoversize = value
		if value > 0 then this.edit:SetText("+" .. value) else this.edit:SetText(tostring(value)) end
		OptionsDeps.ApplyVisualLayout()
	end)

	optionsFrame.active:SetScript("OnValueChanged", function()
		local value
		if optionsFrame.updating then return end
		value = floor(this:GetValue() + 0.5)
		visuals.activealpha = value / 100
		this.edit:SetText(value .. "%")
	end)

	optionsFrame.inactive:SetScript("OnValueChanged", function()
		local value
		if optionsFrame.updating then return end
		value = floor(this:GetValue() + 0.5)
		visuals.inactivealpha = value / 100
		this.edit:SetText(value .. "%")
	end)

	optionsFrame.length.edit:SetScript("OnEnterPressed", function()
		local value = OptionsDeps.ReadInteger(this, 100)
		this:ClearFocus()
		if not value then OptionsDeps.RefreshAppearanceOptions() return end
		visuals.length = value
		optionsFrame.updating = true
		optionsFrame.length:SetValue(min(value, 1000))
		optionsFrame.updating = false
		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshAppearanceOptions()
	end)

	optionsFrame.width.edit:SetScript("OnEnterPressed", function()
		local value = OptionsDeps.ReadInteger(this, 2)
		this:ClearFocus()
		if not value then OptionsDeps.RefreshAppearanceOptions() return end
		visuals.width = value
		optionsFrame.updating = true
		optionsFrame.width:SetValue(min(value, 100))
		optionsFrame.updating = false
		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshAppearanceOptions()
	end)

	optionsFrame.oversize.edit:SetScript("OnEnterPressed", function()
		local value = OptionsDeps.ReadInteger(this, -50)
		this:ClearFocus()
		if not value then OptionsDeps.RefreshAppearanceOptions() return end
		visuals.iconoversize = value
		optionsFrame.updating = true
		optionsFrame.oversize:SetValue(min(value, 50))
		optionsFrame.updating = false
		OptionsDeps.ApplyVisualLayout()
		OptionsDeps.RefreshAppearanceOptions()
	end)

	optionsFrame.active.edit:SetScript("OnEnterPressed", function()
		local text = string.gsub(this:GetText(), "%%", "")
		local value = tonumber(text)
		this:ClearFocus()
		if not value then OptionsDeps.RefreshAppearanceOptions() return end
		value = floor(value + 0.5)
		if value < 0 then value = 0 end
		visuals.activealpha = value / 100
		optionsFrame.updating = true
		optionsFrame.active:SetValue(min(value, 100))
		optionsFrame.updating = false
		OptionsDeps.RefreshAppearanceOptions()
	end)

	optionsFrame.inactive.edit:SetScript("OnEnterPressed", function()
		local text = string.gsub(this:GetText(), "%%", "")
		local value = tonumber(text)
		this:ClearFocus()
		if not value then OptionsDeps.RefreshAppearanceOptions() return end
		value = floor(value + 0.5)
		if value < 0 then value = 0 end
		visuals.inactivealpha = value / 100
		optionsFrame.updating = true
		optionsFrame.inactive:SetValue(min(value, 100))
		optionsFrame.updating = false
		OptionsDeps.RefreshAppearanceOptions()
	end)

	local edits = {
		optionsFrame.length.edit,
		optionsFrame.width.edit,
		optionsFrame.oversize.edit,
		optionsFrame.active.edit,
		optionsFrame.inactive.edit,
	}
	for i = 1, table.getn(edits) do
		edits[i]:SetScript("OnEscapePressed", function()
			this:ClearFocus()
			OptionsDeps.RefreshAppearanceOptions()
		end)
	end

	OptionsDeps.SelectOptionsTab(appearanceTab)
	OptionsDeps.ShowOptionsPage("appearance")
end

ToggleOptions = function()
	BuildOptions()
	if optionsFrame:IsShown() then
		optionsFrame:Hide()
	else
		ShowOptionsPage("appearance")
		optionsFrame:Show()
	end
end

SLASH_COOLINE1 = "/cooline"
SlashCmdList["COOLINE"] = function(msg)
	ToggleOptions()
end

local function OnVariablesLoaded()
	InitialiseSettings()
	BuildBar()
	BuildOptions()
	BuildMinimapButton()
	ReconcileAllCooldowns()

	bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	bar:RegisterEvent("SPELLS_CHANGED")
	bar:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER")
	bar:RegisterEvent("BAG_UPDATE_COOLDOWN")
	bar:RegisterEvent("BAG_UPDATE")
	bar:RegisterEvent("UNIT_INVENTORY_CHANGED")
	bar:RegisterEvent("PLAYER_ENTERING_WORLD")

	DEFAULT_CHAT_FRAME:AddMessage(
		"|c00ffff00Cooline " .. VERSION .. " loaded.|r"
	)
end

bar:RegisterEvent("VARIABLES_LOADED")

bar:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		OnVariablesLoaded()
	elseif event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" and initialised then
		local _, _, failedSpell = strfind(
			arg1 or "",
			"^You fail to cast (.+): Not yet recovered%.$"
		)

		if failedSpell then
			TriggerCooldownPulse(failedSpell)
		end
	elseif initialised then
		ReconcileAllCooldowns()
	end
end)

bar:SetScript("OnUpdate", function()
	if not initialised then
		return
	end

	scanElapsed = scanElapsed + arg1
	if scanElapsed >= SCAN_INTERVAL then
		scanElapsed = 0
		ReconcileAllCooldowns()
	end

	Render()
end)
