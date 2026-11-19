-- SPDX-License-Identifier: GPL-3.0-or-later
-- Run from the repository root with a Lua interpreter. WoW APIs use fixed fixtures.

local function mustNotWriteDesktop()
    error("The mobile action profile wrote to the desktop bars or bindings")
end

PickupAction, PlaceAction, ClearCursor = mustNotWriteDesktop, mustNotWriteDesktop, mustNotWriteDesktop
SetBinding, SetBindingClick, SaveBindings = mustNotWriteDesktop, mustNotWriteDesktop, mustNotWriteDesktop

local desktop = {
    [1] = { "spell", 101 },
    [13] = { "spell", 101 },
    [14] = { "item", 501 },
    [25] = { "macro", 9 },
    [180] = { "spell", 301 },
}
function GetActionInfo(slot) return table.unpack(desktop[slot] or {}) end
function GetActionTexture(slot) return desktop[slot] and (1000 + slot) end
function GetActionBarPage() return 2 end
function GetLocale() return "deDE" end
C_AddOns = { GetAddOnMetadata = function() return "en" end }

local spellNames = { [101] = "Fire", [201] = "Ice", [301] = "Passive" }
C_Spell = {
    GetSpellName = function(id) return spellNames[id] end,
    GetSpellTexture = function(id) return id + 700 end,
    GetSpellCharges = function() return { currentCharges = 2 } end,
    GetSpellCooldown = function() return { startTime = 12, duration = 10, modRate = 1.5 } end,
}
local spellBook = {
    { itemType = 1, spellID = 201 },
    { itemType = 1, actionID = 101, spellID = 100 },
    { itemType = 1, spellID = 301, isPassive = true },
    { itemType = 1, spellID = 101 },
}
Enum = { SpellBookSpellBank = { Player = 1 }, SpellBookItemType = { Spell = 1 } }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = #spellBook } end,
    GetSpellBookItemInfo = function(slot) return spellBook[slot] end,
}
C_Item = {
    GetItemNameByID = function(id) return id == 501 and "Potion" or "Cloth" end,
    GetItemSpell = function(id) return id == 501 and "Drink" or nil end,
    GetItemIconByID = function(id) return id + 800 end,
}
local items = { 501, 502, 501 }
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #items or 0 end,
    GetContainerItemInfo = function(_, slot) return { itemID = items[slot] } end,
}

local addon = {}
assert(loadfile("ForeverTouch/ForeverTouchActions.lua"))("ForeverTouch", addon)
local actions = addon.actions
assert(not addon.german, "An explicit English selection must survive the German client locale")

local order, records = actions.desktop()
assert(#order == 4 and records[order[1]].slot == 13 and records[order[4]].slot == 180)
assert(order[2] == "item:501:")
print("Desktop scan prioritizes the active page, scans through slot 180, and removes duplicates.")

local copy = actions.splitDesktop(order, records)
local saved = actions.independentProfile(copy, records)
assert(copy.right[1].kind == "desktop" and copy.left[1].kind == "desktop")
assert(saved.right[1].kind == "spell" and saved.right[1].id == 101)
assert(saved.left[1].kind == "item" and saved.left[1].id == 501)
assert(saved.right[2].kind == "desktop" and saved.right[2].key == "macro:9:")
assert(desktop[13][2] == 101 and desktop[14][2] == 501)

local button = {
    attributes = {},
    SetAttribute = function(self, key, value) self.attributes[key] = value end,
    GetAttribute = function(self, key) return self.attributes[key] end,
    icon = {
        SetTexture = function(self, texture) self.texture = texture end,
        SetVertexColor = function() end,
    },
    count = { SetText = function(self, text) self.text = text end },
    cooldown = { SetCooldown = function(self, ...) self.values = { ... } end },
}
desktop[1], desktop[13], desktop[14] = nil, { "spell", 201 }, nil
local _, updatedRecords = actions.desktop()
actions.bind(button, saved.right[1], updatedRecords)
assert(button:GetAttribute("type") == "spell" and button:GetAttribute("spell") == 101)
assert(button:GetAttribute("action") == nil)
actions.refresh(button, updatedRecords, true)
assert(button.icon.texture == 801 and button.count.text == 2)
assert(button.cooldown.values[1] == 12 and button.cooldown.values[2] == 10 and button.cooldown.values[3] == 1.5)
actions.bind(button, saved.left[1], updatedRecords)
assert(button:GetAttribute("type") == "item" and button:GetAttribute("item") == "item:501")
assert(button:GetAttribute("spell") == nil)
actions.bind(button, nil, updatedRecords)
assert(button:GetAttribute("type") == nil and button:GetAttribute("item") == nil)
print("Saved spells and items retain their IDs after desktop changes. Macro references stay linked.")

local choices = actions.spellChoices()
assert(#choices == 2 and choices[1].id == 101 and choices[2].id == 201)
choices = actions.itemChoices()
assert(#choices == 1 and choices[1].id == 501)
local corrupt = actions.copyProfile({ left = {
    { kind = "spell", id = 0 }, { kind = "item", id = math.huge }, { kind = "spell", id = 1.5 },
    { kind = "item", id = 501 },
} })
assert(#corrupt.left == 1 and corrupt.left[1].id == 501)
print("Spell and item pickers filter invalid, passive, unusable, and duplicate entries.")

assert(loadfile("ForeverTouch/ForeverTouchPicker.lua"))
assert(loadfile("ForeverTouch/ForeverTouchMobileLayout.lua"))
print("All three add-on scripts parse successfully.")
