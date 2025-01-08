set INSTALL_DIR=%cd%\deps

@git clone https://github.com/lunarmodules/luafilesystem
cd luafilesystem
cl /c /O1 /MD /I%INSTALL_DIR%\include\luajit-2.1 src\lfs.c
link /dll /def:src\lfs.def /out:lfs.dll lfs.obj "%INSTALL_DIR%\lib\lua51.lib"