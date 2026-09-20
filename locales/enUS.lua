CoolineLocale = CoolineLocale or {}
CoolineLocale.strings = CoolineLocale.strings or {}

local L = CoolineLocale.strings

L["Lock Bar"] = "Lock Bar"
L["Minimap Button"] = "Minimap Button"
L["Appearance"] = "Appearance"
L["Spells"] = "Spells"
L["Items"] = "Items"
L["Account Wide"] = "Account Wide"
L["Per Character"] = "Per Character"
L["Style"] = "Style"
L["Classic"] = "Classic"
L["Flat"] = "Flat"
L["Dark"] = "Dark"
L["Borderless"] = "Borderless"
L["Animate on Cooldown"] = "Animate on Cooldown"
L["Layout"] = "Layout"
L["Bar Direction"] = "Bar Direction"
L["Horizontal"] = "Horizontal"
L["Vertical"] = "Vertical"
L["Icon Direction"] = "Icon Direction"
L["Ascending"] = "Ascending"
L["Descending"] = "Descending"
L["Sizes"] = "Sizes"
L["Bar Length"] = "Bar Length"
L["Bar Width"] = "Bar Width"
L["Icon Oversize"] = "Icon Oversize"
L["Opacity"] = "Opacity"
L["Bar Active"] = "Bar Active"
L["Bar Inactive"] = "Bar Inactive"
L["Icon Size"] = "Icon Size"
L["Spell Only Icon Oversize"] = "Spell Only Icon Oversize"
L["Filter Type"] = "Filter Type"
L["Blacklist"] = "Blacklist"
L["Whitelist"] = "Whitelist"
L["Add Spell"] = "Add Spell"
L["Add"] = "Add"
L["Filtered Spells"] = "Filtered Spells"
L["Item Only Icon Oversize"] = "Item Only Icon Oversize"
L["Add Item"] = "Add Item"
L["Filtered Items"] = "Filtered Items"
L["Bar Font"] = "Bar Font"
L["Client Default"] = "Client Default"
L["Left-click: Options"] = "Left-click: Options"
L["Right-click: Lock / Unlock"] = "Right-click: Lock / Unlock"
L["Drag: Move button"] = "Drag: Move button"
L["Cooline %s loaded."] = "Cooline %s loaded."

function CoolineLocale.Text(text)
	return L[text] or text
end

function CoolineLocale.GetLocale()
	return GetLocale and GetLocale() or "enUS"
end
