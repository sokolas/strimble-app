local arg = table.pack(...);
xpcall(
    function() (loadfile('src/main.lua'))(unpack(arg)); end,
    function(err) io.write('Uncaught lua script exception', debug.traceback(err)); io.flush(); end
)
