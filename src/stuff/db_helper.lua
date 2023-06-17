Db = Sqlite.open_memory()

function LoadDb()
    if Db and Db:isopen() then
        Db:close()
        Db = nil
    end
    Db = Sqlite.open_memory()

    local db = Sqlite.open("data/config.sqlite3")
    local backup = Sqlite.backup_init(Db, "main", db, "main")
    if not backup then
        Log(Db:errmsg())
    else
        local bres = backup:step(-1)
        if bres ~= Sqlite.DONE then
            Log(bres, Db:errmsg())
        else
            Log("DB load OK")
        end
        backup:finish()
    end
    db:close()
    db = nil
end

function SaveDb()
    local db = Sqlite.open("data/config.sqlite3")
    local backup = Sqlite.backup_init(db, "main", Db, "main")
    if not backup then
        Log(db:errmsg())
    else
        local bres = backup:step(-1)
        if bres ~= Sqlite.DONE then
            Log(bres, db:errmsg())
        else
            Log("DB save OK")
        end
        backup:finish()
    end
    db:close()
end