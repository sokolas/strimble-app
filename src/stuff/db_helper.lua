local logger = Logger.create("db_helper")

Db = Sqlite.open_memory()

function LoadDb()
    if Db and Db:isopen() then
        Db:close()
        Db = nil
    end
    Db = Sqlite.open_memory()

    local db = Sqlite.open(DataDir .. "/config.sqlite3")
    local backup = Sqlite.backup_init(Db, "main", db, "main")
    if not backup then
        logger.err(Db:errmsg())
    else
        local bres = backup:step(-1)
        if bres ~= Sqlite.DONE then
            logger.err(bres, Db:errmsg())
        else
            logger.log("DB load OK")
        end
        backup:finish()
    end
    db:close()
    db = nil
end

function SaveDb()
    local db = Sqlite.open(DataDir .. "/config.sqlite3")
    local backup = Sqlite.backup_init(db, "main", Db, "main")
    if not backup then
        logger.err(db:errmsg())
    else
        local bres = backup:step(-1)
        if bres ~= Sqlite.DONE then
            logger.err(bres, db:errmsg())
        else
            logger.log("DB save OK")
        end
        backup:finish()
    end
    db:close()
end