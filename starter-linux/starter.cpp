#include "sol.hpp"

void ShowConsole() {
    
}

void HideConsole() {
    
}

// int main()
int main(int argc, char* argv[])
{
    std::vector<std::string> cmdline(argv, argv+argc);
    //std::cout << path;

    std::cout << "hello world from C++\n";
    //std::cout << std::string(lpCmdLine) << std::endl;

    sol::state lua;
    lua.open_libraries();

    lua["ShowConsole"] = ShowConsole;
    lua["HideConsole"] = HideConsole;
    lua["_args"] = cmdline;
    //lua["b"] = std::string(lpCmdLine);
    sol::load_result script = lua.load(
        // "local arg = table.pack(...); \n"
        "xpcall("
        "function()"
        "local f = loadfile('src/main.lua');f();"
        "end,"
        "function(err) print('Uncaught lua script exception',debug.traceback(err)); print('Press Enter...'); io.read() end"
        ")");
    //lua.script("local f = loadfile('main.lua'); f();");
    script();   // pass args
    //Sleep(5000);
    return 0;
}
