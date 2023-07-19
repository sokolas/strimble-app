#!/bin/bash

# exit if the command line is empty
if [ $# -eq 0 ]; then
  echo "Usage: $0 LIBRARY..."
  exit 0
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" # per http://stackoverflow.com/a/246128

# binary directory
BIN_DIR="$DIR/bin"

# temporary installation directory for dependencies
INSTALL_DIR="$DIR/deps"

# number of parallel jobs used for building
MAKEFLAGS="-j1" # some make may hang on Windows with j4 or j7

# flags for manual building with gcc
BUILD_FLAGS="-Os -static-libgcc -shared -s -I $INSTALL_DIR/include -L $INSTALL_DIR/lib"

# paths configuration
WXWIDGETS_BASENAME="wxWidgets"
WXWIDGETS_URL="https://github.com/wxWidgets/wxWidgets.git"

WXLUA_BASENAME="wxlua"
WXLUA_URL="https://github.com/sokolas/wxlua.git"

LUASOCKET_BASENAME="luasocket-master"
LUASOCKET_FILENAME="luasocket-master.zip"
# LUASOCKET_URL="https://github.com/lunarmodules/luasocket/archive/refs/heads/master.zip"
LUASOCKET_URL="https://raw.githubusercontent.com/lunarmodules/luasocket/master/src/url.lua"

OPENSSL_BASENAME="openssl-1.1.1t"
OPENSSL_FILENAME="$OPENSSL_BASENAME.tar.gz"
OPENSSL_URL="http://www.openssl.org/source/$OPENSSL_FILENAME"

LUASEC_BASENAME="luasec-master"
LUASEC_FILENAME="luasec-master.zip"
# LUASEC_URL="https://github.com/brunoos/luasec/archive/$LUASEC_FILENAME"
LUASEC_URL="https://github.com/brunoos/luasec/archive/refs/heads/master.zip"

LFS_BASENAME="1_8_0"
LFS_FILENAME="$LFS_BASENAME.zip"
LFS_URL="https://github.com/lunarmodules/luafilesystem/archive/refs/tags/v1_8_0.zip"

LPEG_BASENAME="lpeg-1.0.0"
LPEG_FILENAME="$LPEG_BASENAME.tar.gz"
LPEG_URL="http://www.inf.puc-rio.br/~roberto/lpeg/$LPEG_FILENAME"

LEXLPEG_BASENAME="scintillua_3.6.5-1"
LEXLPEG_FILENAME="$LEXLPEG_BASENAME.zip"
LEXLPEG_URL="https://github.com/orbitalquark/scintillua/archive/refs/tags/$LEXLPEG_FILENAME"

WINAPI_BASENAME="winapi"
WINAPI_URL="https://github.com/stevedonovan/winapi.git"

WXWIDGETSDEBUG="--disable-debug"
WXLUABUILD="MinSizeRel"

WEBVIEWEDGE_URL="https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.1823.32"
WEBVIEW_FILENAME="1.0.1823.32"

LSQLITE_URL="https://luarocks.org/manifests/dougcurrie/lsqlite3complete-0.9.5-1.src.rock"
LSQLITE_BASE_NAME="lsqlite3_fsl09y"

LUAUTF8_URL="https://github.com/starwing/luautf8.git"

POLLNET_URL="https://github.com/probable-basilisk/pollnet.git"

JSON_URL="https://raw.githubusercontent.com/rxi/json.lua/master/json.lua"

# please use ALL
# iterate through the command line arguments
for ARG in "$@"; do
  case $ARG in
  jit)
    BUILD_LUA=true
    BUILD_JIT=true
    ;;
  wxwidgets)
    BUILD_WXWIDGETS=true
    ;;
  wxlua)
    BUILD_WXLUA=true
    ;;
  winapi)
    BUILD_WINAPI=true
    ;;
  lfs)
    BUILD_LFS=true
    ;;
  utf)
    BUILD_LUTF8=true
    ;;
  sqlite)
    BUILD_SQLITE=true
    ;;
  pollnet)
    BUILD_POLLNET=true
    ;;
  json)
    BUILD_JSON=true
    ;;
  debug)
    WXWIDGETSDEBUG="--enable-debug=max --enable-debug_gdb"
    WXLUABUILD="Debug"
    DEBUGBUILD=true
    ;;
  all)
    BUILD_LUA=true
    BUILD_JIT=true
    BUILD_WXWIDGETS=true
    BUILD_WXLUA=true
    BUILD_LFS=true
    BUILD_WINAPI=true
    BUILD_LUTF8=true
    BUILD_SQLITE=true
    BUILD_POLLNET=true
    BUILD_JSON=true
    ;;
  *)
    echo "Error: invalid argument $ARG"
    exit 1
    ;;
  esac
done

# check for g++
if [ ! "$(which g++)" ]; then
  echo "Error: g++ isn't found. Please install MinGW C++ compiler."
  exit 1
fi

# check for cmake
if [ ! "$(which cmake)" ]; then
  echo "Error: cmake isn't found. Please install CMake and add it to PATH."
  exit 1
fi

# check for git
if [[ ! "$(which git)" ]]; then
  echo "Error: git isn't found. Please install console GIT client."
  exit 1
fi

# check for wget
if [ ! "$(which wget)" ]; then
  echo "Error: wget isn't found. Please install GNU Wget."
  exit 1
fi

# create the installation directory
mkdir -p "$INSTALL_DIR" || { echo "Error: cannot create directory $INSTALL_DIR"; exit 1; }

LUAV="51"
LUAS=""
LUA_BASENAME="lua-5.1.5"

LUA_FILENAME="$LUA_BASENAME.tar.gz"
LUA_URL="http://www.lua.org/ftp/$LUA_FILENAME"
LUA_COMPAT=""

if [ $BUILD_JIT ]; then
  LUA_BASENAME="luajit"
  LUA_URL="https://luajit.org/git/luajit.git"
fi

# build Lua
if [ $BUILD_LUA ]; then
#  : <<'END'
  if [ $BUILD_JIT ]; then
    git clone "$LUA_URL" "$LUA_BASENAME"
    (cd "$LUA_BASENAME"; git checkout v2.1)
  else
    wget -c "$LUA_URL" -O "$LUA_FILENAME" || { echo "Error: failed to download Lua"; exit 1; }
    tar -xzf "$LUA_FILENAME"
  fi
  cd "$LUA_BASENAME"
  if [ $BUILD_JIT ]; then
    make CCOPT="-DLUAJIT_ENABLE_LUA52COMPAT" || { echo "Error: failed to build Lua"; exit 1; }
    make install PREFIX="$INSTALL_DIR"
    cp "$INSTALL_DIR/bin/luajit-2.1.0-beta3.exe" "$INSTALL_DIR/bin/lua.exe"
  else
    # need to patch Lua io to support large (>2GB) files on Windows:
    # http://lua-users.org/lists/lua-l/2015-05/msg00370.html
    cat <<EOF >>src/luaconf.h
#if defined(liolib_c) && defined(__MINGW32__)
#include <sys/types.h>
#define l_fseek(f,o,w) fseeko64(f,o,w)
#define l_ftell(f) ftello64(f)
#define l_seeknum off64_t
#endif
EOF
    make mingw $LUA_COMPAT || { echo "Error: failed to build Lua"; exit 1; }
    make install INSTALL_TOP="$INSTALL_DIR"
  fi
  cp src/lua$LUAV.dll "$INSTALL_DIR/lib"
  cp "$INSTALL_DIR/bin/lua.exe" "$INSTALL_DIR/bin/lua$LUAV.exe"
  [ -f "$INSTALL_DIR/lib/lua$LUAV.dll" ] || { echo "Error: lua$LUAV.dll isn't found"; exit 1; }
  [ $DEBUGBUILD ] || strip --strip-unneeded "$INSTALL_DIR/lib/lua$LUAV.dll"
  cd ..
  # rm -rf "$LUA_FILENAME" "$LUA_BASENAME"
fi

# build wxWidgets
if [ $BUILD_WXWIDGETS ]; then
  if [ ! -d "$WXWIDGETS_BASENAME" ]; then
    git clone "$WXWIDGETS_URL" "$WXWIDGETS_BASENAME" || { echo "Error: failed to get wxWidgets"; exit 1; }
  fi

  cd "$WXWIDGETS_BASENAME"

  # checkout the version that was used in wxwidgets upgrade to 3.1.x
  git checkout "v3.2.2.1"
  # git checkout master

  # refresh wxwidgets submodules
  git submodule update --init --recursive

  # remove rand_s, which doesn't link with mingw/gcc 4.8.x; will use fallback
  # sed -i 's/rand_s(&random32)/1/' src/expat/expat/lib/xmlparse.c

  # enable direct2d support
  sed -i 's/#define wxUSE_GRAPHICS_DIRECT2D 0/#define wxUSE_GRAPHICS_DIRECT2D wxUSE_GRAPHICS_CONTEXT/' setup.h.in

  wget $WEBVIEWEDGE_URL || { echo "error: failed to download webview2"; exit 1; }
  mv $WEBVIEW_FILENAME "webview.zip"
  unzip webview.zip -d "3rdparty/webview2" || { echo "error: failed to unzip webview2"; exit 1; }
  # rm webview.zip
  # read -p "press enter"

  ./configure --prefix="$INSTALL_DIR" $WXWIDGETSDEBUG --disable-shared \
    --enable-compat30 \
    --enable-privatefonts \
    --enable-webviewedge \
    --with-libjpeg=builtin --with-libpng=builtin --with-libtiff=builtin --with-expat=builtin \
    --with-zlib=builtin \
    CFLAGS="-Os -fno-keep-inline-dllexport" CXXFLAGS="-Os -fno-keep-inline-dllexport -DNO_CXX11_REGEX"
  make $MAKEFLAGS || { echo "Error: failed to build wxWidgets"; exit 1; }
  make install
  
  cd ..
  # rm -rf "$WXWIDGETS_BASENAME"
fi

# build wxLua
if [ $BUILD_WXLUA ]; then
  if [ ! -d "$WXLUA_BASENAME" ]; then
    git clone "$WXLUA_URL" "$WXLUA_BASENAME" || { echo "Error: failed to get wxlua"; exit 1; }
  fi

  cd "$WXLUA_BASENAME/wxLua"

  # git checkout v3.2.0.2

  sed -i 's|:-/\(.\)/|:-\1:/|' "$INSTALL_DIR/bin/wx-config"

  # remove check for Lua 5.2 as it doesn't work with Twoface ABI mapper
  sed -i 's/LUA_VERSION_NUM < 502/0/' modules/wxlua/wxlcallb.cpp

  echo "set_target_properties(wxLuaModule PROPERTIES LINK_FLAGS -static)" >> modules/luamodule/CMakeLists.txt
  cmake -G "MSYS Makefiles" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DCMAKE_BUILD_TYPE=$WXLUABUILD -DBUILD_SHARED_LIBS=FALSE \
    -DCMAKE_CXX_FLAGS="-DLUA_COMPAT_MODULE" \
    -DwxWidgets_CONFIG_EXECUTABLE="$INSTALL_DIR/bin/wx-config" \
    -DwxWidgets_COMPONENTS="webview;xrc;xml;media;richtext;propgrid;gl;html;adv;core;net;base" \
    -DwxLuaBind_COMPONENTS="webview;xrc;xml;media;richtext;propgrid;gl;html;adv;core;net;base" \
    -DwxLua_LUA_LIBRARY_USE_BUILTIN=FALSE \
    -DwxLua_LUA_INCLUDE_DIR="$INSTALL_DIR/include/luajit-2.1" -DwxLua_LUA_LIBRARY="$INSTALL_DIR/lib/lua$LUAV.dll" .
  (cd modules/luamodule; make $MAKEFLAGS) || { echo "Error: failed to build wxLua"; exit 1; }
  (cd modules/luamodule; make install)
  [ -f "$INSTALL_DIR/bin/libwx.dll" ] || { echo "Error: libwx.dll isn't found"; exit 1; }
  [ $DEBUGBUILD ] || strip --strip-unneeded "$INSTALL_DIR/bin/libwx.dll"
  cd ../..
  # rm -rf "$WXLUA_BASENAME"
fi

# build lfs
if [ $BUILD_LFS ]; then
  wget --no-check-certificate -c "$LFS_URL" -O "$LFS_FILENAME" || { echo "Error: failed to download lfs"; exit 1; }
  unzip "$LFS_FILENAME"
  mv "luafilesystem-$LFS_BASENAME" "$LFS_BASENAME"
  cd "$LFS_BASENAME/src"
  mkdir -p "$INSTALL_DIR/lib/lua/$LUAV/"
  gcc $BUILD_FLAGS -I "$INSTALL_DIR/include/luajit-2.1" -o "$INSTALL_DIR/lib/lua/$LUAV/lfs.dll" lfs.c -llua$LUAV \
    || { echo "Error: failed to build lfs"; exit 1; }
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/lfs.dll" ] || { echo "Error: lfs.dll isn't found"; exit 1; }
  [ $DEBUGBUILD ] || strip --strip-unneeded "$INSTALL_DIR/lib/lua/$LUAV/lfs.dll"
  cd ../..
  rm -rf "$LFS_FILENAME" "$LFS_BASENAME"
fi

# build winapi
if [ $BUILD_WINAPI ]; then
  git clone "$WINAPI_URL" "$WINAPI_BASENAME"
  cd "$WINAPI_BASENAME"
  mkdir -p "$INSTALL_DIR/lib/lua/$LUAV/"
  gcc $BUILD_FLAGS -DPSAPI_VERSION=1 -I "$INSTALL_DIR/include/luajit-2.1" -o "$INSTALL_DIR/lib/lua/$LUAV/winapi.dll" winapi.c wutils.c -lpsapi -lmpr -llua$LUAV \
    || { echo "Error: failed to build winapi"; exit 1; }
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/winapi.dll" ] || { echo "Error: winapi.dll isn't found"; exit 1; }
  [ $DEBUGBUILD ] || strip --strip-unneeded "$INSTALL_DIR/lib/lua/$LUAV/winapi.dll"
  cd ..
  # rm -rf "$WINAPI_BASENAME"
fi

if [ $BUILD_LUTF8 ]; then
  git clone "$LUAUTF8_URL" "lutf8"
  cd lutf8
  gcc -Os -static-libgcc -shared -s -I "$INSTALL_DIR/include/luajit-2.1" -L "$INSTALL_DIR/lib" -llua51 lutf8lib.c -o "$INSTALL_DIR/lib/lua/$LUAV/lua-utf8.dll"
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/lua-utf8.dll" ] || { echo "Error: lua-utf8.dll isn't found"; exit 1; }
  cd ..
fi

if [ $BUILD_POLLNET ]; then
  git clone "$POLLNET_URL" "pollnet"
  cd pollnet
  cargo build --release
  sed -i 's/LIBDIR\s=\s\"\.\/\"/LIBDIR = \"bin\/clibs\/\"/' bindings/luajit/pollnet.lua
  [ -f "target/release/pollnet.dll" ] || { echo "Error: pollnet.dll isn't found"; exit 1; }

  cd ..
fi

if [ $BUILD_SQLITE ]; then
  wget "$LSQLITE_URL" -O "lsqlite.zip"
  unzip lsqlite.zip -d lsqlite
  cd lsqlite
  unzip "$LSQLITE_BASE_NAME.zip"
  cd "$LSQLITE_BASE_NAME"
  gcc -Os -static-libgcc -DLSQLITE_VERSION=\"0.9.5\" -Dluaopen_lsqlite3=luaopen_lsqlite3complete -DSQLITE_ENABLE_JSON1=1 -shared -s \
    -I "$INSTALL_DIR/include/luajit-2.1" -L "$INSTALL_DIR/lib/" -llua51 -o "$INSTALL_DIR/lib/lua/$LUAV/lsqlite3complete.dll" sqlite3.c lsqlite3.c 
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/lsqlite3complete.dll" ] || { echo "Error: lsqlite3complete.dll isn't found"; exit 1; }
  cd ../..
fi

[ -d "$BIN_DIR/clibs" ] || mkdir -p "$BIN_DIR/clibs" || { echo "Error: cannot create directory $BIN_DIR/clibs"; exit 1; }
if [ $LUAS ]; then
  [ -d "$BIN_DIR/clibs$LUAS" ] || mkdir -p "$BIN_DIR/clibs$LUAS" || { echo "Error: cannot create directory $BIN_DIR/clibs$LUAS"; exit 1; }
fi

[ -d "lualibs" ] || mkdir -p "lualibs" || { echo "Error: cannot create directory lualibs"; exit 1; }

# now copy the compiled dependencies to the correct locations
[ $BUILD_WXWIDGETS ] && cp "$WXWIDGETS_BASENAME/3rdparty/webview2/build/x64/WebView2Loader.dll" "$BIN_DIR/clibs$LUAS/WebView2Loader.dll"
[ $BUILD_WXLUA ] && cp "$INSTALL_DIR/bin/libwx.dll" "$BIN_DIR/clibs$LUAS/wx.dll"
[ $BUILD_LUA ] && cp "$INSTALL_DIR/bin/lua$LUAS.exe" "$INSTALL_DIR/lib/lua$LUAV.dll" "$BIN_DIR"
if [ $BUILD_POLLNET ]; then
  cp "pollnet/target/release/pollnet.dll" "$BIN_DIR/clibs$LUAS/"
  cp "pollnet/bindings/luajit/pollnet.lua" "lualibs"
  mkdir lualibs/socket
  wget "$LUASOCKET_URL" -O lualibs/socket/url.lua
  echo "local _M = {}; return _M" > lualibs/socket.lua
fi
[ $BUILD_JSON ] && wget $JSON_URL -O "lualibs/json.lua"

cp $INSTALL_DIR/lib/lua/$LUAV/*.dll "$BIN_DIR/clibs$LUAS/"

# cp -r "$INSTALL_DIR/share/lua/$LUAV/"* "lualibs"

# To build lua5.1.dll proxy:
# (1) get mkforwardlib-gcc.lua from http://lua-users.org/wiki/LuaProxyDllThree
# (2) run it as "lua mkforwardlib-gcc.lua lua51 lua5.1 X86"
# To build lua5.2.dll proxy:
# (1) get mkforwardlib-gcc-52.lua from http://lua-users.org/wiki/LuaProxyDllThree
# (2) run it as "lua mkforwardlib-gcc-52.lua lua52 lua5.2 X86"

echo "*** Build has been successfully completed ***"
exit 0
