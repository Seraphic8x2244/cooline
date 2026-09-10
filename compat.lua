local L = CoolineLocale and CoolineLocale.Text or function(text) return text end
local locale = CoolineLocale and CoolineLocale.GetLocale and CoolineLocale.GetLocale() or (GetLocale and GetLocale()) or "enUS"
local setupComplete = false

local function NewFilter()
	return {
		mode = "blacklist",
		blacklist = {},
		whitelist = {},
	}
end

local function ScopeFiltersByLocale()
	if not CoolineCharDB then return end

	if not CoolineCharDB.filtersByLocale then
		CoolineCharDB.filtersByLocale = {}
		CoolineCharDB.filtersByLocale[locale] = CoolineCharDB.filters or NewFilter()
	end
	if not CoolineCharDB.filtersByLocale[locale] then
		CoolineCharDB.filtersByLocale[locale] = NewFilter()
	end
	CoolineCharDB.filters = CoolineCharDB.filtersByLocale[locale]

	if not CoolineCharDB.itemFiltersByLocale then
		CoolineCharDB.itemFiltersByLocale = {}
		CoolineCharDB.itemFiltersByLocale[locale] = CoolineCharDB.itemFilters or NewFilter()
	end
	if not CoolineCharDB.itemFiltersByLocale[locale] then
		CoolineCharDB.itemFiltersByLocale[locale] = NewFilter()
	end
	CoolineCharDB.itemFilters = CoolineCharDB.itemFiltersByLocale[locale]
end

local function ApplyClientFontAndLocale(frame, visited)
	local regions
	local children
	local i
	local region
	local child
	local text
	local _, size, flags
	local font = STANDARD_TEXT_FONT or [[Fonts\FRIZQT__.TTF]]

	if not frame then return end
	visited = visited or {}
	if visited[frame] then return end
	visited[frame] = true

	regions = { frame:GetRegions() }
	for i = 1, table.getn(regions) do
		region = regions[i]
		if region then
			if region.GetText and region.SetText then
				text = region:GetText()
				if text and text ~= "" then
					region:SetText(L(text))
				end
			end
			if region.GetFont and region.SetFont then
				_, size, flags = region:GetFont()
				if size then
					region:SetFont(font, size, flags or "")
				end
			end
		end
	end

	children = { frame:GetChildren() }
	for i = 1, table.getn(children) do
		child = children[i]
		if child then
			ApplyClientFontAndLocale(child, visited)
		end
	end
end

local function LocalizeMinimapTooltip()
	local button = getglobal("CoolineMinimapButton")
	if not button then return end

	button:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_LEFT")
		GameTooltip:AddLine("Cooline", 1, 0.82, 0)
		GameTooltip:AddLine(L("Left-click: Options"), 1, 1, 1)
		GameTooltip:AddLine(L("Right-click: Lock / Unlock"), 1, 1, 1)
		GameTooltip:AddLine(L("Drag: Move button"), 1, 1, 1)
		GameTooltip:Show()
	end)
end

local function GetSpellCount()
	local tabs = GetNumSpellTabs() or 0
	local highest = 0
	local i
	local _, _, offset, num

	for i = 1, tabs do
		_, _, offset, num = GetSpellTabInfo(i)
		if offset and num and offset + num > highest then
			highest = offset + num
		end
	end

	return highest
end

local function FindFailedSpell(message)
	local count = GetSpellCount()
	local now = GetTime()
	local bestName
	local bestTexture
	local bestLength = 0
	local i
	local name
	local startTime, duration, enabled

	if not message or message == "" then return nil, nil end

	for i = 1, count do
		name = GetSpellName(i, BOOKTYPE_SPELL)
		if name and string.find(message, name, 1, true) then
			startTime, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
			if enabled == 1 and duration and duration > 2.5 and
			   startTime and (startTime + duration) > now and string.len(name) > bestLength then
				bestName = name
				bestTexture = GetSpellTexture(i, BOOKTYPE_SPELL)
				bestLength = string.len(name)
			end
		end
	end

	return bestName, bestTexture
end

local function FindCooldownFrame(texture)
	local bar = getglobal("CoolineBar")
	local children
	local i
	local child

	if not bar or not bar.border or not texture then return nil end

	children = { bar.border:GetChildren() }
	for i = 1, table.getn(children) do
		child = children[i]
		if child and child.icon and child.icon.GetTexture and
		   child.icon:GetTexture() == texture and child:IsShown() then
			return child
		end
	end

	return nil
end

local function GetVisuals()
	if CoolineCharDB and CoolineCharDB.useCharacterVisuals and CoolineCharDB.visuals then
		return CoolineCharDB.visuals
	end
	return CoolineDB and CoolineDB.visuals
end

local function GetSpellBaseSize()
	local visuals = GetVisuals()
	local width = visuals and visuals.width or 18
	local oversize = visuals and visuals.iconoversize or 4

	if CoolineCharDB and CoolineCharDB.spellIconOverride then
		oversize = CoolineCharDB.spellIconOversize or oversize
	end

	return math.max(2, width + oversize)
end

local function HandleFailedSpell(message)
	local visuals = GetVisuals()
	local _, texture
	local frame

	if not visuals or not visuals.cooldownanimate or visuals.cooldownanimate == 100 then return end

	_, texture = FindFailedSpell(message)
	if not texture then return end

	frame = FindCooldownFrame(texture)
	if not frame then return end

	frame.coolineLocalePulseStart = GetTime()
	frame.coolineLocalePulseBase = GetSpellBaseSize()
end

local function UpdateLocalePulses()
	local bar = getglobal("CoolineBar")
	local visuals = GetVisuals()
	local children
	local i
	local frame
	local progress
	local pulse
	local targetScale
	local drawSize

	if not bar or not bar.border or not visuals then return end

	children = { bar.border:GetChildren() }
	for i = 1, table.getn(children) do
		frame = children[i]
		if frame and frame.coolineLocalePulseStart then
			progress = (GetTime() - frame.coolineLocalePulseStart) / 0.26
			if progress >= 1 then
				frame.coolineLocalePulseStart = nil
				frame:SetWidth(frame.coolineLocalePulseBase or GetSpellBaseSize())
				frame:SetHeight(frame.coolineLocalePulseBase or GetSpellBaseSize())
			else
				if progress < 0.5 then
					pulse = progress * 2
				else
					pulse = (1 - progress) * 2
				end
				targetScale = (visuals.cooldownanimate or 150) / 100
				drawSize = (frame.coolineLocalePulseBase or GetSpellBaseSize()) *
				           (1 + ((targetScale - 1) * pulse))
				frame:SetWidth(drawSize)
				frame:SetHeight(drawSize)
			end
		end
	end
end

local function WrapCooldownScripts()
	local bar = getglobal("CoolineBar")
	local oldEvent
	local oldUpdate

	if not bar or bar.coolineLocaleWrapped then return end
	bar.coolineLocaleWrapped = true

	oldEvent = bar:GetScript("OnEvent")
	if oldEvent then
		bar:SetScript("OnEvent", function()
			if event == "CHAT_MSG_SPELL_FAILED_LOCALPLAYER" then
				HandleFailedSpell(arg1)
			else
				oldEvent()
			end
		end)
	end

	oldUpdate = bar:GetScript("OnUpdate")
	if oldUpdate then
		bar:SetScript("OnUpdate", function()
			oldUpdate()
			UpdateLocalePulses()
		end)
	end
end

local function Setup()
	local options = getglobal("CoolineOptionsFrame")
	local bar = getglobal("CoolineBar")

	if setupComplete then return true end
	if not CoolineDB or not CoolineCharDB or not options or not bar or not bar.labels then
		return false
	end

	ScopeFiltersByLocale()
	ApplyClientFontAndLocale(options)
	LocalizeMinimapTooltip()
	WrapCooldownScripts()
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
	if not setupComplete and Setup() then
		this:SetScript("OnUpdate", nil)
	end
end)
