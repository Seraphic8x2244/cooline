-- Cooline 1.9.1 core test
-- Minimal clean-room baseline for WoW 1.12.1.

local VERSION = "1.9.1-coretest"

local DEFAULTS = {
	width = 360,
	height = 18,
	x = 0,
	y = -240,
	inactivealpha = 0.5,
	activealpha = 1.0,
}

local bar = CreateFrame("Frame", "CoolineBar", UIParent)
local cooldowns = {}
local initialised = false

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
		bar.settings = CoolineCharDB.visuals
	else
		bar.settings = CoolineDB.visuals
	end
end

local function BuildBar()
	local s = bar.settings

	bar:SetWidth(s.width)
	bar:SetHeight(s.height)
	bar:SetPoint("CENTER", UIParent, "CENTER", s.x, s.y)
	bar:SetMovable(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")

	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints(bar)
	bar.bg:SetTexture(0, 0, 0, 0.55)

	bar.edge = bar:CreateTexture(nil, "ARTWORK")
	bar.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	bar.edge:SetTexture(0.18, 0.18, 0.18, 1)

	bar.inner = bar:CreateTexture(nil, "OVERLAY")
	bar.inner:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
	bar.inner:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -1, 1)
	bar.inner:SetTexture(0.05, 0.05, 0.05, 1)

	bar.label = bar:CreateFontString(nil, "OVERLAY")
	bar.label:SetPoint("CENTER", bar, "CENTER", 0, 0)
	bar.label:SetFont([[Fonts\FRIZQT__.TTF]], 10)
	bar.label:SetTextColor(1, 0.82, 0)
	bar.label:SetText("Cooline core test")

	bar:SetAlpha(s.inactivealpha)

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
			s.x = floor(x - ux + 0.5)
			s.y = floor(y - uy + 0.5)
		end
	end)

	initialised = true
end

local function GetSpellCount()
	local tabs = GetNumSpellTabs()
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

local function ClearCooldownFrames()
	local i
	for i = 1, table.getn(cooldowns) do
		cooldowns[i]:Hide()
	end
end

local function EnsureCooldownFrame(index)
	local frame = cooldowns[index]

	if not frame then
		frame = CreateFrame("Frame", nil, bar)
		frame:SetWidth(20)
		frame:SetHeight(20)

		frame.icon = frame:CreateTexture(nil, "ARTWORK")
		frame.icon:SetAllPoints(frame)

		cooldowns[index] = frame
	end

	return frame
end

local function ScanSpells()
	local count = GetSpellCount()
	local id
	local name
	local startTime, duration, enabled
	local texture
	local frame
	local shown = 0
	local now = GetTime()
	local remaining
	local offset

	ClearCooldownFrames()

	for id = 1, count do
		name = GetSpellName(id, BOOKTYPE_SPELL)

		if name then
			startTime, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)

			if enabled == 1 and duration and duration > 2.5 then
				remaining = (startTime + duration) - now

				if remaining > 0 then
					shown = shown + 1
					frame = EnsureCooldownFrame(shown)
					texture = GetSpellTexture(id, BOOKTYPE_SPELL)
					frame.icon:SetTexture(texture)

					-- Linear placement for this core test only.
					offset = remaining
					if offset > 60 then
						offset = 60
					end
					offset = (offset / 60) * bar.settings.width

					frame:ClearAllPoints()
					frame:SetPoint("CENTER", bar, "LEFT", offset, 0)
					frame:Show()
				end
			end
		end
	end

	if shown > 0 then
		bar:SetAlpha(bar.settings.activealpha)
		bar.label:Hide()
	else
		bar:SetAlpha(bar.settings.inactivealpha)
		bar.label:Show()
	end
end

bar:RegisterEvent("VARIABLES_LOADED")
bar:RegisterEvent("SPELL_UPDATE_COOLDOWN")
bar:RegisterEvent("PLAYER_ENTERING_WORLD")

bar:SetScript("OnEvent", function()
	if event == "VARIABLES_LOADED" then
		InitialiseSettings()
		BuildBar()
		DEFAULT_CHAT_FRAME:AddMessage("|c00ffff00Cooline core test loaded.|r")
	elseif initialised then
		ScanSpells()
	end
end)

bar:SetScript("OnUpdate", function()
	if initialised then
		bar.scan = (bar.scan or 0) + arg1
		if bar.scan >= 0.5 then
			bar.scan = 0
			ScanSpells()
		end
	end
end)
