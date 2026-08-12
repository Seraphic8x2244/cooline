-- Cooline 1.9.1 timeline test
-- Clean single-file rebuild for WoW 1.12.1.
-- This stage adds the real nonlinear Cooline timeline and smooth spell movement.

local VERSION = "1.9.1-timeline"

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

local function TimelineOffset(timeLeft)
	local section = visuals.width / 6

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

	return visuals.width
end

local function BuildBar()
	local s = visuals
	local section = s.width / 6
	local labels = {
		{ "0", 0, "LEFT" },
		{ "1", section, "CENTER" },
		{ "3", section * 2, "CENTER" },
		{ "10", section * 3, "CENTER" },
		{ "30", section * 4, "CENTER" },
		{ "2m", section * 5, "CENTER" },
		{ "6m", section * 6, "RIGHT" },
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

	for i, data in ipairs(labels) do
		fs = bar:CreateFontString(nil, "OVERLAY")
		fs:SetFont([[Fonts\FRIZQT__.TTF]], 10)
		fs:SetTextColor(1, 1, 1, 0.8)
		fs:SetShadowColor(0, 0, 0, 0.5)
		fs:SetShadowOffset(1, -1)
		fs:SetText(data[1])
		fs:SetWidth(30)
		fs:SetHeight(12)
		fs:SetJustifyH("CENTER")

		if data[3] == "LEFT" then
			fs:SetPoint("LEFT", bar, "LEFT", 1, 0)
		elseif data[3] == "RIGHT" then
			fs:SetPoint("RIGHT", bar, "RIGHT", -1, 0)
		else
			fs:SetPoint("CENTER", bar, "LEFT", data[2], 0)
		end
	end

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
		size = visuals.height + 4
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

				cd:ClearAllPoints()
				cd:SetPoint("CENTER", bar, "LEFT", offset, 0)
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

local function OnVariablesLoaded()
	InitialiseSettings()
	BuildBar()
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
