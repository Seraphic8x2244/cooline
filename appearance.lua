local L = CoolineLocale and CoolineLocale.Text or function(text) return text end
local setupComplete = false
local overlay
local dropdown
local fontPopup
local lastFontKey
local syncElapsed = 0

local FONT_CHOICES = {
	{ key = "default", name = L("Client Default") },
	{ key = "friz", name = "Friz Quadrata", path = [[Fonts\FRIZQT__.TTF]] },
	{ key = "arial", name = "Arial Narrow", path = [[Fonts\ARIALN.TTF]] },
	{ key = "morpheus", name = "Morpheus", path = [[Fonts\MORPHEUS.TTF]] },
	{ key = "skurri", name = "Skurri", path = [[Fonts\skurri.ttf]] },
}

local function GetVisuals()
	if CoolineCharDB and CoolineCharDB.useCharacterVisuals and CoolineCharDB.visuals then
		return CoolineCharDB.visuals
	end
	return CoolineDB and CoolineDB.visuals
end

local function GetFontEntry(key)
	local i
	for i = 1, table.getn(FONT_CHOICES) do
		if FONT_CHOICES[i].key == key then
			return FONT_CHOICES[i]
		end
	end
	return FONT_CHOICES[1]
end

local function GetClientDefaultFont()
	local path

	-- Use the font the client is actually using for Blizzard UI text first.
	-- This also respects UI replacements which alter the standard GameFont.
	if GameFontNormal and GameFontNormal.GetFont then
		path = GameFontNormal:GetFont()
	end

	return path or STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]
end

local function GetFontPath(key)
	local entry = GetFontEntry(key)
	return entry.path or GetClientDefaultFont()
end

local function EnsureFontDefaults()
	if CoolineDB and CoolineDB.visuals and CoolineDB.visuals.barfont == nil then
		CoolineDB.visuals.barfont = "default"
	end
	if CoolineCharDB and CoolineCharDB.visuals and CoolineCharDB.visuals.barfont == nil then
		CoolineCharDB.visuals.barfont = CoolineDB and CoolineDB.visuals and CoolineDB.visuals.barfont or "default"
	end
end

local function GetFontKey()
	local visuals = GetVisuals()
	local key = visuals and visuals.barfont or "default"
	return GetFontEntry(key).key
end

local function ApplyFont(fontString, path, size)
	if not fontString or not fontString.SetFont then return end

	fontString:SetFont(path, size)
	if not fontString:GetFont() then
		fontString:SetFont(GetClientDefaultFont(), size)
	end
end

local function ApplyTimelineFont()
	local key = GetFontKey()
	local path = GetFontPath(key)
	local bar = getglobal("CoolineBar")
	local i
	local data

	-- Apply to the actual visible overlay labels.
	if overlay and overlay.labels then
		for i = 1, table.getn(overlay.labels) do
			ApplyFont(overlay.labels[i], path, 10)
		end
	end

	-- Keep the original timeline regions in sync as well. They are hidden
	-- layout anchors in 1.9.x, but updating both removes any dependency on
	-- which set of labels a 1.12-derived client happens to render.
	if bar and bar.labels then
		for i = 1, table.getn(bar.labels) do
			data = bar.labels[i]
			if data and data.frame then
				ApplyFont(data.frame, path, 10)
			end
		end
	end

	lastFontKey = key
end

local function BuildLabelOverlay()
	local bar = getglobal("CoolineBar")
	local i
	local data
	local label

	if overlay or not bar or not bar.labels then return end

	overlay = CreateFrame("Frame", nil, bar)
	overlay:SetAllPoints(bar)
	overlay:SetFrameLevel(1000)
	overlay.labels = {}
	bar.labelOverlay = overlay

	for i = 1, table.getn(bar.labels) do
		data = bar.labels[i]
		if data and data.frame then
			label = overlay:CreateFontString(nil, "OVERLAY")
			label:SetPoint("CENTER", data.frame, "CENTER", 0, 0)
			label:SetWidth(30)
			label:SetHeight(12)
			label:SetJustifyH("CENTER")
			label:SetTextColor(1, 1, 1, 0.8)
			label:SetShadowColor(0, 0, 0, 0.5)
			label:SetShadowOffset(1, -1)
			label:SetText(data.frame:GetText() or "")
			tinsert(overlay.labels, label)

			-- Keep the original regions as invisible layout anchors. The main
			-- addon can continue repositioning them while this higher frame level
			-- guarantees the visible labels draw over every cooldown icon.
			data.frame:Hide()
		end
	end

	ApplyTimelineFont()
end

local function SetFontStringFont(fontString, key, size)
	if not fontString or not fontString.SetFont then return end
	ApplyFont(fontString, GetFontPath(key), size or 12)
end

local function UpdateDropdown()
	local key
	local entry
	local selectedText
	if not dropdown then return end

	key = GetFontKey()
	entry = GetFontEntry(key)
	UIDropDownMenu_SetText(entry.name, dropdown)

	-- The closed Cooline control previews the active font without touching
	-- Blizzard's shared global dropdown list buttons.
	selectedText = getglobal(dropdown:GetName() .. "Text")
	SetFontStringFont(selectedText, key, 12)
end

local function RefreshFontPopup()
	local current
	local i
	local button

	if not fontPopup or not fontPopup.buttons then return end

	current = GetFontKey()
	for i = 1, table.getn(fontPopup.buttons) do
		button = fontPopup.buttons[i]
		if button.entryKey == current then
			button.check:Show()
		else
			button.check:Hide()
		end
	end
end

local function SelectFont(key)
	local visuals = GetVisuals()
	if not visuals or not key then return end

	visuals.barfont = GetFontEntry(key).key
	ApplyTimelineFont()
	UpdateDropdown()
	RefreshFontPopup()

	if fontPopup then
		fontPopup:Hide()
	end
end

local function BuildFontPopup()
	local selectedText
	local i
	local entry
	local button
	local text
	local check
	local rowHeight = 20

	if fontPopup or not dropdown then return end

	selectedText = getglobal(dropdown:GetName() .. "Text")
	fontPopup = CreateFrame("Frame", "CoolineBarFontPopup", dropdown)
	fontPopup:SetWidth(190)
	fontPopup:SetHeight((table.getn(FONT_CHOICES) * rowHeight) + 12)
	fontPopup:SetFrameLevel(dropdown:GetFrameLevel() + 20)
	fontPopup:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	fontPopup:SetBackdropColor(0, 0, 0, 0.95)
	fontPopup:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	fontPopup.buttons = {}

	if selectedText then
		fontPopup:SetPoint("TOPLEFT", selectedText, "BOTTOMLEFT", -8, -5)
	else
		fontPopup:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 25, 5)
	end

	for i = 1, table.getn(FONT_CHOICES) do
		entry = FONT_CHOICES[i]
		button = CreateFrame("Button", nil, fontPopup)
		button:SetHeight(rowHeight)
		button:SetPoint("TOPLEFT", fontPopup, "TOPLEFT", 6, -6 - ((i - 1) * rowHeight))
		button:SetPoint("TOPRIGHT", fontPopup, "TOPRIGHT", -6, -6 - ((i - 1) * rowHeight))
		button.entryKey = entry.key
		button:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")
		button:SetScript("OnClick", function()
			SelectFont(this.entryKey)
		end)

		text = button:CreateFontString(nil, "OVERLAY")
		text:SetPoint("LEFT", button, "LEFT", 8, 0)
		text:SetPoint("RIGHT", button, "RIGHT", -24, 0)
		text:SetJustifyH("LEFT")
		SetFontStringFont(text, entry.key, 12)
		text:SetText(entry.name)
		button.text = text

		check = button:CreateTexture(nil, "OVERLAY")
		check:SetWidth(16)
		check:SetHeight(16)
		check:SetPoint("RIGHT", button, "RIGHT", -4, 0)
		check:SetTexture([[Interface\Buttons\UI-CheckBox-Check]])
		button.check = check

		tinsert(fontPopup.buttons, button)
	end

	fontPopup:Hide()
	RefreshFontPopup()
end

local function ToggleFontPopup()
	BuildFontPopup()
	if not fontPopup then return end

	if fontPopup:IsShown() then
		fontPopup:Hide()
	else
		RefreshFontPopup()
		fontPopup:Show()
	end
end

local function BuildFontOption()
	local options = getglobal("CoolineOptionsFrame")
	local page
	local label
	local arrowButton

	if dropdown or not options or not options.appearancePage then return end
	page = options.appearancePage

	label = page:CreateFontString(nil, "OVERLAY")
	label:SetPoint("TOPLEFT", page, "TOPLEFT", 28, -610)
	label:SetFont(GetClientDefaultFont(), 11)
	label:SetTextColor(0.9, 0.9, 0.9)
	label:SetText(L("Bar Font"))

	dropdown = CreateFrame("Frame", "CoolineBarFontDropDown", page, "UIDropDownMenuTemplate")
	-- Keep the familiar Vanilla closed dropdown shell, but do not initialize
	-- Blizzard's shared dropdown menu. Cooline owns the opened font list.
	dropdown:SetPoint("TOPLEFT", page, "TOPLEFT", 219, -594)
	UIDropDownMenu_SetWidth(180, dropdown)
	UpdateDropdown()

	arrowButton = getglobal(dropdown:GetName() .. "Button")
	if arrowButton then
		arrowButton:SetScript("OnClick", ToggleFontPopup)
	end

	dropdown:SetScript("OnHide", function()
		if fontPopup then
			fontPopup:Hide()
		end
	end)
end

local function ClampAlpha(value)
	if not value then return value end
	if value < 0 then return 0 end
	if value > 1 then return 1 end
	return value
end

local function ClampVisuals(visuals)
	local changed = false
	local value
	if not visuals then return false end

	value = ClampAlpha(visuals.activealpha)
	if value ~= visuals.activealpha then
		visuals.activealpha = value
		changed = true
	end

	value = ClampAlpha(visuals.inactivealpha)
	if value ~= visuals.inactivealpha then
		visuals.inactivealpha = value
		changed = true
	end

	return changed
end

local function RefreshAlphaControls()
	local options = getglobal("CoolineOptionsFrame")
	local visuals = GetVisuals()
	local active
	local inactive

	if not options or not visuals or not options.active or not options.inactive then return end

	active = math.floor(((visuals.activealpha or 1) * 100) + 0.5)
	inactive = math.floor(((visuals.inactivealpha or 0.5) * 100) + 0.5)

	options.updating = true
	options.active:SetValue(active)
	options.active.edit:SetText(active .. "%")
	options.inactive:SetValue(inactive)
	options.inactive.edit:SetText(inactive .. "%")
	options.updating = false
end

local function ClampAllOpacity()
	local changed = false
	if CoolineDB and ClampVisuals(CoolineDB.visuals) then changed = true end
	if CoolineCharDB and ClampVisuals(CoolineCharDB.visuals) then changed = true end
	if changed then RefreshAlphaControls() end
end

local function Setup()
	local bar = getglobal("CoolineBar")
	local options = getglobal("CoolineOptionsFrame")

	if setupComplete then return true end
	if not CoolineDB or not CoolineCharDB or not bar or not bar.labels or not options then
		return false
	end

	EnsureFontDefaults()
	ClampAllOpacity()
	BuildLabelOverlay()
	BuildFontOption()
	setupComplete = true
	return true
end

local driver = CreateFrame("Frame")
driver:RegisterEvent("VARIABLES_LOADED")
driver:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" and Setup() then
		this:UnregisterEvent("VARIABLES_LOADED")
	end
end)
driver:SetScript("OnUpdate", function()
	local bar
	local key

	if not setupComplete then
		if not Setup() then return end
	end

	bar = getglobal("CoolineBar")
	if overlay and bar and bar.bg then
		overlay:SetAlpha(bar.bg:GetAlpha())
	end

	key = GetFontKey()
	if key ~= lastFontKey then
		ApplyTimelineFont()
		UpdateDropdown()
		RefreshFontPopup()
	end

	syncElapsed = syncElapsed + arg1
	if syncElapsed >= 0.20 then
		syncElapsed = 0
		ClampAllOpacity()
	end
end)
