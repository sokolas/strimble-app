local unpack = table.unpack or unpack
mainarg = table.pack(...)

local showConsole = false
for i, a in ipairs(mainarg) do
    if a == "console" then
        ShowConsole()
        showConsole = true
        break
    end
end
if not showConsole then
    HideConsole()
end

function SplitMessage(msg, sep)
    local sep = sep or "\r\n"
    local pos,arr = 0,{}
    for st,sp in function() return string.find(msg, sep, pos, true) end do
        table.insert(arr,string.sub(msg, pos, st-1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(msg, pos))
    return arr
    
    --[[local t = {}
    for s in lutf8.gmatch(msg, "([^"..sep.."]*)"..sep) do
        table.insert(t, s)
    end
    return t]]
end

-- partition input table entries 
function Partition(input)
end

function string.startsWith(str, substr)
    if not str or not substr then
        return false
    end
    if string.len(substr) > string.len(str) then
        return false
    end
    return string.sub(str, 1, string.len(substr)) == substr
end

function string.endsWith(str, substr)
    if not str or not substr then
        return false
    end
    if string.len(substr) > string.len(str) then
        return false
    end
    -- print(string.sub(str, string.len(str) - string.len(substr)))
    return string.sub(str, string.len(str) - string.len(substr) + 1) == substr
end

package.cpath = 'bin/clibs/?.dll;' .. package.cpath
package.path  = 'lualibs/?.lua;lualibs/?/?.lua;lualibs/?/init.lua;' .. package.path

if jit and jit.on then jit.on() end -- turn jit "on" as "mobdebug" may turn it off for LuaJIT
require("wx")
-- wx.wxSplashScreen(wx.wxBitmap("starter/resources/res/bug-256.png"), wx.wxSPLASH_CENTRE_ON_SCREEN + wx.wxSPLASH_TIMEOUT, 1000, wx.NULL, wx.wxID_ANY)
-- dofile "src/util.lua"

-- initialization of some globals
-- print(wx.wxGetCwd())
math.randomseed(os.time())

Logger = {
    loggers = {}
}

Logger.create = function(name)
    if not Logger.loggers[name] then
        local logger = {
            enabled = true,
            name_str = "[" .. name .. "]\t"
        }
        logger.log = function(...)
            if not logger.enabled then return end
            -- Log(logger.name_str, ...)
            local arg = table.pack(...)
            local s = os.date("[%d %b %Y %H:%M:%S]\t") .. logger.name_str
            local info = debug.getinfo(2)
        
            if info then
                local src = string.gsub(info.short_src, ".\\", "")
                s = s .. src .. ":" .. info.currentline .. "\t"
            end
            for i = 1, arg.n do
                if type(v) == "string" then
                    s = s .. arg[i]
                else
                    s = s .. tostring(arg[i])
                end
                if i < arg.n then
                    s = s .. "\t"
                end
            end
            io.write(s .. "\n")
        end

        logger.err = function(...)
            -- Log(logger.name_str, "ERROR\t", ...)
            local arg = table.pack(...)
            local s = os.date("[%d %b %Y %H:%M:%S]\t") .. logger.name_str .. "ERROR\t"
            local info = debug.getinfo(2)
        
            if info then
                local src = string.gsub(info.short_src, ".\\", "")
                s = s .. src .. ":" .. info.currentline .. "\t"
            end
            for i = 1, arg.n do
                if type(v) == "string" then
                    s = s .. arg[i]
                else
                    s = s .. tostring(arg[i])
                end
                if i < arg.n then
                    s = s .. "\t"
                end
            end
            io.write(s .. "\n")
        end
        Logger.loggers[name] = logger
    end
    return Logger.loggers[name]
end

function Log(...)
    local arg = table.pack(...)
    local s = os.date("[%d %b %Y %H:%M:%S]\t")
    local info = debug.getinfo(2)

    if info then
        local src = string.gsub(info.short_src, ".\\", "")
        s = s .. src .. ":" .. info.currentline .. "\t"
    end
    for i = 1, arg.n do
        if type(v) == "string" then
            s = s .. arg[i]
        else
            s = s .. tostring(arg[i])
        end
        if i < arg.n then
            s = s .. "\t"
        end
    end
    io.write(s .. "\n")
end

local lfs = require("lfs")
pollnet = require("pollnet")

-- print("locking")
local count = 0
local lock = nil
Log("Checking if already running...")
repeat
    if count == 1 then
        Log("Waiting for another app to exit...")
    end
    lock = lfs.lock_dir("./data/", 1)
    count = count + 1
    pollnet.sleep_ms(100)
until lock or count == 100
if not lock then
    wx.wxMessageBox("Can't stop the app, please close it manually and restart",
        "Strimble Error",
        wx.wxOK + wx.wxICON_EXCLAMATION,
        wx.NULL)
    return
end
-- print(lock)

Lutf8 = require("lua-utf8")
NetworkManager = require("src/netutils")
DelayManager = require("src/delayutils")
Json = require("json")

-- local _sq = package.loadlib("bin/sqlite3.dll", "sqlite3_version") -- hack to preload sqlite3 dll
local _vw2 = package.loadlib("bin/WebView2Loader.dll", "GetAvailableCoreWebView2BrowserVersionString")  -- hack to preload webview dll
Sqlite = require("lsqlite3complete")
require("src/stuff/db_helper")  -- adds global Db
DataDb = Sqlite.open("data/data.sqlite3")
AppConfig = wx.wxFileConfig("", "", wx.wxGetCwd() .. "\\data\\strimble.ini", "", wx.wxCONFIG_USE_LOCAL_FILE)

function CopyTable(data)
    local result = {}
    for k, v in pairs(data) do
        result[k] = v
    end
    return result
end

function SaveToCfg(path, t, name)
    local currentPath = AppConfig:GetPath()
    AppConfig:SetPath("/" .. path)
    if type(t) == "table" then
        for k, v in pairs(t) do
            AppConfig:Write(k, v)
        end
    else
        AppConfig:Write(name, t)
    end
    AppConfig:SetPath(currentPath)
    AppConfig:Flush()
end

function ReadFromCfg(path, name, defaultValue)
    local currentPath = AppConfig:GetPath()
    AppConfig:SetPath("/" .. path)
    local _, res = AppConfig:Read(name, defaultValue)
    AppConfig:SetPath(currentPath)
    return res
end

dofile("src/migrations/migrations.lua")  -- do this for db file!

Twitch = require("src/twitch")

-- UI init
dofile("src/xml_ui.lua")
-- dofile("src/test/sqlite.lua")
-- dofile("src/timer.lua")

-- run
main()
if is_wx_app then
    wx.wxGetApp():MainLoop()
end

-- cleanup
if Db and Db:isopen() then
    Db:close()  -- probably don't need this for in-memory db
end
if DataDb and DataDb:isopen() then
    DataDb:close()
end