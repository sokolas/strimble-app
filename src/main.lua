local unpack = table.unpack or unpack
mainarg = table.pack(...)

package.cpath = 'bin/clibs/?.so;bin/clibs/?.dll;' .. package.cpath
package.path  = 'lualibs/?.lua;lualibs/?/?.lua;lualibs/?/init.lua;' .. package.path

local tracing = false

LFS = require("lfs")

if jit.os == 'Windows' then
    DataDir = LFS.currentdir() .. "/data"
else
    DataDir = os.getenv("HOME") .. "/.strimble"
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

-- ShowConsole()
--[[
for i, a in ipairs(mainarg) do
    if a == "console" then
        ShowConsole()
        showConsole = true
    end
    if a == "trace" then
        tracing = true
    end
end
]]
if mainarg[2] then
    local parts = SplitMessage(mainarg[2], " ")
    for i, flag in ipairs(parts) do
        if flag == "console" then
            ShowConsole()
            showConsole = true
        end
        if flag == "trace" then
            tracing = true
        end
    end
end
if not showConsole then
    HideConsole()
end

local tracefile = tracing and io.open(DataDir .. "/trace.log", "w")


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

Serpent = require("serpent")

Serpent.simple = function(arg)
    return Serpent.line(arg, {nocode = true, comment = false, sparse = true})
end

local inspect = require("inspect")

if jit and jit.on then jit.on() end -- turn jit "on" as "mobdebug" may turn it off for LuaJIT
-- require("winapi")
require("wx")
-- wx.wxSplashScreen(wx.wxBitmap("starter/resources/res/bug-256.png"), wx.wxSPLASH_CENTRE_ON_SCREEN + wx.wxSPLASH_TIMEOUT, 1000, wx.NULL, wx.wxID_ANY)
-- dofile "src/util.lua"

-- initialization of some globals
-- print(wx.wxGetCwd())
math.randomseed(os.time())

function Trace(...)
    if not tracing then return end
    local arg = table.pack(...)
    local s = os.date("[%d %b %Y %H:%M:%S]\t")
    local info = debug.getinfo(2)

    if info then
        local src = string.gsub(info.source, ".\\", "")
        s = s .. src .. ":" .. info.currentline .. "\t"
    end
    for i = 1, arg.n do
        if type(arg[i]) == "string" then
            s = s .. arg[i]
        else
            s = s .. inspect(arg[i]) --Serpent.simple(arg[i])
        end
        if i < arg.n then
            s = s .. "\t"
        end
    end
    if (tracefile) then
        tracefile:write(s .. "\n")
        tracefile:flush()
    end
end

local function formatLogString(loggerName, debugInfo, arg)
    local s = os.date("[%d %b %Y %H:%M:%S]\t") .. loggerName
    local src = ""
    if debugInfo then
        src = string.gsub(debugInfo.source, ".\\", "") .. ":" .. debugInfo.currentline
        s = s .. src .. "\t"
    end
    for i = 1, arg.n do
        if type(arg[i]) == "string" then
            s = s .. arg[i]
        else
            s = s .. inspect(arg[i]) --Serpent.simple(arg[i])
            -- s = s .. tostring(arg[i])
        end

        if i < arg.n then
            s = s .. "\t"
        end
    end
    return s, src
end

function Log(...)
    local arg = table.pack(...)
    local s = os.date("[%d %b %Y %H:%M:%S]\t")
    local info = debug.getinfo(2)

    if info then
        local src = string.gsub(info.source, ".\\", "")
        s = s .. src .. ":" .. info.currentline .. "\t"
    end
    for i = 1, arg.n do
        if type(arg[i]) == "string" then
            s = s .. arg[i]
        else
            s = s .. inspect(arg[i]) --Serpent.simple(arg[i])
        end
        if i < arg.n then
            s = s .. "\t"
        end
    end
    io.write(s .. "\n")
end


pollnet = require("pollnet")

Log("Checking data dir...")

local function checkDataDir()
    local cwd, err = LFS.currentdir()
    if cwd == nil then
        Log("Can't get the current dir, exiting")
        wx.wxMessageBox("Can't get the current dir, exiting. " .. (err or ""),
            "Strimble Error",
            wx.wxOK + wx.wxICON_EXCLAMATION,
            wx.NULL)
        return false
    end
    
    local chdirRes, err = LFS.chdir(DataDir)
    if chdirRes then
        Log("Data dir OK")
        LFS.chdir(cwd)
        return true
    end

    -- trying to create the data dir in case it couldn't chdir into it
    local mkdirRes, err = LFS.mkdir(DataDir)
    if mkdirRes then
        Log("Data dir created")
        LFS.chdir(cwd)
        return true
    end

    -- something went wrong and the data dir is not found and can't be created
    Log("Can't get or create data dir, exiting")
    wx.wxMessageBox("Can't get or create data dir, exiting. " .. (err or ""),
        "Strimble Error",
        wx.wxOK + wx.wxICON_EXCLAMATION,
        wx.NULL)

    LFS.chdir(cwd)
    return false
end

if not checkDataDir() then
    return
end

-- print("locking")
local count = 0
local lock = nil
Log("Checking if already running...")
repeat
    if count == 1 then
        Log("Waiting for another app to exit...")
    end
    lock = LFS.lock_dir(DataDir, 1)
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

AppConfig = wx.wxFileConfig("", "", DataDir .. "/strimble.ini", "", wx.wxCONFIG_USE_LOCAL_FILE)

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

Logger = {
    loggers = {}
}

Logger.create = function(name)
    if not Logger.loggers[name] then
        local enabled = ReadFromCfg("logging", name, 0)
        -- Log(name, enabled == 1)
        local logger = {
            enabled = enabled == 1,
            name_str = "[" .. name .. "]\t"
        }
        logger.log = function(...)
            local arg = table.pack(...)
            local info = debug.getinfo(2)
            local s, src = formatLogString(logger.name_str, info, arg)
            
            if logger.enabled then
                io.write(s .. "\n")
            end
            if tracing then
                Trace(src, ...)
            end
        end

        logger.force = function(...)
            local arg = table.pack(...)
            local info = debug.getinfo(2)
            local s, src = formatLogString(logger.name_str, info, arg)
            
            io.write(s .. "\n")
            
            if tracing then
                Trace(src, ...)
            end
        end

        logger.err = logger.force   -- maybe change it to its own function

        Logger.loggers[name] = logger
    end
    return Logger.loggers[name]
end

Lutf8 = require("lua-utf8")
NetworkManager = require("src/netutils")
Json = require("json")
-- require("winsock")

-- local _sq = package.loadlib("bin/sqlite3.dll", "sqlite3_version") -- hack to preload sqlite3 dll
-- local _vw2 = package.loadlib("bin/WebView2Loader.dll", "GetAvailableCoreWebView2BrowserVersionString")  -- hack to preload webview dll
Sqlite = require("lsqlite3complete")
require("src/stuff/db_helper")  -- adds global Db
DataDb = Sqlite.open(DataDir .. "/data.sqlite3")

function CopyTable(data)
    local result = {}
    for k, v in pairs(data) do
        result[k] = v
    end
    return result
end

dofile("src/migrations/migrations.lua")  -- do this for db file!

Twitch = require("src/integrations/twitch")

Integrations = {}

-- UI init
dofile("src/xml_ui.lua")
local audio = require("src/stuff/audio")

audio.init()
-- run
main()
if is_wx_app then
    wx.wxGetApp():MainLoop()
end

if tracing then
    io.close(tracefile)
end

-- cleanup
if Db and Db:isopen() then
    Db:close()  -- probably don't need this for in-memory db
end
if DataDb and DataDb:isopen() then
    DataDb:close()
end
audio.destroy()
