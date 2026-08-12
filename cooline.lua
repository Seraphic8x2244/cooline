--[[
	Cooline 1.9.1
	Clean single-file rebuild for World of Warcraft 1.12.1.

	Design goals:
	- Keep the original Cooline timeline concept and appearance.
	- Do not rely on fragile cached event state.
	- Reconcile cooldown state periodically so missed events self-repair.
	- Keep account-wide visuals with an optional per-character visual override.
	- Keep cooldown filters per character.
]]

local VERSION = "1.9.1"

-- ============================================================================
-- Defaults and SavedVariables
-- ============================================================================

local DEFAULT_VISUALS = {
	vertical = false,
	reverse = false,
	width = 360,
	height = 18,
	x = 0,
	y = -240,

	statusbar = [[Interface\TargetingFrame\UI-StatusBar]],
	bgcolor = { 0, 0, 0, 0.5 },

	border = [[Interface\DialogFrame\UI-DialogBox-Border]],
	bordersize = 16,
	borderinset = 4,
	bordercolor = { 1, 1, 1, 1 },

	iconoutset = 2,

	font = [[Fonts\FRIZQT__.TTF]],
	fontsize = 10,
	fontcolor = { 1, 1, 1, 0.8 },

	spellcolor = { 0.8, 0.4, 0, 1 },
	itemcolor = { 0, 0, 0, 1 },

	inactivealpha = 0.5,
	activealpha = 1.0,

	overlapThreshold = 3.0,
}

local function CopyTable(source)
	local result = {}
	local key, value

	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = CopyTable(value)
		else
			result[key] = value
		end
	end

	return result
end

local function ApplyDefaults(target, defaults)
	local key, value

	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = CopyTable(value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			ApplyDefaults(target[key], value)
		end
	end
end

local visuals

local function InitialiseSavedVariables()
	CoolineDB = CoolineDB or {}
	CoolineDB.visuals = CoolineDB.visuals or {}
	ApplyDefaults(CoolineDB.visuals, DEFAULT_VISUALS)

	CoolineCharDB = CoolineCharDB or {}

	if CoolineCharDB.useCharacterVisuals == nil then
		CoolineCharDB.useCharacterVisuals = false
	end

	CoolineCharDB.filters = CoolineCharDB.filters or {}

	if CoolineCharDB.filters.mode == nil then
		CoolineCharDB.filters.mode = "blacklist"
	end
	if CoolineCharDB.filters.blacklist == nil then
		CoolineCharDB.filters.blacklist = { "Hearthstone" }
	end
	if CoolineCharDB.filters.whitelist == nil then
		CoolineCharDB.filters.whitelist = {}
	end

	if CoolineCharDB.useCharacterVisuals then
		if not CoolineCharDB.visuals then
			CoolineCharDB.visuals = CopyTable(CoolineDB.visuals)
		end
		ApplyDefaults(CoolineCharDB.visuals, DEFAULT_VISUALS)
		visuals = CoolineCharDB.visuals
	else
		visuals = CoolineDB.visuals
	end
end

local function SelectVisualScope(useCharacter)
	if useCharacter then
		if not CoolineCharDB.visuals then
			CoolineCharDB.visuals = CopyTable(CoolineDB.visuals)
		end
		ApplyDefaults(CoolineCharDB.visuals, DEFAULT_VISUALS)
		CoolineCharDB.useCharacterVisuals = true
		visuals = CoolineCharDB.visuals
	else
		CoolineCharDB.useCharacterVisuals = false
		visuals = CoolineDB.visuals
	end
end

-- ============================================================================
-- Filter helpers
-- ============================================================================

local function ListContains(list, name)
	local index, entry

	if not name or not list then
		return false
	end

	for index, entry in ipairs(list) do
		if type(entry) == "string" and strupper(entry) == strupper(name) then
			return true
		end
	end

	return false
end

local function CooldownAllowed(name)
	local filters

	if not name or name == "" then
		return false
	end

	filters = CoolineCharDB.filters

	if filters.mode == "whitelist" then
		return ListContains(filters.whitelist, name)
	end

	return not ListContains(filters.blacklist, name)
end

-- ============================================================================
-- Core state
-- ============================================================================

local bar = CreateFrame("Button", "CoolineBar", UIParent)
local active = {}
local framePool = {}
local initialised = false
local optionsFrame

local scanElapsed = 0
local renderElapsed = 0
local SCAN_INTERVAL = 0.50
local RENDER_INTERVAL_IDLE = 0.10

local placeFrame
local sectionSize = 60
local iconSize = 20

-- ============================================================================
-- Timeline layout
-- ============================================================================

local function PlaceHorizontal(frame, offset, justify)
	frame:ClearAllPoints()
	frame:SetPoint(justify or "CENTER", bar, "LEFT", offset, 0)
end

local function PlaceHorizontalReverse(frame, offset, justify)
	frame:ClearAllPoints()
	frame:SetPoint(justify or "CENTER", bar, "LEFT", visuals.width - offset, 0)
end

local function PlaceVertical(frame, offset, justify)
	frame:ClearAllPoints()
	frame:SetPoint(justify or "CENTER", bar, "BOTTOM", 0, offset)
end

local function PlaceVerticalReverse(frame, offset, justify)
	frame:ClearAllPoints()
	frame:SetPoint(justify or "CENTER", bar, "BOTTOM", 0, visuals.height - offset)
end

local function TimelineOffset(timeLeft)
	if timeLeft <= 0 then
		return 0
	elseif timeLeft < 1 then
		return sectionSize * timeLeft
	elseif timeLeft < 3 then
		return sectionSize * (1 + ((timeLeft - 1) / 2))
	elseif timeLeft < 10 then
		return sectionSize * (2 + ((timeLeft - 3) / 7))
	elseif timeLeft < 30 then
		return sectionSize * (3 + ((timeLeft - 10) / 20))
	elseif timeLeft < 120 then
		return sectionSize * (4 + ((timeLeft - 30) / 90))
	elseif timeLeft < 360 then
		return sectionSize * (5 + ((timeLeft - 120) / 240))
	end

	return sectionSize * 6
end

local function LayoutLabel(label, offset, edge)
	local justify = edge

	label:SetFont(visuals.font, visuals.fontsize)
	label:SetTextColor(unpack(visuals.fontcolor))
	label:SetWidth(visuals.fontsize * 3)
	label:SetHeight(visuals.fontsize + 2)
	label:SetShadowColor(unpack(visuals.bgcolor))
	label:SetShadowOffset(1, -1)
	label:SetJustifyH("CENTER")

	if edge then
		if visuals.vertical then
			if visuals.reverse then
				if edge == "LEFT" then
					justify = "TOP"
				else
					justify = "BOTTOM"
				end
			else
				if edge == "LEFT" then
					justify = "BOTTOM"
				else
					justify = "TOP"
				end
			end
		else
			if visuals.reverse then
				if edge == "LEFT" then
					justify = "RIGHT"
				else
					justify = "LEFT"
				end
			else
				justify = edge
			end

			if justify == "LEFT" then
				offset = offset + 1
			else
				offset = offset - 1
			end

			label:SetJustifyH(justify)
		end
	end

	placeFrame(label, offset, justify)
end

local function ApplyVisualLayout()
	local frame

	if not initialised then
		return
	end

	bar:SetWidth(visuals.width)
	bar:SetHeight(visuals.height)
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", UIParent, "CENTER", visuals.x, visuals.y)

	if visuals.vertical then
		placeFrame = visuals.reverse and PlaceVerticalReverse or PlaceVertical
		sectionSize = visuals.height / 6
		iconSize = visuals.width + (visuals.iconoutset * 2)
		bar.bg:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	else
		placeFrame = visuals.reverse and PlaceHorizontalReverse or PlaceHorizontal
		sectionSize = visuals.width / 6
		iconSize = visuals.height + (visuals.iconoutset * 2)
		bar.bg:SetTexCoord(0, 1, 0, 1)
	end

	LayoutLabel(bar.tick0, 0, "LEFT")
	LayoutLabel(bar.tick1, sectionSize)
	LayoutLabel(bar.tick3, sectionSize * 2)
	LayoutLabel(bar.tick10, sectionSize * 3)
	LayoutLabel(bar.tick30, sectionSize * 4)
	LayoutLabel(bar.tick120, sectionSize * 5)
	LayoutLabel(bar.tick360, sectionSize * 6, "RIGHT")

	for _, frame in pairs(active) do
		frame:SetWidth(iconSize)
		frame:SetHeight(iconSize)
	end

	for _, frame in ipairs(framePool) do
		frame:SetWidth(iconSize)
		frame:SetHeight(iconSize)
	end
end

-- ============================================================================
-- Cooldown frames
-- ============================================================================

local function CreateCooldownFrame()
	local frame = CreateFrame("Frame", nil, bar.border)

	frame:SetBackdrop({
		bgFile = [[Interface\AddOns\Cooline\artwork\backdrop.tga]]
	})

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	frame.icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

	frame:Hide()
	return frame
end

local function AcquireFrame()
	local count = table.getn(framePool)
	local frame

	if count > 0 then
		frame = framePool[count]
		framePool[count] = nil
	else
		frame = CreateCooldownFrame()
	end

	frame:SetWidth(iconSize)
	frame:SetHeight(iconSize)
	frame:SetAlpha(1)
	return frame
end

local function ReleaseCooldown(key)
	local cooldown = active[key]

	if not cooldown then
		return
	end

	cooldown.frame:Hide()
	cooldown.frame.key = nil
	cooldown.frame.endTime = nil
	tinsert(framePool, cooldown.frame)
	active[key] = nil
end

local function StartOrUpdateCooldown(key, name, texture, startTime, duration, kind)
	local cooldown
	local endTime

	if not CooldownAllowed(name) then
		ReleaseCooldown(key)
		return
	end

	if not startTime or not duration or duration <= 0 then
		ReleaseCooldown(key)
		return
	end

	endTime = startTime + duration
	cooldown = active[key]

	if not cooldown then
		cooldown = {
			key = key,
			name = name,
			kind = kind,
			frame = AcquireFrame(),
		}
		active[key] = cooldown
	end

	cooldown.name = name
	cooldown.kind = kind
	cooldown.startTime = startTime
	cooldown.duration = duration
	cooldown.endTime = endTime
	cooldown.seen = true

	cooldown.frame.key = key
	cooldown.frame.endTime = endTime
	cooldown.frame.icon:SetTexture(texture)

	if kind == "spell" then
		cooldown.frame:SetBackdropColor(unpack(visuals.spellcolor))
	else
		cooldown.frame:SetBackdropColor(unpack(visuals.itemcolor))
	end

	cooldown.frame:Show()
end

-- ============================================================================
-- Cooldown scanning
-- ============================================================================

local function SafeItemName(link)
	local _, _, name

	if not link or type(link) ~= "string" then
		return nil
	end

	_, _, name = strfind(link, "|h%[([^]]+)%]|h")
	return name
end

local function MarkAllUnseen()
	local _, cooldown

	for _, cooldown in pairs(active) do
		cooldown.seen = false
	end
end

local function ScanBags()
	local bag, slot
	local slots
	local startTime, duration, enabled
	local link, name, texture

	for bag = 0, 4 do
		slots = GetContainerNumSlots(bag) or 0

		for slot = 1, slots do
			startTime, duration, enabled = GetContainerItemCooldown(bag, slot)

			if enabled == 1 and duration and duration > 3 and duration < 3601 then
				link = GetContainerItemLink(bag, slot)
				name = SafeItemName(link)

				if name then
					texture = GetContainerItemInfo(bag, slot)
					StartOrUpdateCooldown(
						"bag:" .. name,
						name,
						texture,
						startTime,
						duration,
						"item"
					)
				end
			end
		end
	end
end

local function ScanEquipment()
	local slot
	local startTime, duration, enabled
	local link, name, texture

	for slot = 0, 19 do
		startTime, duration, enabled = GetInventoryItemCooldown("player", slot)

		if enabled == 1 and duration and duration > 3 and duration < 3601 then
			link = GetInventoryItemLink("player", slot)
			name = SafeItemName(link)

			if name then
				texture = GetInventoryItemTexture("player", slot)
				StartOrUpdateCooldown(
					"equipped:" .. name,
					name,
					texture,
					startTime,
					duration,
					"item"
				)
			end
		end
	end
end

local function GetSpellbookCount()
	local tabs = GetNumSpellTabs() or 0
	local tab
	local _, _, offset, count
	local highest = 0
	local total

	for tab = 1, tabs do
		_, _, offset, count = GetSpellTabInfo(tab)

		if offset and count then
			total = offset + count
			if total > highest then
				highest = total
			end
		end
	end

	return highest
end

local function ScanSpells()
	local spellCount = GetSpellbookCount()
	local id
	local name, rank, texture
	local startTime, duration, enabled
	local key

	for id = 1, spellCount do
		name, rank = GetSpellName(id, BOOKTYPE_SPELL)

		if name then
			startTime, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)

			-- >2.5s deliberately excludes the normal global cooldown.
			if enabled == 1 and duration and duration > 2.5 then
				texture = GetSpellTexture(id, BOOKTYPE_SPELL)

				-- All ranks of the same spell share one Cooline entry. Vanilla
				-- can report the same cooldown on multiple learned ranks.
				key = "spell:" .. name

				StartOrUpdateCooldown(
					key,
					name,
					texture,
					startTime,
					duration,
					"spell"
				)
			end
		end
	end
end

local function ReconcileCooldowns()
	local key, cooldown
	local now = GetTime()

	if not initialised then
		return
	end

	MarkAllUnseen()

	ScanSpells()
	ScanBags()
	ScanEquipment()

	-- Anything that was active on the previous scan but cannot be found now
	-- has ended, disappeared, or changed. Remove it cleanly.
	for key, cooldown in pairs(active) do
		if not cooldown.seen or cooldown.endTime <= now - 0.25 then
			ReleaseCooldown(key)
		end
	end
end

-- ============================================================================
-- Rendering
-- ============================================================================

local function SortByEndTime(a, b)
	return a.endTime < b.endTime
end

local function RenderCooldowns()
	local now = GetTime()
	local list = {}
	local _, cooldown
	local index
	local timeLeft
	local offset
	local size
	local anyActive = false

	for _, cooldown in pairs(active) do
		tinsert(list, cooldown)
	end

	table.sort(list, SortByEndTime)

	for index, cooldown in ipairs(list) do
		timeLeft = cooldown.endTime - now

		if timeLeft <= -0.25 then
			ReleaseCooldown(cooldown.key)
		else
			anyActive = true
			offset = TimelineOffset(timeLeft)

			if timeLeft < 0 then
				cooldown.frame:SetAlpha(max(0, 1 + (timeLeft * 4)))
			else
				cooldown.frame:SetAlpha(1)
			end

			if timeLeft >= 0 and timeLeft < 0.3 then
				size = iconSize * (0.5 - timeLeft) * 5
				if size < iconSize then
					size = iconSize
				end
				cooldown.frame:SetWidth(size)
				cooldown.frame:SetHeight(size)
			else
				cooldown.frame:SetWidth(iconSize)
				cooldown.frame:SetHeight(iconSize)
			end

			-- Deterministic frame levels replace the original random re-leveling.
			cooldown.frame:SetFrameLevel(index + 2)
			placeFrame(cooldown.frame, offset)
		end
	end

	bar:SetAlpha(anyActive and visuals.activealpha or visuals.inactivealpha)
end

-- ============================================================================
-- Bar construction and movement
-- ============================================================================

local function CreateLabel(text)
	local label = bar.overlay:CreateFontString(nil, "OVERLAY")
	label:SetText(text)
	return label
end

local function StopDragging()
	local x, y
	local ux, uy

	bar:StopMovingOrSizing()

	x, y = bar:GetCenter()
	ux, uy = UIParent:GetCenter()

	if x and y and ux and uy then
		visuals.x = floor(x - ux + 0.5)
		visuals.y = floor(y - uy + 0.5)
	end

	bar.dragging = false
end

local function BuildBar()
	bar:SetClampedToScreen(true)
	bar:SetMovable(true)
	bar:RegisterForDrag("LeftButton")

	bar.bg = bar:CreateTexture(nil, "ARTWORK")
	bar.bg:SetTexture(visuals.statusbar)
	bar.bg:SetVertexColor(unpack(visuals.bgcolor))
	bar.bg:SetAllPoints(bar)

	bar.border = CreateFrame("Frame", nil, bar)
	bar.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -visuals.borderinset, visuals.borderinset)
	bar.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", visuals.borderinset, -visuals.borderinset)
	bar.border:SetBackdrop({
		edgeFile = visuals.border,
		edgeSize = visuals.bordersize,
	})
	bar.border:SetBackdropBorderColor(unpack(visuals.bordercolor))

	bar.overlay = CreateFrame("Frame", nil, bar.border)
	bar.overlay:SetAllPoints(bar.border)
	bar.overlay:SetFrameLevel(24)

	-- Select a placement function before labels are positioned.
	if visuals.vertical then
		placeFrame = visuals.reverse and PlaceVerticalReverse or PlaceVertical
	else
		placeFrame = visuals.reverse and PlaceHorizontalReverse or PlaceHorizontal
	end

	bar.tick0 = CreateLabel("0")
	bar.tick1 = CreateLabel("1")
	bar.tick3 = CreateLabel("3")
	bar.tick10 = CreateLabel("10")
	bar.tick30 = CreateLabel("30")
	bar.tick120 = CreateLabel("2m")
	bar.tick360 = CreateLabel("6m")

	initialised = true
	ApplyVisualLayout()

	bar:SetScript("OnDragStart", function()
		if IsAltKeyDown() then
			this.dragging = true
			this:StartMoving()
		end
	end)

	bar:SetScript("OnDragStop", function()
		StopDragging()
	end)
end

-- ============================================================================
-- Options UI
-- ============================================================================

local function MakeButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetWidth(width)
	button:SetHeight(22)
	button:SetText(text)
	return button
end

local function MakeText(parent, text, x, y, size, colour)
	local fontString = parent:CreateFontString(nil, "OVERLAY")
	fontString:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	fontString:SetFont([[Fonts\FRIZQT__.TTF]], size or 11)

	if colour == "title" then
		fontString:SetTextColor(1, 0.82, 0)
	elseif colour == "muted" then
		fontString:SetTextColor(0.65, 0.70, 0.76)
	else
		fontString:SetTextColor(0.9, 0.9, 0.9)
	end

	fontString:SetText(text or "")
	return fontString
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

local sliderNumber = 0

local function MakeSlider(parent, text, x, y, width, low, high, step)
	local slider
	local name

	sliderNumber = sliderNumber + 1
	name = "CoolineSlider" .. sliderNumber

	slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
	slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	slider:SetWidth(width)
	slider:SetHeight(16)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)

	getglobal(name .. "Text"):SetText(text)
	getglobal(name .. "Low"):SetText(tostring(low))
	getglobal(name .. "High"):SetText(tostring(high))

	slider.valueText = parent:CreateFontString(nil, "OVERLAY")
	slider.valueText:SetPoint("LEFT", slider, "RIGHT", 10, 0)
	slider.valueText:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	slider.valueText:SetTextColor(0.9, 0.9, 0.9)

	return slider
end

local function RefreshOptions()
	if not optionsFrame then
		return
	end

	optionsFrame.updating = true

	optionsFrame.characterVisuals:SetChecked(CoolineCharDB.useCharacterVisuals and 1 or nil)

	if CoolineCharDB.useCharacterVisuals then
		optionsFrame.scope:SetText("Editing: this character")
	else
		optionsFrame.scope:SetText("Editing: account-wide")
	end

	optionsFrame.width:SetValue(visuals.width)
	optionsFrame.width.valueText:SetText(tostring(visuals.width))

	optionsFrame.height:SetValue(visuals.height)
	optionsFrame.height.valueText:SetText(tostring(visuals.height))

	optionsFrame.vertical:SetChecked(visuals.vertical and 1 or nil)
	optionsFrame.reverse:SetChecked(visuals.reverse and 1 or nil)

	optionsFrame.activeAlpha:SetValue(floor((visuals.activealpha * 100) + 0.5))
	optionsFrame.activeAlpha.valueText:SetText(floor((visuals.activealpha * 100) + 0.5) .. "%")

	optionsFrame.inactiveAlpha:SetValue(floor((visuals.inactivealpha * 100) + 0.5))
	optionsFrame.inactiveAlpha.valueText:SetText(floor((visuals.inactivealpha * 100) + 0.5) .. "%")

	optionsFrame.updating = false
end

local function BuildOptions()
	local close
	local appearanceTab, cooldownsTab, advancedTab
	local panel
	local page
	local placeholder
	local reset

	if optionsFrame then
		return
	end

	optionsFrame = CreateFrame("Frame", "CoolineOptionsFrame", UIParent)
	optionsFrame:SetWidth(520)
	optionsFrame:SetHeight(400)
	optionsFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	optionsFrame:SetFrameStrata("DIALOG")
	optionsFrame:SetMovable(true)
	optionsFrame:EnableMouse(true)
	optionsFrame:RegisterForDrag("LeftButton")
	optionsFrame:SetScript("OnDragStart", function() this:StartMoving() end)
	optionsFrame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
	optionsFrame:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true,
		tileSize = 32,
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	optionsFrame:SetBackdropColor(0.08, 0.10, 0.13, 0.98)
	optionsFrame:SetBackdropBorderColor(0.45, 0.52, 0.60, 1)
	optionsFrame:Hide()

	MakeText(optionsFrame, "Cooline", 18, -16, 14, "title")
	MakeText(optionsFrame, "v" .. VERSION, 75, -18, 10, "muted")

	close = MakeButton(optionsFrame, "X", 24)
	close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -11)
	close:SetScript("OnClick", function() optionsFrame:Hide() end)

	appearanceTab = MakeButton(optionsFrame, "Appearance", 105)
	appearanceTab:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 18, -45)

	cooldownsTab = MakeButton(optionsFrame, "Cooldowns", 105)
	cooldownsTab:SetPoint("LEFT", appearanceTab, "RIGHT", 4, 0)

	advancedTab = MakeButton(optionsFrame, "Advanced", 105)
	advancedTab:SetPoint("LEFT", cooldownsTab, "RIGHT", 4, 0)

	panel = CreateFrame("Frame", nil, optionsFrame)
	panel:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 16, -76)
	panel:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -16, 42)
	panel:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	panel:SetBackdropColor(0.04, 0.05, 0.07, 0.88)
	panel:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)

	page = CreateFrame("Frame", nil, panel)
	page:SetAllPoints(panel)
	optionsFrame.appearancePage = page

	placeholder = CreateFrame("Frame", nil, panel)
	placeholder:SetAllPoints(panel)
	placeholder:Hide()
	optionsFrame.placeholderPage = placeholder
	optionsFrame.placeholderTitle = MakeText(placeholder, "", 18, -20, 14, "title")
	MakeText(placeholder, "Reserved for a later 1.9.x build.", 18, -48, 11)

	local function ShowPage(which)
		page:Hide()
		placeholder:Hide()

		if which == "appearance" then
			page:Show()
		elseif which == "cooldowns" then
			optionsFrame.placeholderTitle:SetText("Cooldowns")
			placeholder:Show()
		else
			optionsFrame.placeholderTitle:SetText("Advanced")
			placeholder:Show()
		end
	end

	appearanceTab:SetScript("OnClick", function() ShowPage("appearance") end)
	cooldownsTab:SetScript("OnClick", function() ShowPage("cooldowns") end)
	advancedTab:SetScript("OnClick", function() ShowPage("advanced") end)

	MakeText(page, "Appearance", 18, -18, 14, "title")
	optionsFrame.scope = MakeText(page, "", 18, -45, 11)

	optionsFrame.characterVisuals = MakeCheckbox(
		page,
		"Use character-specific appearance",
		18,
		-67
	)

	MakeText(page, "Size", 18, -108, 12, "title")
	optionsFrame.width = MakeSlider(page, "Width", 28, -140, 250, 120, 720, 1)
	optionsFrame.height = MakeSlider(page, "Height", 28, -188, 250, 8, 48, 1)

	MakeText(page, "Layout", 330, -108, 12, "title")
	optionsFrame.vertical = MakeCheckbox(page, "Vertical", 330, -137)
	optionsFrame.reverse = MakeCheckbox(page, "Reverse direction", 330, -168)

	MakeText(page, "Opacity", 18, -232, 12, "title")
	optionsFrame.activeAlpha = MakeSlider(page, "Active", 28, -264, 250, 10, 100, 5)
	optionsFrame.inactiveAlpha = MakeSlider(page, "Inactive", 28, -312, 250, 0, 100, 5)

	reset = MakeButton(optionsFrame, "Reset Appearance", 130)
	reset:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 18, 12)

	local done = MakeButton(optionsFrame, "Close", 80)
	done:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -18, 12)
	done:SetScript("OnClick", function() optionsFrame:Hide() end)

	optionsFrame.characterVisuals:SetScript("OnClick", function()
		SelectVisualScope(this:GetChecked() and true or false)
		ApplyVisualLayout()
		RefreshOptions()
	end)

	optionsFrame.width:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.width = floor(this:GetValue() + 0.5)
		this.valueText:SetText(tostring(visuals.width))
		ApplyVisualLayout()
	end)

	optionsFrame.height:SetScript("OnValueChanged", function()
		if optionsFrame.updating then return end
		visuals.height = floor(this:GetValue() + 0.5)
		this.valueText:SetText(tostring(visuals.height))
		ApplyVisualLayout()
	end)

	optionsFrame.vertical:SetScript("OnClick", function()
		visuals.vertical = this:GetChecked() and true or false
		ApplyVisualLayout()
	end)

	optionsFrame.reverse:SetScript("OnClick", function()
		visuals.reverse = this:GetChecked() and true or false
		ApplyVisualLayout()
	end)

	optionsFrame.activeAlpha:SetScript("OnValueChanged", function()
		local value
		if optionsFrame.updating then return end
		value = floor(this:GetValue() + 0.5)
		visuals.activealpha = value / 100
		this.valueText:SetText(value .. "%")
	end)

	optionsFrame.inactiveAlpha:SetScript("OnValueChanged", function()
		local value
		if optionsFrame.updating then return end
		value = floor(this:GetValue() + 0.5)
		visuals.inactivealpha = value / 100
		this.valueText:SetText(value .. "%")
	end)

	reset:SetScript("OnClick", function()
		local x = visuals.x
		local y = visuals.y

		if CoolineCharDB.useCharacterVisuals then
			CoolineCharDB.visuals = CopyTable(DEFAULT_VISUALS)
			visuals = CoolineCharDB.visuals
		else
			CoolineDB.visuals = CopyTable(DEFAULT_VISUALS)
			visuals = CoolineDB.visuals
		end

		-- Reset visual appearance without unexpectedly moving the bar.
		visuals.x = x
		visuals.y = y

		ApplyVisualLayout()
		RefreshOptions()
	end)

	ShowPage("appearance")
end

local function ToggleOptions()
	BuildOptions()

	if optionsFrame:IsShown() then
		optionsFrame:Hide()
	else
		RefreshOptions()
		optionsFrame:Show()
	end
end

SLASH_COOLINE1 = "/cooline"
SlashCmdList["COOLINE"] = function(msg)
	ToggleOptions()
end

-- ============================================================================
-- Events and update loop
-- ============================================================================

local function OnVariablesLoaded()
	InitialiseSavedVariables()
	BuildBar()
	BuildOptions()

	bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	bar:RegisterEvent("BAG_UPDATE_COOLDOWN")
	bar:RegisterEvent("PLAYER_ENTERING_WORLD")
	bar:RegisterEvent("SPELLS_CHANGED")
	bar:RegisterEvent("BAG_UPDATE")
	bar:RegisterEvent("UNIT_INVENTORY_CHANGED")

	ReconcileCooldowns()

	DEFAULT_CHAT_FRAME:AddMessage(
		"|c00ffff00Cooline " .. VERSION ..
		" loaded: hold <alt> and left-drag the bar to move it.|r"
	)
end

bar:RegisterEvent("VARIABLES_LOADED")

bar:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		OnVariablesLoaded()
	elseif initialised then
		-- Events request an immediate reconciliation. The periodic scan below
		-- remains the safety net if an event is missed by the client/server.
		ReconcileCooldowns()
	end
end)

bar:SetScript("OnUpdate", function()
	local elapsed = arg1 or 0

	if not initialised then
		return
	end

	bar:EnableMouse(IsAltKeyDown())

	if bar.dragging and not IsAltKeyDown() then
		StopDragging()
	end

	scanElapsed = scanElapsed + elapsed
	renderElapsed = renderElapsed + elapsed

	if scanElapsed >= SCAN_INTERVAL then
		scanElapsed = 0
		ReconcileCooldowns()
	end

	if renderElapsed >= RENDER_INTERVAL_IDLE then
		renderElapsed = 0
		RenderCooldowns()
	end
end)
