local dataHelper = require("src/stuff/data_helper")
local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local ctxHelper = require("src/stuff/action_context")
-- local bit = require("bit")

local logger = Logger.create("hotkey_triggers")

local _M = {}

local triggerIcons = {}

local triggerIconPaths = {
    {path = "images/icons/keyboard.png", name = "hotkeys"},
}

local function registerTriggerIcons()
    triggerIcons = iconsHelper.registerTriggerIcons(triggerIconPaths)
end

local keys = {
    0xBA,
    0xBB,
    0xBC,
    0xBD,
    0xBE,
    0xBF,
    0xC0,
    0xDB,
    0xDD,
    0xDC,
    0xDE,
    0xE2,
    wx.WXK_BACK,
    wx.WXK_INSERT,
    wx.WXK_DELETE,
    wx.WXK_HOME,
    wx.WXK_END,
    wx.WXK_PAGEUP,
    wx.WXK_PAGEDOWN,

    wx.WXK_UP,
    wx.WXK_DOWN,
    wx.WXK_LEFT,
    wx.WXK_RIGHT,

    wx.WXK_RETURN,
    wx.WXK_SPACE,
    wx.WXK_TAB,

    wx.WXK_ESCAPE,
    wx.WXK_F1,
    wx.WXK_F2,
    wx.WXK_F3,
    wx.WXK_F4,
    wx.WXK_F5,
    wx.WXK_F6,
    wx.WXK_F7,
    wx.WXK_F8,
    wx.WXK_F9,
    wx.WXK_F10,
    wx.WXK_F11,
    wx.WXK_F12,

    wx.WXK_NUMLOCK,
    wx.WXK_SCROLL,

    wx.WXK_NUMPAD0,
    wx.WXK_NUMPAD1,
    wx.WXK_NUMPAD2,
    wx.WXK_NUMPAD3,
    wx.WXK_NUMPAD4,
    wx.WXK_NUMPAD5,
    wx.WXK_NUMPAD6,
    wx.WXK_NUMPAD7,
    wx.WXK_NUMPAD8,
    wx.WXK_NUMPAD9,

    wx.WXK_NUMPAD_ADD,
    wx.WXK_NUMPAD_DIVIDE,
    wx.WXK_NUMPAD_MULTIPLY,
    wx.WXK_NUMPAD_SUBTRACT,
    wx.WXK_NUMPAD_EQUAL,
    wx.WXK_NUMPAD_DECIMAL,

    wx.WXK_NUMPAD_UP,
    wx.WXK_NUMPAD_DOWN,
    wx.WXK_NUMPAD_LEFT,
    wx.WXK_NUMPAD_RIGHT,
    wx.WXK_NUMPAD_ENTER,

    -1
}

local keyNames = {
    ";: (may vary)",
    "+= (add/equals)",
    ", (comma)",
    "-_ (minus)",
    ". (full stop)",
    "/? (may vary)",
    "`~ (may vary)",
    "[{ (may vary)",
    "]} (may vary)",
    "\\| (may vary)",
    "'\" (may vary)",
    "<> or \\| (may vary)",
    "Backspace",
    "Insert",
    "Delete",
    "Home",
    "End",
    "PageUp",
    "PageDown",

    "Up",
    "Down",
    "Left",
    "Right",

    "Return/Enter",
    "Space",
    "Tab",

    "Escape",
    "F1",
    "F2",
    "F3",
    "F4",
    "F5",
    "F6",
    "F7",
    "F8",
    "F9",
    "F10",
    "F11",
    "F12",

    "NumLock",
    "ScrollLock",

    "Numpad 0",
    "Numpad 1",
    "Numpad 2",
    "Numpad 3",
    "Numpad 4",
    "Numpad 5",
    "Numpad 6",
    "Numpad 7",
    "Numpad 8",
    "Numpad 9",

    "Numpad +",
    "Numpad /",
    "Numpad *",
    "Numpad -",
    "Numpad =",
    "Numpad .",

    "Numpad Up",
    "Numpad Down",
    "Numpad Left",
    "Numpad Right",
    "Numpad Enter (may not work)",
    "<Unknown>"
}

for i = 48, 57 do   -- numbers
    table.insert(keys, i - 47, i)
    table.insert(keyNames, i - 47, string.char(i))
end

for i = 65, 90 do   -- A-Z
    table.insert(keys, i - 64, i)
    table.insert(keyNames, i - 64, string.char(i))
end

local function getKeyIndexByCode(code)
    local r = #keys
    for i, v in ipairs(keys) do
        if code == v then
            return i
        end
    end
    return r
end

-- https://www.ascii-code.com/
-- https://learn.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes

local function getHotkeyMods(data)
    return bit.bor(
        bit.tobit(data.alt and wx.wxMOD_ALT or 0),
        bit.tobit(data.ctrl and wx.wxMOD_CONTROL or 0),
        bit.tobit(data.shift and wx.wxMOD_SHIFT or 0),
        bit.tobit(data.win and wx.wxMOD_WIN or 0)
    )
end

local function getHotkeyId(data)
    local modBits = getHotkeyMods(data) -- 0x0f max
    local keyCode = bit.lshift(
        bit.tobit(data.key)
    , 4) -- 0x1ff0 max
    
    return bit.bor(keyCode, modBits)
end

local function getHotkeyIdForValidation(data)   -- key is an index instead of actual code
    local modBits = getHotkeyMods(data) -- 0x0f max
    local keyCode = bit.lshift(
        bit.tobit(keys[data.key + 1])
    , 4) -- 0x1ff0 max
    
    return bit.bor(keyCode, modBits)
end

local function createHotkeyDialog()
    local hotkeyDlg = dialogHelper.createTriggerDialog(Gui, "HotkeyDialog", {
        {
            name = "Trigger properties",
            controls = {
                {
                    name = "name",
                    label = "Name",
                    type = "text"
                },
                {
                    name = "ctrl",
                    text = "Ctrl",
                    type = "check",
                    value = false
                },
                {
                    name = "alt",
                    text = "Alt",
                    type = "check",
                    value = false
                },
                {
                    name = "shift",
                    text = "Shift",
                    type = "check",
                    value = false
                },
                {
                    name = "win",
                    text = "Win",
                    type = "check",
                    value = false
                },
                {
                    name = "key",
                    label = "Key",
                    type = "choice",
                    choices = keyNames
                }
            }
        }
    },
    -- validation
    function(data, context)
        -- logger.log(data.key, #keys-1)
        if data.key == #keys-1 then
            return false, "Key can't be <Unknown>"
        end

        local keyId = getHotkeyIdForValidation(data)
        if context and context.id then
            logger.log("Context id: ", context.id, "hotkey id:", keyId)
            local duplicates = dataHelper.findTriggers(function(v)
                -- for k, vv in pairs(v) do
                    -- logger.log(k, vv)
                -- end
                -- logger.log("")
                return v.id ~= context.id and (not v.isGroup) and v.type == "hotkey" and getHotkeyId(v.data) == keyId
            end)
            if #duplicates > 0 then
                return false, "Hotkey combination must be unique"
            end
        else
            logger.log("hotkey id:", keyId)
            local duplicates = dataHelper.findTriggers(function(v)
                -- for k, vv in pairs(v) do
                    -- logger.log(k, vv)
                -- end
                -- logger.log("")
                return (not v.isGroup) and v.type == "hotkey" and getHotkeyId(v.data) == keyId
            end)
            if #duplicates > 0 then
                return false, "Hotkey combination must be unique"
            end
        end
        return true
    end)
    return hotkeyDlg
end

local function createHotkeysFolder(triggerListCtrl, onTrigger)
    local rootTriggerItem = triggerListCtrl:GetRootItem()

    local hotkeysFolder = triggerListCtrl:AppendItem(rootTriggerItem, "Hotkeys", triggerIcons.hotkeys, triggerIcons.hotkeys)
    
    local function createHotkeyHandler(item, guiItem)
        logger.log("Hotkey handler created")
        local function buildContext()
            return ctxHelper.create({}, item.data.action)
        end
        return function(event)
            logger.log("hotkey triggering; action", item.data.action)
            onTrigger("hotkey", {action = item.data.action, name = item.name}, buildContext)
        end
    end

    local treeItem = {
        id = hotkeysFolder:GetValue(),
        isGroup = true,
        canAddChildren = true,
        childrenType = "hotkey",
        persistChildren = true,
        icon = triggerIcons.active, -- for children
        getDescription = function(result)
            local mods = {}
            if result.ctrl then
                table.insert(mods, "Ctrl")
            end
            if result.alt then
                table.insert(mods, "Alt")
            end
            if result.shift then
                table.insert(mods, "Shift")
            end
            if result.win then
                table.insert(mods, "Win")
            end
            local d = table.concat(mods, " + ")
            local code = getHotkeyId(result)
            local index = getKeyIndexByCode(result.key)

            return d .. " + " .. tostring(keyNames[index])
        end,
        dialog = Gui.dialogs.HotkeyDialog,
        preProcess = function(data)
            local index = getKeyIndexByCode(data.key)
            data.key = index - 1
        end,
        postProcess = function(result)
            logger.log("Postprocessing hotkey")
            result.key = keys[result.key + 1]
        end,
        add = "Add hotkey",
        childEdit = "Edit hotkey",
        data = { -- default values for new children
            name = "Example hotkey",
            ctrl = true,
            alt = true,
            key = 313,
            enabled = true
        },
        onEnable = function(item, guiItem)
            logger.log("onEnable hotkey", item.name)
            if getKeyIndexByCode(item.data.key) == #keys then
                logger.err("Unknown hotkey code: " .. bit.tohex(item.data.key))
                return
            end
            local this, main_thread = coroutine.running()
            if not main_thread then
                logger.err("Trigger onEnable Must be run from the main thread")
                return
            end
            local id = getHotkeyId(item.data)
            local mods = getHotkeyMods(item.data)
            local code = item.data.key

            local ok = Gui.frame:RegisterHotKey(id, mods, code)
            logger.log("Hotkey " .. bit.tohex(id) .. " code: " .. bit.tohex(code) .. " registration:", ok)
            
            local handler = createHotkeyHandler(item, guiItem)
            Gui.frame:Connect(id, wx.wxEVT_HOTKEY, function(event)
                logger.log("Hotkey pressed", item.name, bit.tohex(id))
                handler()
            end)
            return ok
        end,
        onDisable = function(item, guiItem)
            logger.log("onDisable hotkey", item.name)
            local id = getHotkeyId(item.data)
            Gui.frame:Disconnect(id, wx.wxEVT_HOTKEY)
            local r = Gui.frame:UnregisterHotKey(id)
            logger.log("unregister result", r)
        end,
        onDelete = function(item, guiItem)
            logger.log("onDelete hotkey", item.name)
        end,
        onUpdate = function(item, guiItem, result)
            local this, main_thread = coroutine.running()
            logger.log("onUpdate hotkey", item.name)
            if not main_thread then
                logger.err("Trigger onUpdate Must be run from the main thread")
                return
            end
            
            local oldId = getHotkeyId(item.data)
            
            Gui.frame:Disconnect(oldId, wx.wxEVT_HOTKEY)
            local r = Gui.frame:UnregisterHotKey(oldId)
            logger.log("unregister result", r)

            if getKeyIndexByCode(result.key) == #keys then
                logger.err("Unknown hotkey code: " .. bit.tohex(result.key))
                return
            end

            local id = getHotkeyId(result)
            local mods = getHotkeyMods(result)
            local code = result.key

            local ok = Gui.frame:RegisterHotKey(id, mods, code)
            logger.log("Hotkey " .. bit.tohex(id) .. " code: " .. bit.tohex(code) .. " registration:", ok)
            local handler = createHotkeyHandler(item, guiItem)
            Gui.frame:Connect(id, wx.wxEVT_HOTKEY, function(event)
                logger.log("Hotkey pressed", item.name, bit.tohex(id))
                handler()
            end)
            return ok
        end
    }
    return hotkeysFolder, treeItem
end

_M.createHotkeyDialog = createHotkeyDialog
_M.getTriggerTypes = function() return {"hotkey"} end
_M.registerTriggerIcons = registerTriggerIcons
_M.createTriggerFolder = function(name, triggerListCtrl, onTrigger)
    return createHotkeysFolder(triggerListCtrl, onTrigger)
end
return _M
