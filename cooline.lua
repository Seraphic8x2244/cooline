-- Cooline 1.9.0
-- Based on shirsig's Cooline for WoW 1.12.1.
--
-- Settings model:
--   CoolineDB     = account-wide visual settings
--   CoolineCharDB = per-character filters and optional visual override

local COOLINE_VERSION = "1.9.1"

local factory_visuals = {
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
	nospellcolor = { 0, 0, 0, 1 },
	inactivealpha = 0.5,
	activealpha = 1.0,
	treshold = 3.0,
}

local function copy_table(source)
	local result = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			result[key] = copy_table(value)
		else
			result[key] = value
		end
	end
	return result
end

local function apply_defaults(target, defaults)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = copy_table(value)
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			apply_defaults(target[key], value)
		end
	end
end

-- SavedVariables are not available until VARIABLES_LOADED on Vanilla 1.12.1.
-- These references are initialised there.
local cooline_theme

local function initialise_settings()
	-- Account-wide SavedVariables.
	CoolineDB = CoolineDB or {}
	CoolineDB.visuals = CoolineDB.visuals or {}
	apply_defaults(CoolineDB.visuals, factory_visuals)

	-- Per-character SavedVariables.
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

	-- A character visual profile is only created when the character actually
	-- opts into character-specific visuals.
	if CoolineCharDB.useCharacterVisuals then
		if not CoolineCharDB.visuals then
			CoolineCharDB.visuals = copy_table(CoolineDB.visuals)
		end
		apply_defaults(CoolineCharDB.visuals, factory_visuals)
		cooline_theme = CoolineCharDB.visuals
	else
		cooline_theme = CoolineDB.visuals
	end
end


local function select_visual_settings()
	if CoolineCharDB.useCharacterVisuals then
		if not CoolineCharDB.visuals then
			CoolineCharDB.visuals = copy_table(CoolineDB.visuals)
		end
		apply_defaults(CoolineCharDB.visuals, factory_visuals)
		cooline_theme = CoolineCharDB.visuals
	else
		cooline_theme = CoolineDB.visuals
	end
end

local function set_character_visuals(enabled)
	if enabled then
		if not CoolineCharDB.visuals then
			CoolineCharDB.visuals = copy_table(CoolineDB.visuals)
		end
		CoolineCharDB.useCharacterVisuals = true
	else
		CoolineCharDB.useCharacterVisuals = false
	end

	select_visual_settings()
end

local cooline = CreateFrame('Button', nil, UIParent)
cooline:SetScript('OnEvent', function()
	this[event]()
end)
cooline:RegisterEvent('VARIABLES_LOADED')

local frame_pool = {}
local cooldowns = {}

function cooline.hyperlink_name(hyperlink)
    local _, _, name = strfind(hyperlink, '|Hitem:%d+:%d+:%d+:%d+|h[[]([^]]+)[]]|h')
    return name
end

local function list_contains_name(list, name)
	if not name then
		return false
	end

	for _, listed_name in ipairs(list) do
		if strupper(name) == strupper(listed_name) then
			return true
		end
	end

	return false
end


function cooline.detect_cooldowns()
	
	local function start_cooldown(name, texture, start_time, duration, is_spell)
		local filters = CoolineCharDB.filters
		local listed

		if filters.mode == "whitelist" then
			listed = list_contains_name(filters.whitelist, name)
			if not listed then
				return
			end
		else
			listed = list_contains_name(filters.blacklist, name)
			if listed then
				return
			end
		end
		
		local end_time = start_time + duration
			
		for _, cooldown in pairs(cooldowns) do
			if cooldown.end_time == end_time then
				return
			end
		end

		cooldowns[name] = cooldowns[name] or tremove(frame_pool) or cooline.cooldown_frame()
		local frame = cooldowns[name]
		frame:SetWidth(cooline.icon_size)
		frame:SetHeight(cooline.icon_size)
		frame.icon:SetTexture(texture)
		if is_spell then
			frame:SetBackdropColor(unpack(cooline_theme.spellcolor))
		else
			frame:SetBackdropColor(unpack(cooline_theme.nospellcolor))
		end
		frame:SetAlpha((end_time - GetTime() > 360) and 0.6 or 1)
		frame.end_time = end_time
		frame:Show()
	end
	
    for bag = 0,4 do
        if GetBagName(bag) then
            for slot = 1, GetContainerNumSlots(bag) do
				local start_time, duration, enabled = GetContainerItemCooldown(bag, slot)
				if enabled == 1 then
					local name = cooline.hyperlink_name(GetContainerItemLink(bag, slot))
					if duration > 3 and duration < 3601 then
						start_cooldown(
							name,
							GetContainerItemInfo(bag, slot),
							start_time,
							duration,
							false
						)
					elseif duration == 0 then
						cooline.clear_cooldown(name)
					end
				end
            end
        end
    end
	
	for slot=0,19 do
		local start_time, duration, enabled = GetInventoryItemCooldown('player', slot)
		if enabled == 1 then
			local name = cooline.hyperlink_name(GetInventoryItemLink('player', slot))
			if duration > 3 and duration < 3601 then
				start_cooldown(
					name,
					GetInventoryItemTexture('player', slot),
					start_time,
					duration,
					false
				)
			elseif duration == 0 then
				cooline.clear_cooldown(name)
			end
		end
	end
	
	local _, _, offset, spell_count = GetSpellTabInfo(GetNumSpellTabs())
	local total_spells = offset + spell_count
	for id=1,total_spells do
		local start_time, duration, enabled = GetSpellCooldown(id, BOOKTYPE_SPELL)
		local name = GetSpellName(id, BOOKTYPE_SPELL)
		if enabled == 1 and duration > 2.5 then
			start_cooldown(
				name,
				GetSpellTexture(id, BOOKTYPE_SPELL),
				start_time,
				duration,
				true
			)
		elseif duration == 0 then
			cooline.clear_cooldown(name)
		end
	end
	
	cooline.on_update(true)
end

function cooline.cooldown_frame()
	local frame = CreateFrame('Frame', nil, cooline.border)
	frame:SetBackdrop({ bgFile=[[Interface\AddOns\cooline\artwork\backdrop.tga]] })
	frame.icon = frame:CreateTexture(nil, 'ARTWORK')
	frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	frame.icon:SetPoint('TOPLEFT', 1, -1)
	frame.icon:SetPoint('BOTTOMRIGHT', -1, 1)
	return frame
end

local function place_H(this, offset, just)
	this:SetPoint(just or 'CENTER', cooline, 'LEFT', offset, 0)
end
local function place_HR(this, offset, just)
	this:SetPoint(just or 'CENTER', cooline, 'LEFT', cooline_theme.width - offset, 0)
end
local function place_V(this, offset, just)
	this:SetPoint(just or 'CENTER', cooline, 'BOTTOM', 0, offset)
end
local function place_VR(this, offset, just)
	this:SetPoint(just or 'CENTER', cooline, 'BOTTOM', 0, cooline_theme.height - offset)
end

function cooline.clear_cooldown(name)
	if cooldowns[name] then
		cooldowns[name]:Hide()
		tinsert(frame_pool, cooldowns[name])
		cooldowns[name] = nil
	end
end

local relevel, throt = false, 0

function getKeysSortedByValue(tbl, sortFunction)
	local keys = {}
	for key in pairs(tbl) do
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		return sortFunction(tbl[a], tbl[b])
	end)

	return keys
end

function cooline.update_cooldown(name, frame, position, tthrot, relevel)
	throt = min(throt, tthrot)
	
	if frame.end_time - GetTime() < cooline_theme.treshold then
		local sorted = getKeysSortedByValue(cooldowns, function(a, b) return a.end_time > b.end_time end)
		for i, k in ipairs(sorted) do
			if name == k then
				frame:SetFrameLevel(i+2)
			end
		end
	else
		if relevel then
			frame:SetFrameLevel(random(1,5) + 2)
		end
	end
	
	cooline.place(frame, position)
end

do
	local last_update, last_relevel = GetTime(), GetTime()
	
	function cooline.on_update(force)
		if GetTime() - last_update < throt and not force then return end
		last_update = GetTime()
		
		relevel = false
		if GetTime() - last_relevel > 0.4 then
			relevel, last_relevel = true, GetTime()
		end
		
		isactive, throt = false, 1.5
		for name, frame in pairs(cooldowns) do
			local time_left = frame.end_time - GetTime()
			isactive = isactive or time_left < 360
			
			if time_left < -1 then
				throt = min(throt, 0.2)
				isactive = true
				cooline.clear_cooldown(name)
			elseif time_left < 0 then
				cooline.update_cooldown(name, frame, 0, 0, relevel)
				frame:SetAlpha(1 + time_left)  -- fades
			elseif time_left < 0.3 then
				local size = cooline.icon_size * (0.5 - time_left) * 5  -- icon_size + icon_size * (0.3 - time_left) / 0.2
				frame:SetWidth(size)
				frame:SetHeight(size)
				cooline.update_cooldown(name, frame, cooline.section * time_left, 0, relevel)
			elseif time_left < 1 then
				cooline.update_cooldown(name, frame, cooline.section * time_left, 0, relevel)
			elseif time_left < 3 then
				cooline.update_cooldown(name, frame, cooline.section * (time_left + 1) * 0.5, 0.02, relevel)  -- 1 + (time_left - 1) / 2
			elseif time_left < 10 then
				cooline.update_cooldown(name, frame, cooline.section * (time_left + 11) * 0.14286, time_left > 4 and 0.05 or 0.02, relevel)  -- 2 + (time_left - 3) / 7
			elseif time_left < 30 then
				cooline.update_cooldown(name, frame, cooline.section * (time_left + 50) * 0.05, 0.06, relevel)  -- 3 + (time_left - 10) / 20
			elseif time_left < 120 then
				cooline.update_cooldown(name, frame, cooline.section * (time_left + 330) * 0.011111, 0.18, relevel)  -- 4 + (time_left - 30) / 90
			elseif time_left < 360 then
				cooline.update_cooldown(name, frame, cooline.section * (time_left + 1080) * 0.0041667, 1.2, relevel)  -- 5 + (time_left - 120) / 240
				frame:SetAlpha(cooline_theme.activealpha)
			else
				cooline.update_cooldown(name, frame, 6 * cooline.section, 2, relevel)
			end
		end
		cooline:SetAlpha(isactive and cooline_theme.activealpha or cooline_theme.inactivealpha)
	end
end

local create_options

function cooline.layout_label(fs, offset, just)
	fs:SetFont(cooline_theme.font, cooline_theme.fontsize)
	fs:SetTextColor(unpack(cooline_theme.fontcolor))
	fs:SetWidth(cooline_theme.fontsize * 3)
	fs:SetHeight(cooline_theme.fontsize + 2)
	fs:SetShadowColor(unpack(cooline_theme.bgcolor))
	fs:SetShadowOffset(1, -1)
	fs:ClearAllPoints()

	if just then
		if cooline_theme.vertical then
			fs:SetJustifyH('CENTER')
			just = cooline_theme.reverse and ((just == 'LEFT' and 'TOP') or 'BOTTOM') or ((just == 'LEFT' and 'BOTTOM') or 'TOP')
		elseif cooline_theme.reverse then
			just = (just == 'LEFT' and 'RIGHT') or 'LEFT'
			offset = offset + ((just == 'LEFT' and 1) or -1)
			fs:SetJustifyH(just)
		else
			offset = offset + ((just == 'LEFT' and 1) or -1)
			fs:SetJustifyH(just)
		end
	else
		fs:SetJustifyH('CENTER')
	end

	cooline.place(fs, offset, just)
end

function cooline.label(text, offset, just)
	local fs = cooline.overlay:CreateFontString(nil, 'OVERLAY')
	fs:SetText(text)
	cooline.layout_label(fs, offset, just)
	return fs
end

function cooline.apply_visual_settings()
	if not cooline_theme or not cooline.bg or not cooline.border then
		return
	end

	cooline:SetWidth(cooline_theme.width)
	cooline:SetHeight(cooline_theme.height)

	cooline:ClearAllPoints()
	cooline:SetPoint('CENTER', cooline_theme.x, cooline_theme.y)

	if cooline_theme.vertical then
		cooline.bg:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	else
		cooline.bg:SetTexCoord(0, 1, 0, 1)
	end

	cooline.section = (cooline_theme.vertical and cooline_theme.height or cooline_theme.width) / 6
	cooline.icon_size = (cooline_theme.vertical and cooline_theme.width or cooline_theme.height) + cooline_theme.iconoutset * 2
	cooline.place = cooline_theme.vertical and (cooline_theme.reverse and place_VR or place_V) or (cooline_theme.reverse and place_HR or place_H)

	if cooline.tick0 then
		cooline.layout_label(cooline.tick0, 0, 'LEFT')
		cooline.layout_label(cooline.tick1, cooline.section)
		cooline.layout_label(cooline.tick3, cooline.section * 2)
		cooline.layout_label(cooline.tick10, cooline.section * 3)
		cooline.layout_label(cooline.tick30, cooline.section * 4)
		cooline.layout_label(cooline.tick120, cooline.section * 5)
		cooline.layout_label(cooline.tick300, cooline.section * 6, 'RIGHT')
	end

	for _, frame in pairs(cooldowns) do
		frame:SetWidth(cooline.icon_size)
		frame:SetHeight(cooline.icon_size)
	end

	cooline.on_update(true)
end

function cooline.VARIABLES_LOADED()
	initialise_settings()

	cooline:SetClampedToScreen(true)
	cooline:SetMovable(true)
	cooline:RegisterForDrag('LeftButton')
	
	function cooline:on_drag_stop()
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		local ux, uy = UIParent:GetCenter()
		cooline_theme.x, cooline_theme.y = floor(x - ux + 0.5), floor(y - uy + 0.5)
		this.dragging = false
	end
	cooline:SetScript('OnDragStart', function()
		this.dragging = true
		this:StartMoving()
	end)
	cooline:SetScript('OnDragStop', function()
		this:on_drag_stop()
	end)
	cooline:SetScript('OnUpdate', function()
		this:EnableMouse(IsAltKeyDown())
		if not IsAltKeyDown() and this.dragging then
			this:on_drag_stop()
		end
		cooline.on_update()
	end)

	cooline:SetWidth(cooline_theme.width)
	cooline:SetHeight(cooline_theme.height)
	cooline:SetPoint('CENTER', cooline_theme.x, cooline_theme.y)
	
	cooline.bg = cooline:CreateTexture(nil, 'ARTWORK')
	cooline.bg:SetTexture(cooline_theme.statusbar)
	cooline.bg:SetVertexColor(unpack(cooline_theme.bgcolor))
	cooline.bg:SetAllPoints(cooline)
	if cooline_theme.vertical then
		cooline.bg:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
	else
		cooline.bg:SetTexCoord(0, 1, 0, 1)
	end

	cooline.border = CreateFrame('Frame', nil, cooline)
	cooline.border:SetPoint('TOPLEFT', -cooline_theme.borderinset, cooline_theme.borderinset)
	cooline.border:SetPoint('BOTTOMRIGHT', cooline_theme.borderinset, -cooline_theme.borderinset)
	cooline.border:SetBackdrop({
		edgeFile = cooline_theme.border,
		edgeSize = cooline_theme.bordersize,
	})
	cooline.border:SetBackdropBorderColor(unpack(cooline_theme.bordercolor))

	cooline.overlay = CreateFrame('Frame', nil, cooline.border)
	cooline.overlay:SetFrameLevel(24) -- TODO this gets changed automatically later, to 9, find out why

	cooline.section = (cooline_theme.vertical and cooline_theme.height or cooline_theme.width) / 6
	cooline.icon_size = (cooline_theme.vertical and cooline_theme.width or cooline_theme.height) + cooline_theme.iconoutset * 2
	cooline.place = cooline_theme.vertical and (cooline_theme.reverse and place_VR or place_V) or (cooline_theme.reverse and place_HR or place_H)

	cooline.tick0 = cooline.label('0', 0, 'LEFT')
	cooline.tick1 = cooline.label('1', cooline.section)
	cooline.tick3 = cooline.label('3', cooline.section * 2)
	cooline.tick10 = cooline.label('10', cooline.section * 3)
	cooline.tick30 = cooline.label('30', cooline.section * 4)
	cooline.tick120 = cooline.label('2m', cooline.section * 5)
	cooline.tick300 = cooline.label('6m', cooline.section * 6, 'RIGHT')
	
	cooline:RegisterEvent('SPELL_UPDATE_COOLDOWN')
	cooline:RegisterEvent('BAG_UPDATE_COOLDOWN')
	
	cooline.detect_cooldowns()

	create_options()

	DEFAULT_CHAT_FRAME:AddMessage('|c00ffff00Cooline ' .. COOLINE_VERSION .. ' loaded: move the Cooline bar by holding <alt> while dragging it with left mouse button.|r');
end


local options

local function options_label(parent, text, x, y, size)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	fs:SetFont([[Fonts\FRIZQT__.TTF]], size or 12)
	fs:SetTextColor(1, 0.82, 0)
	fs:SetText(text)
	return fs
end

local function options_body_text(parent, text, x, y)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	fs:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	fs:SetTextColor(0.9, 0.9, 0.9)
	fs:SetText(text)
	return fs
end

local function make_button(parent, text, width, height)
	local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
	button:SetWidth(width)
	button:SetHeight(height)
	button:SetText(text)
	return button
end

local function make_checkbox(parent, text, x, y)
	local check = CreateFrame('CheckButton', nil, parent, 'UICheckButtonTemplate')
	check:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	check:SetWidth(24)
	check:SetHeight(24)

	local label = check:CreateFontString(nil, 'OVERLAY')
	label:SetPoint('LEFT', check, 'RIGHT', 2, 1)
	label:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	label:SetTextColor(0.9, 0.9, 0.9)
	label:SetText(text)
	check.label = label

	return check
end

local slider_count = 0
local function make_slider(parent, label, x, y, width, low, high, step)
	slider_count = slider_count + 1
	local name = 'CoolineOptionsSlider' .. slider_count
	local slider = CreateFrame('Slider', name, parent, 'OptionsSliderTemplate')
	slider:SetPoint('TOPLEFT', parent, 'TOPLEFT', x, y)
	slider:SetWidth(width)
	slider:SetHeight(16)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)

	getglobal(name .. 'Text'):SetText(label)
	getglobal(name .. 'Low'):SetText(tostring(low))
	getglobal(name .. 'High'):SetText(tostring(high))

	local value = parent:CreateFontString(nil, 'OVERLAY')
	value:SetPoint('LEFT', slider, 'RIGHT', 10, 0)
	value:SetFont([[Fonts\FRIZQT__.TTF]], 11)
	value:SetTextColor(0.9, 0.9, 0.9)
	slider.valueText = value

	return slider
end

create_options = function()
	if options then
		return
	end

	options = CreateFrame('Frame', 'CoolineOptionsFrame', UIParent)
	options:SetWidth(520)
	options:SetHeight(400)
	options:SetPoint('CENTER', UIParent, 'CENTER', 0, 40)
	options:SetFrameStrata('DIALOG')
	options:SetMovable(true)
	options:EnableMouse(true)
	options:RegisterForDrag('LeftButton')
	options:SetScript('OnDragStart', function() this:StartMoving() end)
	options:SetScript('OnDragStop', function() this:StopMovingOrSizing() end)
	options:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		tile = true,
		tileSize = 32,
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})
	options:SetBackdropColor(0.08, 0.10, 0.13, 0.98)
	options:SetBackdropBorderColor(0.45, 0.52, 0.60, 1)
	options:Hide()

	local title = options:CreateFontString(nil, 'OVERLAY')
	title:SetPoint('TOPLEFT', options, 'TOPLEFT', 18, -15)
	title:SetFont([[Fonts\FRIZQT__.TTF]], 14)
	title:SetTextColor(1, 0.82, 0)
	title:SetText('Cooline')
	options.title = title

	local version = options:CreateFontString(nil, 'OVERLAY')
	version:SetPoint('LEFT', title, 'RIGHT', 7, 0)
	version:SetFont([[Fonts\FRIZQT__.TTF]], 10)
	version:SetTextColor(0.65, 0.70, 0.76)
	version:SetText('v' .. COOLINE_VERSION)

	local close = make_button(options, 'X', 24, 22)
	close:SetPoint('TOPRIGHT', options, 'TOPRIGHT', -12, -11)
	close:SetScript('OnClick', function() options:Hide() end)

	options.appearanceTab = make_button(options, 'Appearance', 105, 24)
	options.appearanceTab:SetPoint('TOPLEFT', options, 'TOPLEFT', 18, -45)

	options.cooldownsTab = make_button(options, 'Cooldowns', 105, 24)
	options.cooldownsTab:SetPoint('LEFT', options.appearanceTab, 'RIGHT', 4, 0)

	options.advancedTab = make_button(options, 'Advanced', 105, 24)
	options.advancedTab:SetPoint('LEFT', options.cooldownsTab, 'RIGHT', 4, 0)

	options.panel = CreateFrame('Frame', nil, options)
	options.panel:SetPoint('TOPLEFT', options, 'TOPLEFT', 16, -76)
	options.panel:SetPoint('BOTTOMRIGHT', options, 'BOTTOMRIGHT', -16, 42)
	options.panel:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]],
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	options.panel:SetBackdropColor(0.04, 0.05, 0.07, 0.88)
	options.panel:SetBackdropBorderColor(0.30, 0.36, 0.43, 1)

	options.appearancePage = CreateFrame('Frame', nil, options.panel)
	options.appearancePage:SetAllPoints(options.panel)

	options.placeholderPage = CreateFrame('Frame', nil, options.panel)
	options.placeholderPage:SetAllPoints(options.panel)
	options.placeholderPage:Hide()
	options.placeholderTitle = options_label(options.placeholderPage, '', 18, -20, 14)
	options.placeholderText = options_body_text(options.placeholderPage, 'Reserved for a later 1.9.x build.', 18, -48)

	local function show_page(page)
		options.appearancePage:Hide()
		options.placeholderPage:Hide()

		if page == 'appearance' then
			options.appearancePage:Show()
		elseif page == 'cooldowns' then
			options.placeholderTitle:SetText('Cooldowns')
			options.placeholderPage:Show()
		else
			options.placeholderTitle:SetText('Advanced')
			options.placeholderPage:Show()
		end
	end

	options.appearanceTab:SetScript('OnClick', function() show_page('appearance') end)
	options.cooldownsTab:SetScript('OnClick', function() show_page('cooldowns') end)
	options.advancedTab:SetScript('OnClick', function() show_page('advanced') end)

	options_label(options.appearancePage, 'Appearance', 18, -18, 14)

	options.scopeText = options_body_text(options.appearancePage, '', 18, -45)

	options.charVisuals = make_checkbox(
		options.appearancePage,
		'Use character-specific appearance',
		18,
		-67
	)

	options_label(options.appearancePage, 'Size', 18, -108, 12)

	options.widthSlider = make_slider(options.appearancePage, 'Width', 28, -140, 250, 120, 720, 1)
	options.heightSlider = make_slider(options.appearancePage, 'Height', 28, -188, 250, 8, 48, 1)

	options_label(options.appearancePage, 'Layout', 330, -108, 12)

	options.verticalCheck = make_checkbox(options.appearancePage, 'Vertical', 330, -137)
	options.reverseCheck = make_checkbox(options.appearancePage, 'Reverse direction', 330, -168)

	options_label(options.appearancePage, 'Opacity', 18, -232, 12)

	options.activeSlider = make_slider(options.appearancePage, 'Active', 28, -264, 250, 10, 100, 5)
	options.inactiveSlider = make_slider(options.appearancePage, 'Inactive', 28, -312, 250, 0, 100, 5)

	options.reset = make_button(options, 'Reset Appearance', 130, 24)
	options.reset:SetPoint('BOTTOMLEFT', options, 'BOTTOMLEFT', 18, 12)

	options.done = make_button(options, 'Close', 80, 24)
	options.done:SetPoint('BOTTOMRIGHT', options, 'BOTTOMRIGHT', -18, 12)
	options.done:SetScript('OnClick', function() options:Hide() end)

	function options.refresh()
		options.updating = true

		options.charVisuals:SetChecked(CoolineCharDB.useCharacterVisuals and 1 or nil)
		options.scopeText:SetText(
			CoolineCharDB.useCharacterVisuals
			and 'Editing: this character'
			or 'Editing: account-wide'
		)

		options.widthSlider:SetValue(cooline_theme.width)
		options.widthSlider.valueText:SetText(tostring(cooline_theme.width))

		options.heightSlider:SetValue(cooline_theme.height)
		options.heightSlider.valueText:SetText(tostring(cooline_theme.height))

		options.verticalCheck:SetChecked(cooline_theme.vertical and 1 or nil)
		options.reverseCheck:SetChecked(cooline_theme.reverse and 1 or nil)

		options.activeSlider:SetValue(floor(cooline_theme.activealpha * 100 + 0.5))
		options.activeSlider.valueText:SetText(floor(cooline_theme.activealpha * 100 + 0.5) .. '%')

		options.inactiveSlider:SetValue(floor(cooline_theme.inactivealpha * 100 + 0.5))
		options.inactiveSlider.valueText:SetText(floor(cooline_theme.inactivealpha * 100 + 0.5) .. '%')

		options.updating = false
	end

	options.charVisuals:SetScript('OnClick', function()
		set_character_visuals(this:GetChecked() and true or false)
		cooline.apply_visual_settings()
		options.refresh()
	end)

	options.widthSlider:SetScript('OnValueChanged', function()
		if options.updating then return end
		cooline_theme.width = floor(this:GetValue() + 0.5)
		this.valueText:SetText(tostring(cooline_theme.width))
		cooline.apply_visual_settings()
	end)

	options.heightSlider:SetScript('OnValueChanged', function()
		if options.updating then return end
		cooline_theme.height = floor(this:GetValue() + 0.5)
		this.valueText:SetText(tostring(cooline_theme.height))
		cooline.apply_visual_settings()
	end)

	options.verticalCheck:SetScript('OnClick', function()
		cooline_theme.vertical = this:GetChecked() and true or false
		cooline.apply_visual_settings()
	end)

	options.reverseCheck:SetScript('OnClick', function()
		cooline_theme.reverse = this:GetChecked() and true or false
		cooline.apply_visual_settings()
	end)

	options.activeSlider:SetScript('OnValueChanged', function()
		if options.updating then return end
		local value = floor(this:GetValue() + 0.5)
		cooline_theme.activealpha = value / 100
		this.valueText:SetText(value .. '%')
		cooline.apply_visual_settings()
	end)

	options.inactiveSlider:SetScript('OnValueChanged', function()
		if options.updating then return end
		local value = floor(this:GetValue() + 0.5)
		cooline_theme.inactivealpha = value / 100
		this.valueText:SetText(value .. '%')
		cooline.apply_visual_settings()
	end)

	options.reset:SetScript('OnClick', function()
		local x, y = cooline_theme.x, cooline_theme.y
		if CoolineCharDB.useCharacterVisuals then
			CoolineCharDB.visuals = copy_table(factory_visuals)
			cooline_theme = CoolineCharDB.visuals
		else
			CoolineDB.visuals = copy_table(factory_visuals)
			cooline_theme = CoolineDB.visuals
		end

		-- Reset appearance values, but do not unexpectedly move the bar.
		cooline_theme.x = x
		cooline_theme.y = y

		cooline.apply_visual_settings()
		options.refresh()
	end)

	show_page('appearance')
end

local function toggle_options()
	create_options()

	if options:IsShown() then
		options:Hide()
	else
		options.refresh()
		options:Show()
	end
end

SLASH_COOLINE1 = '/cooline'
SlashCmdList['COOLINE'] = function(msg)
	toggle_options()
end


function cooline.BAG_UPDATE_COOLDOWN()
	cooline.detect_cooldowns()
end

function cooline.SPELL_UPDATE_COOLDOWN()
	cooline.detect_cooldowns()
end
