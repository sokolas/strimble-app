local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local wxtimers = require("src/stuff/wxtimers")
local audio = require("src/stuff/audio")

local _M = {}

local logger = Logger.create("general_steps")

local submenu = wx.wxMenu()
local steps = {}

local function delay(ctx, params)
    logger.log("delaying", params.delay)
    local this, main_thread = coroutine.running()
    if main_thread then
        logger.err("Can't call suspendable 'delay' from non-coroutine", debug.traceback())
        return false
    end
    logger.log(this)

    wxtimers.addTimer(params.delay, function(event)
        logger.log("resuming", params.delay)
        local ok, res = coroutine.resume(this)
        logger.log(ok, res)
    end)
    coroutine.yield()
    logger.log("delay is over", params.delay)
    return true
end

local function log(ctx, params)
    local output = ctx:interpolate(params.message)
    logger.force(output)
    return true
end

local function playSound(ctx, params)
    audio.loadAndPlay(params.filename, nil, true)
    return true
end

local function init(menu, dialogs)
    local pages = iconsHelper.getPages()

    -- delay
    steps.delayItem = submenu:Append(wx.wxID_ANY, "Delay")

    steps.delayDialog = dialogHelper.createDataDialog(Gui, "DelayStepDialog", {
        ["Delay"] = {
            {
                name = "delay",
                label = "Delay (ms)",
                type = "text"
            }
        }
    },
    function(data, context)
        if not data.delay or data.delay == "" then
            return false, "Delay can't be empty"
        else if data.delay ~= string.match(data.delay, "%d+") then
            return false, "Only digits are allowed"
        end
            return true
        end
    end)
    
    dialogs[steps.delayItem:GetId()] = {
        name = "Delay",
        dialog = steps.delayDialog,
        dialogItem = Gui.dialogs.DelayStepDialog,
        icon = pages.timer,
        getDescription = function(result) return result.delay .. 'ms' end,
        preProcess = function(params)
            return {
                delay = tostring(params.delay)
            }
        end,
        postProcess = function(result)
            local delay = tonumber(result.delay)
            logger.log(type(delay))
            return {
                delay = delay
            }
        end,
        code = delay,
        data = {
            delay = "1000"
        }
    }

    -- log
    steps.logItem = submenu:Append(wx.wxID_ANY, "Log")

    steps.logDialog = dialogHelper.createDataDialog(Gui, "LogStepDialog", {
        ["Log"] = {
            {
                name = "message",
                label = "Message",
                type = "text"
            }
        }
    },
    function(data, context)
        if not data.message or data.message == "" then
            return false, "Message can't be empty"
        else
            local start, finish = Lutf8.find(data.message, var_pattern)
            while start do
                local var_expr = Lutf8.sub(data.message, start, finish)
                if not string.startsWith(var_expr, '$$') then
                    local var = Lutf8.sub(var_expr, 2)
                    logger.log("var", var)
                end
                start, finish = Lutf8.find(data.message, var_pattern, finish)
            end
            
            return true
        end
    end)
    
    dialogs[steps.logItem:GetId()] = {
        name = "Log",
        dialog = steps.logDialog,
        dialogItem = Gui.dialogs.LogStepDialog,
        icon = pages.logs,
        getDescription = function(result) return result.message end,
        code = log,
        data = {
            message = "User: $user, channel: $channel"
        }
    }

    --sound
    steps.playSoundItem = submenu:Append(wx.wxID_ANY, "Play sound")
    steps.soundDialog = dialogHelper.createDataDialog(Gui, "PlaySoundStepDialog", {
        ["PlaySound"] = {
            {
                name = "filename",
                label = "File name",
                type = "text"
            },
            {
                name = "file_selector",
                label = "",
                value = "Select file...",
                type = "file",
                ref = "filename",
                wildcard = "Audio files (MP3, WAV, OGG)|*.mp3;*.wav;*.ogg"
            }
        }
    })

    dialogs[steps.playSoundItem:GetId()] = {
        name = "Play sound",
        dialog = steps.soundDialog,
        dialogItem = Gui.dialogs.PlaySoundStepDialog,
        icon = pages.logs,
        getDescription = function(result) return result.filename end,
        code = playSound,
        data = {
            filename = "example.wav"
        }
    }

    -- finalize
    menu:AppendSubMenu(submenu, "General")
end

_M.delay = delay
_M.init = init

return _M