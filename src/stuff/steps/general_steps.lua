local dialogHelper = require("src/gui/dialog_helper")
local iconsHelper = require("src/gui/icons")
local wxtimers = require("src/stuff/wxtimers")
local audio = require("src/stuff/audio")
local actionContext = require("src/stuff/action_context")

local _M = {}

local logger = Logger.create("general_steps")

local submenu
local steps = {}

local typesChoices = {
    "string",
    "number"
}

local conditionChoices = {
    "equals",       -- 0
    "not equals",   -- 1
    "greater",      -- 2
    "greater or equal",-- 3
    "less",         -- 4
    "less or equal",-- 5
    "empty",        -- 6
    "not empty",    -- 7
    "pattern"       -- 8
}

local opChoices = {
    "continue",
    "break"
}

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
    local output = ctx:interpolate(params.message, params.asJson)
    logger.force(output)
    return true
end

local function playSound(ctx, params)
    audio.loadAndPlay(params.filename, nil, true)
    return true
end

local function getResult(ctx, param, type)
    local p = ctx:interpolate(param)
    if p == nil then
        return nil  -- shouldn't be there yet
    elseif type == 0 then
        return tostring(p)
    else
        return tonumber(p)
    end
end

local function checkCondition(ctx, params)
    local expr = getResult(ctx, params.expr, params.exprType)
    local value = params.value
    if params.condition ~= 8 then   -- for pattern match, we don't interpolate the value
        value = getResult(ctx, params.value, params.valueType)
    end

    logger.log(conditionChoices[params.condition + 1], expr, type(expr), "to", value, type(value))
    local exprResult = false
    if params.condition == 0 then
        exprResult = (expr == value)
    elseif params.condition == 1 then
        exprResult = (expr ~= value)
    elseif params.condition == 2 then
        exprResult = (expr > value)
    elseif params.condition == 3 then
        exprResult = (expr >= value)
    elseif params.condition == 4 then
        exprResult = (expr < value)
    elseif params.condition == 5 then
        exprResult = (expr <= value)
    elseif params.condition == 6 then
        exprResult = ((expr == '') or (expr == nil))
    elseif params.condition == 7 then
        exprResult = ((expr ~= '') and (expr ~= nil))
    else    -- 8
        local f = Lutf8.find(expr, value)
        logger.log(f, type(f))
        exprResult = (f ~= nil)
    end
    logger.log("result is", exprResult)
    if params.op == 0 then  -- continue if true
        return exprResult
    else
        return not exprResult   -- continue if false
    end
end

local function initDelayStep(submenu, stepHandlers, pages)
    steps.delayItem = submenu:Append(wx.wxID_ANY, "Delay")

    steps.delayDialog = dialogHelper.createDataDialog(Gui, "DelayStepDialog", {
        {
            name = "Delay",
            controls = {
                {
                    name = "delay",
                    label = "Delay (ms)",
                    type = "text"
               }
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
    
    stepHandlers[steps.delayItem:GetId()] = {
        name = "Delay",
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
end

local function initLogStep(submenu, stepHandlers, pages)
    steps.logItem = submenu:Append(wx.wxID_ANY, "Log")

    steps.logDialog = dialogHelper.createDataDialog(Gui, "LogStepDialog", {
        {
            name = "Log",
            controls = {
                {
                    name = "message",
                    label = "Message",
                    type = "text"
                },
                {
                    name = "asJson",
                    text = "Encode to JSON",
                    type = "check"
                }
            }
        }
    },
    function(data, context)
        if not data.message or data.message == "" then
            return false, "Message can't be empty"
        else
            return true
        end
    end)
    
    stepHandlers[steps.logItem:GetId()] = {
        name = "Log",
        dialogItem = Gui.dialogs.LogStepDialog,
        icon = pages.logs,
        getDescription = function(result) return result.message end,
        code = log,
        data = {
            message = "User: $user, channel: $channel"
        }
    }
end

local function initSoundStep(submenu, stepHandlers, pages)
    steps.playSoundItem = submenu:Append(wx.wxID_ANY, "Play sound")
    steps.soundDialog = dialogHelper.createDataDialog(Gui, "PlaySoundStepDialog", {
        {
            name = "Play Sound",
            controls = {
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
        }
    })

    stepHandlers[steps.playSoundItem:GetId()] = {
        name = "Play sound",
        dialogItem = Gui.dialogs.PlaySoundStepDialog,
        icon = pages.logs,
        getDescription = function(result) return result.filename end,
        code = playSound,
        data = {
            filename = "example.wav"
        }
    }
end

local function initLogicStep(submenu, stepHandlers, pages)
    steps.LogicItem = submenu:Append(wx.wxID_ANY, "Logic")
    steps.logicDialog = dialogHelper.createDataDialog(Gui, "LogicStepDialog", {
        {
            name = "Logic",
            controls = {
                {
                    name = "expr",
                    label = "Expression",
                    type = "text"
                },
                {
                    name = "exprType",
                    label = "Treat as",
                    type = "choice",
                    choices = typesChoices
                },
                {
                    name = "condition",
                    label = "Condition",
                    type = "choice",
                    choices = conditionChoices
                },
                {
                    name = "value",
                    label = "Value",
                    type = "text"
                },
                {
                    name = "valueType",
                    label = "Treat as",
                    type = "choice",
                    choices = typesChoices
                },
                {
                    name = "op",
                    label = "On condition",
                    type = "choice",
                    choices = opChoices
                }
            }
        },

    },
    function(data, context)
        logger.log(data.condition)
        if (not data.expr) or data.expr == "" then
            return false, "Expression can't be empty"
        elseif data.condition >= 2 and data.condition <= 5 then -- need numbers
            if data.exprType == 0 or data.valueType == 0 then
                return false, "Less/greater can only be applied to numbers"
            elseif (not data.value) or data.value == "" then
                return false, "Value can't be empty"
            else
                return true
            end
        elseif data.condition == 8 then -- pattern
            if data.exprType ~= 0 or data.valueType ~= 0 then
                return false, "Pattern can only be applied to strings"
            elseif (not data.value) or data.value == "" then
                return false, "Value can't be empty"
            else
                return true
            end
        end
        return true
    end)

    local function getDescription(result)
        for k, v in pairs(result) do
            logger.log(k, v)
        end
        local res = result.expr .. " "
        if result.condition == 6 or result.condition == 7 then
            res = res .. conditionChoices[result.condition + 1]
        else
            res = res .. conditionChoices[result.condition + 1].. " " .. result.value
        end
        res = res  .. ": " .. opChoices[result.op + 1]
        return res
    end

    stepHandlers[steps.LogicItem:GetId()] = {
        name = "Logic",
        dialogItem = Gui.dialogs.LogicStepDialog,
        icon = pages.scripts,
        getDescription = getDescription,
        code = checkCondition,
        data = {
            expr = "$user.name",
            exprType = 0,
            condition = 0,
            value = "StrimbleBot",
            valueType = 0,
            op = 0
        }
    }
end

local function init(menu, stepHandlers)
    local pages = iconsHelper.getPages()
    submenu = wx.wxMenu()

    initDelayStep(submenu, stepHandlers, pages)
    initLogStep(submenu, stepHandlers, pages)
    initSoundStep(submenu, stepHandlers, pages)
    initLogicStep(submenu, stepHandlers, pages)

    -- finalize
    menu:AppendSubMenu(submenu, "General")
end

_M.delay = delay
_M.init = init

return _M