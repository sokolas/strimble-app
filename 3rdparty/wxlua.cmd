set INSTALL_DIR=%cd%\deps

@git clone https://github.com/sokolas/wxlua.git

cd wxlua\wxLua

cmake -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" -DCMAKE_BUILD_TYPE="MinSizeRel" -DBUILD_SHARED_LIBS=TRUE ^
    -DCMAKE_CXX_FLAGS="-DLUA_COMPAT_MODULE /EHsc" ^
    -DwxWidgets_COMPONENTS="mono" ^
    -DwxLuaBind_COMPONENTS="xrc;xml;media;richtext;propgrid;html;adv;core;net;base" ^
    -DwxWidgets_CONFIGURATION="mswu" ^
    -DwxWidgets_ROOT_DIR="%INSTALL_DIR%" ^
    -DwxWidgets_VERSION="3.2.6" ^
    -DwxWidgets_LIB_DIR="%INSTALL_DIR%/lib/vc_x64_dll" ^
    -DwxLua_LUA_LIBRARY_USE_BUILTIN=FALSE ^
    -DwxLua_LUA_INCLUDE_DIR="%INSTALL_DIR%/include/luajit-2.1" -DwxLua_LUA_LIBRARY="%INSTALL_DIR%/lib/lua51.lib" .

msbuild ALL_BUILD.vcxproj /p:configuration=MinSizeRel /p:platform=x64
@rem msbuild INSTALL.vcxproj /p:configuration=MinSizeRel /p:platform=x64

copy bin\MinSizeRel\wx.dll %INSTALL_DIR%\bin\clibs\wx.dll
