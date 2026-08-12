-- Cooline 1.9.1 timeline test
-- Clean single-file rebuild for WoW 1.12.1.
-- This stage adds the real nonlinear Cooline timeline and smooth spell movement.

local VERSION = "1.9.1-appearance"

local DEFAULTS = {
	width = 360,
	height = 18,
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
local scanElapsed = 0
local SCAN_INTERVAL = 0.50
local visuals

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
	ApplyDefaults(CoolineDB.visuals, DEFAULTS)

	CoolineCharDB = CoolineCharDB or {}
	if CoolineCharDB.useCharacterVisuals == nil then
		CoolineCharDB.useCharacterVisuals = false
	end

	if CoolineCharDB.useCharacterVisuals then
		CoolineCharDB.visuals = CoolineCharDB.visuals or {}
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

local function TimelineOffset(timeLeft)
	local span
	local section

	if visuals.vertical then
		span = visuals.height
	else
		span = visuals.width
	end

	section = span / 6

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
			frame:SetPoint("CENTER", bar, "BOTTOM", 0, visuals.height - offset)
		else
			frame:SetPoint("CENTER", bar, "BOTTOM", 0, offset)
		end
	else
		if visuals.reverse then
			frame:SetPoint("CENTER", bar, "LEFT", visuals.width - offset, 0)
		else
			frame:SetPoint("CENTER", bar, "LEFT", offset, 0)
		end
	end
end

local function LayoutLabels()
	local span = visuals.vertical and visuals.height or visuals.width
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
					data.frame:SetPoint("CENTER", bar, "BOTTOM", 0, visuals.height - offset)
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
					data.frame:SetPoint("CENTER", bar, "LEFT", visuals.width - offset, 0)
				else
					data.frame:SetPoint("CENTER", bar, "LEFT", offset, 0)
				end
			end
		end
	end
end

local function ApplyVisualLayout()
	local size
	local name, cd

	bar:SetWidth(visuals.width)
	bar:SetHeight(visuals.height)
	bar:ClearAllPoints()
	bar:SetPoint("CENTER", UIParent, "CENTER", visuals.x, visuals.y)

	if visuals.vertical then
		size = visuals.width + 4
		bar.bg:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	else
		size = visuals.height + 4
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

	bar:SetWidth(s.width)
	bar:SetHeight(s.height)
	bar:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
	bar:SetMovable(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
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

	bar:SetScript("OnDragStart", function()
		if IsAltKeyDown() then
			this:StartMoving()
		end
	end)

	bar:SetScript("OnDragStop", function()
		local x, y, ux, uy
		this:StopMovingOrSizing()
		x, y = this:GetCenter()
		ux, uy = UIParent:GetCenter()

		if x and y and ux and uy then
			visuals.x = floor(x - ux + 0.5)
			visuals.y = floor(y - uy + 0.5)
		end
	end)

	initialised = true
end

local function GetSpellCount()
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

local function EnsureCooldown(name)
	local cd = cooldowns[name]
	local size

	if not cd then
		cd = CreateFrame("Frame", nil, bar.border)
		if visuals.vertical then
			size = visuals.width + 4
		else
			size = visuals.height + 4
		end
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

		cooldowns[name] = cd
	end

	return cd
end

local function ScanSpells()
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

			if enabled == 1 and duration and duration > 2.5 then
				if (startTime + duration) > now then
					cd = EnsureCooldown(name)
					texture = GetSpellTexture(id, BOOKTYPE_SPELL)

					cd.startTime = startTime
					cd.duration = duration
					cd.endTime = startTime + duration
					cd.icon:SetTexture(texture)
					cd:Show()
					seen[name] = true
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
-- Appearance options
-- ============================================================================

local optionsFrame
local sliderCount = 0

local function MakeButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetWidth(width)
	button:SetHeight(22)
	button:SetText(text)
	return button
end

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

local function MakeSlider(parent, text, x, y, width, low, high, step)
	local name
	local slider

	sliderCount = sliderCount + 1
	name = "CoolineAppearanceSlider" .. sliderCount

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
	local panel
	local reset
	local done

	if optionsFrame then
		return
	end

	optionsFrame = CreateFrame("Frame", "CoolineOptionsFrame", UIParent)
	optionsFrame:SetWidth(500)
	optionsFrame:SetHeight(350)
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

	MakeText(optionsFrame, "Cooline", 18, -16, 14, true)
	MakeText(optionsFrame, "v1.9.1", 75, -18, 10, false)

	close = MakeButton(optionsFrame, "X", 24)
	close:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", -12, -11)
	close:SetScript("OnClick", function() optionsFrame:Hide() end)

	panel = CreateFrame("Frame", nil, optionsFrame)
	panel:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 16, -48)
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

	MakeText(panel, "Appearance", 18, -18, 14, true)
	optionsFrame.scope = MakeText(panel, "", 18, -45, 11, false)

	optionsFrame.characterVisuals = MakeCheckbox(
		panel,
		"Use character-specific appearance",
		18,
		-67
	)

	MakeText(panel, "Size", 18, -108, 12, true)
	optionsFrame.width = MakeSlider(panel, "Width", 28, -140, 240, 120, 720, 1)
	optionsFrame.height = MakeSlider(panel, "Height", 28, -188, 240, 8, 48, 1)

	MakeText(panel, "Layout", 320, -108, 12, true)
	optionsFrame.vertical = MakeCheckbox(panel, "Vertical", 320, -137)
	optionsFrame.reverse = MakeCheckbox(panel, "Reverse direction", 320, -168)

	MakeText(panel, "Opacity", 18, -232, 12, true)
	optionsFrame.activeAlpha = MakeSlider(panel, "Active", 28, -264, 240, 10, 100, 5)
	optionsFrame.inactiveAlpha = MakeSlider(panel, "Inactive", 28, -312, 240, 0, 100, 5)

	reset = MakeButton(optionsFrame, "Reset Appearance", 130)
	reset:SetPoint("BOTTOMLEFT", optionsFrame, "BOTTOMLEFT", 18, 12)

	done = MakeButton(optionsFrame, "Close", 80)
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
			CoolineCharDB.visuals = {}
			ApplyDefaults(CoolineCharDB.visuals, DEFAULTS)
			visuals = CoolineCharDB.visuals
		else
			CoolineDB.visuals = {}
			ApplyDefaults(CoolineDB.visuals, DEFAULTS)
			visuals = CoolineDB.visuals
		end

		visuals.x = x
		visuals.y = y

		ApplyVisualLayout()
		RefreshOptions()
	end)
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

local function OnVariablesLoaded()
	InitialiseSettings()
	BuildBar()
	BuildOptions()
	ScanSpells()

	bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	bar:RegisterEvent("SPELLS_CHANGED")
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
		ScanSpells()
	end
end)

bar:SetScript("OnUpdate", function()
	if not initialised then
		return
	end

	scanElapsed = scanElapsed + arg1
	if scanElapsed >= SCAN_INTERVAL then
		scanElapsed = 0
		ScanSpells()
	end

	Render()
end)
