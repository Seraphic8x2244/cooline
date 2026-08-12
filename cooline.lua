-- Cooline 1.9.1 timeline test
-- Clean single-file rebuild for WoW 1.12.1.
-- This stage adds the real nonlinear Cooline timeline and smooth spell movement.

local VERSION = "1.9.1-itemidentity"

local DEFAULTS = {
	length = 360,
	width = 18,
	iconoversize = 4,
	x = 0,
	y = -240,
	vertical = false,
	reverse = false,
	inactivealpha = 0.5,
	activealpha = 1.0,
}

local bar = CreateFrame("Frame", "CoolineBar", UIParent)
local cooldowns = {}
local initialised = false
local ToggleOptions
local pendingItemUse
local itemCooldownLocks = {}
local itemCooldownNames = {}
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
	UseContainerItem = function(bag, slot)
		local link = GetContainerItemLink(bag, slot)
		local name = SafeItemName(link)
		local texture = GetContainerItemInfo(bag, slot)

		if name then
			CapturePendingItem(name, texture)
		end

		return OriginalUseContainerItem(bag, slot)
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
	local size = max(2, visuals.width + visuals.iconoversize)
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

	for name, cd in pairs(cooldowns) do
		cd:SetWidth(size)
		cd:SetHeight(size)
	end

	LayoutLabels()
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
	bar:SetAlpha(s.inactivealpha)

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetTexture([[Interface\TargetingFrame\UI-StatusBar]])
	bar.bg:SetVertexColor(0, 0, 0, 0.5)

	bar.border = CreateFrame("Frame", nil, bar)
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 4)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -4)
	bar.border:SetBackdrop({
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		edgeSize = 16,
	})
	bar.border:SetBackdropBorderColor(1, 1, 1, 1)

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
	bar.clickOverlay:SetFrameLevel(bar.overlay and (bar.overlay:GetFrameLevel() + 1) or 30)
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
		size = max(2, visuals.width + visuals.iconoversize)
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

local function ReconcileAllCooldowns()
	local spellCount = GetSpellCount()
	local id
	local name
	local startTime, duration, enabled
	local texture
	local cd
	local seen = {}
	local now = GetTime()

	for id = 1, spellCount do
		name = GetSpellName(id, BOOKTYPE_SPELL)

		if name then
			startTime, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)

			if SpellAllowed(name) and enabled == 1 and duration and duration > 2.5 then
				if (startTime + duration) > now then
					cd = EnsureCooldown("spell:" .. name)
					texture = GetSpellTexture(id, BOOKTYPE_SPELL)

					cd.startTime = startTime
					cd.duration = duration
					cd.endTime = startTime + duration
					cd.icon:SetTexture(texture)
					cd:Show()
					seen["spell:" .. name] = true
				end
			end
		end
	end

	for name, cd in pairs(cooldowns) do
		if not seen[name] and (not cd.endTime or cd.endTime <= now) then
			cd:Hide()
			cd.endTime = nil
		end
	end
end

local function ScanItems(seen)
	local candidates = {}
	local currentNames = {}
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

		currentNames[itemName] = true
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
				itemCooldownNames[pendingItemUse.name] = candidate.signature

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
			itemCooldownNames[candidate.name] = candidate.signature

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
			if itemCooldownNames[lockedName] == signature then
				itemCooldownNames[lockedName] = nil
			end
		end
	end
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
		if not seen[name] and (not cd.endTime or cd.endTime <= now) then
			cd:Hide()
			cd.endTime = nil
		end
	end
end

local function Render()
	local now = GetTime()
	local anyActive = false
	local name, cd
	local remaining
	local offset
	local level = 2

	for name, cd in pairs(cooldowns) do
		if cd.endTime then
			remaining = cd.endTime - now

			if remaining > 0 then
				anyActive = true
				offset = TimelineOffset(remaining)

				cd:SetFrameLevel(level)
				level = level + 1

				PlaceOnTimeline(cd, offset)
				cd:SetAlpha(1)
				cd:Show()
			else
				cd:Hide()
				cd.endTime = nil
			end
		end
	end

	bar:SetAlpha(anyActive and visuals.activealpha or visuals.inactivealpha)
end


-- ============================================================================
-- Options
-- ============================================================================

local optionsFrame
local sliderCount = 0
local SPELL_ROW_HEIGHT = 28
local SPELL_VISIBLE_ROWS = 9
local ITEM_VISIBLE_ROWS = 9

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

	slider.edit = MakeEditBox(parent, x + width + 24, y - 27, 58)

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

local function RefreshAppearanceOptions()
	if not optionsFrame then return end

	optionsFrame.updating = true

	optionsFrame.scope:SetValue(CoolineCharDB.useCharacterVisuals and 1 or 0)
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
		RefreshSpellRows()
	elseif page == "items" then
		optionsFrame.itemsPage:Show()
		RefreshItemRows()
	else
		optionsFrame.appearancePage:Show()
		RefreshAppearanceOptions()
	end
end

local function BuildOptions()
	local close
	local panel
	local done
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
	optionsFrame:SetHeight(690)
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

	MakeText(optionsFrame, "Cooline", 18, -16, 14, true)
	MakeText(optionsFrame, "v1.9.1", 75, -18, 10, false)

	close = MakeButton(optionsFrame, "X", 24)
	close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -11)
	close:SetScript("OnClick", function() optionsFrame:Hide() end)

	appearanceTab = MakeButton(optionsFrame, "Appearance", 105)
	appearanceTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 18, -46)

	spellsTab = MakeButton(optionsFrame, "Spells", 105)
	spellsTab:SetPoint("LEFT", appearanceTab, "RIGHT", 4, 0)

	itemsTab = MakeButton(optionsFrame, "Items", 105)
	itemsTab:SetPoint("LEFT", spellsTab, "RIGHT", 4, 0)

	panel = CreateFrame("Frame", nil, optionsFrame)
	panel:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 16, -76)
	panel:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 42)
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

	MakeText(page, "Appearance", 18, -18, 14, true)

	MakeText(page, "Settings", 18, -54, 12, true)
	optionsFrame.scope = MakeBinarySlider(page, "Account Wide", "Per Character", 174, -80, 140)

	MakeText(page, "Layout", 18, -116, 12, true)
	MakeText(page, "Bar Direction", 28, -145, 11, false)
	optionsFrame.direction = MakeBinarySlider(page, "Horizontal", "Vertical", 174, -165, 140)

	MakeText(page, "Icon Direction", 28, -195, 11, false)
	optionsFrame.iconDirection = MakeBinarySlider(page, "Ascending", "Descending", 174, -215, 140)

	MakeText(page, "Sizes", 18, -252, 12, true)
	optionsFrame.length = MakeValueSlider(page, "Bar Length", 28, -280, 350, 100, 1000, 10)
	optionsFrame.width = MakeValueSlider(page, "Bar Width", 28, -338, 350, 2, 100, 2)
	optionsFrame.oversize = MakeValueSlider(page, "Icon Oversize", 28, -396, 350, -50, 50, 2)

	MakeText(page, "Opacity", 18, -454, 12, true)
	optionsFrame.active = MakeValueSlider(page, "Bar Active", 28, -482, 350, 0, 100, 10)
	optionsFrame.inactive = MakeValueSlider(page, "Bar Inactive", 28, -540, 350, 0, 100, 10)

	-- Spells page
	spells = CreateFrame("Frame", nil, panel)
	spells:SetAllPoints(panel)
	spells:Hide()
	optionsFrame.spellsPage = spells

	MakeText(spells, "Spells", 18, -18, 14, true)

	MakeText(spells, "Filter Type", 18, -54, 12, true)
	optionsFrame.filterType = MakeBinarySlider(spells, "Blacklist", "Whitelist", 174, -80, 140)

	MakeText(spells, "Add Spell", 18, -120, 12, true)
	optionsFrame.spellAdd = MakeEditBox(spells, 28, -150, 330)
	optionsFrame.spellAdd:SetJustifyH("LEFT")
	optionsFrame.spellAdd:SetTextInsets(6, 6, 0, 0)

	addButton = MakeButton(spells, "Add", 70)
	addButton:SetPoint("TOPLEFT", spells, "TOPLEFT", 372, -149)

	MakeText(spells, "Filtered Spells", 18, -194, 12, true)

	listFrame = CreateFrame("Frame", nil, spells)
	listFrame:SetPoint("TOPLEFT", spells, "TOPLEFT", 28, -222)
	listFrame:SetWidth(440)
	listFrame:SetHeight(SPELL_ROW_HEIGHT * SPELL_VISIBLE_ROWS)
	listFrame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	listFrame:SetBackdropColor(0, 0, 0, 0.35)
	listFrame:SetBackdropBorderColor(0.22, 0.26, 0.31, 1)

	optionsFrame.spellRows = {}

	for i = 1, SPELL_VISIBLE_ROWS do
		row = CreateFrame("Frame", nil, listFrame)
		row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4 - ((i - 1) * SPELL_ROW_HEIGHT))
		row:SetWidth(410)
		row:SetHeight(SPELL_ROW_HEIGHT)

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

		row.remove = MakeButton(row, "X", 24)
		row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.remove:SetScript("OnClick", function()
			if this:GetParent().dataIndex then
				RemoveSpellAtIndex(this:GetParent().dataIndex)
				RefreshSpellRows()
				ReconcileAllCooldowns()
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
		RefreshSpellRows()
	end)

	optionsFrame.filterType:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end

		if this:GetValue() >= 0.5 then
			CoolineCharDB.filters.mode = "whitelist"
		else
			CoolineCharDB.filters.mode = "blacklist"
		end

		optionsFrame.spellOffset = 0
		RefreshSpellRows()
		ReconcileAllCooldowns()
	end)

	optionsFrame.spellAdd:SetScript("OnEnterPressed", function()
		AddSpellFromBox()
		this:ClearFocus()
	end)

	optionsFrame.spellAdd:SetScript("OnEscapePressed", function()
		this:ClearFocus()
	end)

	addButton:SetScript("OnClick", function()
		AddSpellFromBox()
	end)

	appearanceTab:SetScript("OnClick", function()
		ShowOptionsPage("appearance")
	end)

	spellsTab:SetScript("OnClick", function()
		optionsFrame.updating = true
		optionsFrame.filterType:SetValue(CoolineCharDB.filters.mode == "whitelist" and 1 or 0)
		optionsFrame.updating = false
		ShowOptionsPage("spells")
	end)


	-- Items page
	items = CreateFrame("Frame", nil, panel)
	items:SetAllPoints(panel)
	items:Hide()
	optionsFrame.itemsPage = items

	MakeText(items, "Items", 18, -18, 14, true)

	MakeText(items, "Filter Type", 18, -54, 12, true)
	optionsFrame.itemFilterType = MakeBinarySlider(items, "Blacklist", "Whitelist", 174, -80, 140)

	MakeText(items, "Add Item", 18, -120, 12, true)
	optionsFrame.itemAdd = MakeEditBox(items, 28, -150, 330)
	optionsFrame.itemAdd:SetJustifyH("LEFT")
	optionsFrame.itemAdd:SetTextInsets(6, 6, 0, 0)

	itemAddButton = MakeButton(items, "Add", 70)
	itemAddButton:SetPoint("TOPLEFT", items, "TOPLEFT", 372, -149)

	MakeText(items, "Filtered Items", 18, -194, 12, true)

	local itemListFrame = CreateFrame("Frame", nil, items)
	itemListFrame:SetPoint("TOPLEFT", items, "TOPLEFT", 28, -222)
	itemListFrame:SetWidth(440)
	itemListFrame:SetHeight(SPELL_ROW_HEIGHT * ITEM_VISIBLE_ROWS)
	itemListFrame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true, tileSize = 16, edgeSize = 10,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	itemListFrame:SetBackdropColor(0, 0, 0, 0.35)
	itemListFrame:SetBackdropBorderColor(0.22, 0.26, 0.31, 1)

	optionsFrame.itemRows = {}

	for i = 1, ITEM_VISIBLE_ROWS do
		row = CreateFrame("Frame", nil, itemListFrame)
		row:SetPoint("TOPLEFT", itemListFrame, "TOPLEFT", 4, -4 - ((i - 1) * SPELL_ROW_HEIGHT))
		row:SetWidth(410)
		row:SetHeight(SPELL_ROW_HEIGHT)

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

		row.remove = MakeButton(row, "X", 24)
		row.remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
		row.remove:SetScript("OnClick", function()
			if this:GetParent().dataIndex then
				RemoveItemAtIndex(this:GetParent().dataIndex)
				RefreshItemRows()
				ReconcileAllCooldowns()
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
		RefreshItemRows()
	end)

	optionsFrame.itemFilterType:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		if this:GetValue() >= 0.5 then
			CoolineCharDB.itemFilters.mode = "whitelist"
		else
			CoolineCharDB.itemFilters.mode = "blacklist"
		end
		optionsFrame.itemOffset = 0
		RefreshItemRows()
		ReconcileAllCooldowns()
	end)

	optionsFrame.itemAdd:SetScript("OnEnterPressed", function()
		AddItemFromBox()
		this:ClearFocus()
	end)

	optionsFrame.itemAdd:SetScript("OnEscapePressed", function()
		this:ClearFocus()
	end)

	itemAddButton:SetScript("OnClick", function()
		AddItemFromBox()
	end)

	itemsTab:SetScript("OnClick", function()
		optionsFrame.updating = true
		optionsFrame.itemFilterType:SetValue(CoolineCharDB.itemFilters.mode == "whitelist" and 1 or 0)
		optionsFrame.updating = false
		ShowOptionsPage("items")
	end)

	-- Appearance scripts
	optionsFrame.scope:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		SelectVisualScope(this:GetValue() >= 0.5)
		ApplyVisualLayout()
		RefreshAppearanceOptions()
	end)

	optionsFrame.direction:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.vertical = this:GetValue() >= 0.5
		ApplyVisualLayout()
	end)

	optionsFrame.iconDirection:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.reverse = this:GetValue() >= 0.5
		ApplyVisualLayout()
	end)

	optionsFrame.length:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.length = floor(this:GetValue() + 0.5)
		this.edit:SetText(tostring(visuals.length))
		ApplyVisualLayout()
	end)

	optionsFrame.width:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.width = floor(this:GetValue() + 0.5)
		this.edit:SetText(tostring(visuals.width))
		ApplyVisualLayout()
	end)

	optionsFrame.oversize:SetScript("OnValueChanged", function()
		local value
		if optionsFrame.updating then return end
		value = floor(this:GetValue() + 0.5)
		visuals.iconoversize = value
		if value > 0 then this.edit:SetText("+" .. value) else this.edit:SetText(tostring(value)) end
		ApplyVisualLayout()
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
		local value = ReadInteger(this, 100)
		this:ClearFocus()
		if not value then RefreshAppearanceOptions() return end
		visuals.length = value
		optionsFrame.updating = true
		optionsFrame.length:SetValue(min(value, 1000))
		optionsFrame.updating = false
		ApplyVisualLayout()
		RefreshAppearanceOptions()
	end)

	optionsFrame.width.edit:SetScript("OnEnterPressed", function()
		local value = ReadInteger(this, 2)
		this:ClearFocus()
		if not value then RefreshAppearanceOptions() return end
		visuals.width = value
		optionsFrame.updating = true
		optionsFrame.width:SetValue(min(value, 100))
		optionsFrame.updating = false
		ApplyVisualLayout()
		RefreshAppearanceOptions()
	end)

	optionsFrame.oversize.edit:SetScript("OnEnterPressed", function()
		local value = ReadInteger(this, -50)
		this:ClearFocus()
		if not value then RefreshAppearanceOptions() return end
		visuals.iconoversize = value
		optionsFrame.updating = true
		optionsFrame.oversize:SetValue(min(value, 50))
		optionsFrame.updating = false
		ApplyVisualLayout()
		RefreshAppearanceOptions()
	end)

	optionsFrame.active.edit:SetScript("OnEnterPressed", function()
		local text = string.gsub(this:GetText(), "%%", "")
		local value = tonumber(text)
		this:ClearFocus()
		if not value then RefreshAppearanceOptions() return end
		value = floor(value + 0.5)
		if value < 0 then value = 0 end
		visuals.activealpha = value / 100
		optionsFrame.updating = true
		optionsFrame.active:SetValue(min(value, 100))
		optionsFrame.updating = false
		RefreshAppearanceOptions()
	end)

	optionsFrame.inactive.edit:SetScript("OnEnterPressed", function()
		local text = string.gsub(this:GetText(), "%%", "")
		local value = tonumber(text)
		this:ClearFocus()
		if not value then RefreshAppearanceOptions() return end
		value = floor(value + 0.5)
		if value < 0 then value = 0 end
		visuals.inactivealpha = value / 100
		optionsFrame.updating = true
		optionsFrame.inactive:SetValue(min(value, 100))
		optionsFrame.updating = false
		RefreshAppearanceOptions()
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
			RefreshAppearanceOptions()
		end)
	end

	done = MakeButton(optionsFrame, "Close", 80)
	done:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -18, 12)
	done:SetScript("OnClick", function() optionsFrame:Hide() end)

	ShowOptionsPage("appearance")
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
	ReconcileAllCooldowns()

	bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	bar:RegisterEvent("SPELLS_CHANGED")
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
