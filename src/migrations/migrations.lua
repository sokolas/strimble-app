local db = Sqlite.open("data/config.sqlite3")

local res = db:exec([[
    create table if not exists triggers (id integer primary key, name, type, data);
    create table if not exists actions (id integer primary key, name, data);
    create table if not exists steps (id integer primary key, action integer not null, step_order integer not null, name, type, data);
]])
if res then
    Log("migrations done")
else
    Log("migrations error", db:errmsg())
end
db:close()