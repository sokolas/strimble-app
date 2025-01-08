set INSTALL_DIR=%cd%\deps
@git clone https://github.com/stevedonovan/winapi.git

cd winapi
set CFLAGS= /O1 /DPSAPI_VERSION=1  /I"%INSTALL_DIR%\include\luajit-2.1"
cl /nologo -c %CFLAGS% winapi.c
cl /nologo -c %CFLAGS% wutils.c
link /nologo winapi.obj wutils.obj /EXPORT:luaopen_winapi  /LIBPATH:"%INSTALL_DIR%\lib" msvcrt.lib kernel32.lib user32.lib psapi.lib advapi32.lib shell32.lib  Mpr.lib lua51.lib  /DLL /OUT:winapi.dll
