export INSTALL_DIR=`pwd`/deps
export STRIMBLE_ROOT=`pwd`

# prerequisites: build-essentials, cmake, libssl-dev, libgtk-3-devel

# luajit
cd strimble-starter/LuaJIT

make PREFIX="$INSTALL_DIR" CFLAGS=-DLUAJIT_ENABLE_LUA52COMPAT
make install PREFIX="$INSTALL_DIR"

cd $STRIMBLE_ROOT

# starter
cd starter-linux
g++ -I "$INSTALL_DIR/include/luajit-2.1/" -L "$INSTALL_DIR/lib/" starter.cpp -lluajit-5.1 -o strimble
cp strimble "$INSTALL_DIR/bin"

cd $STRIMBLE_ROOT

# wxwidgets
cd 3rdparty/wxWidgets/build/cmake
cmake -G "Unix Makefiles" "../.." -DCMAKE_BUILD_TYPE="MinSizeRel" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DwxBUILD_COMPATIBILITY="3.0" -DwxBUILD_MONOLITHIC=ON
cmake --build .
cmake --build . --target install
cd $STRIMBLE_ROOT

# wxlua
cd 3rdparty/wxlua/wxLua/build
cmake -G "Unix Makefiles" ".." -DCMAKE_BUILD_TYPE="MinSizeRel" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DBUILD_SHARED_LIBS=TRUE \
            -DCMAKE_CXX_FLAGS="-DLUA_COMPAT_MODULE" \
            -DwxWidgets_COMPONENTS="mono" \
            -DwxLuaBind_COMPONENTS="xrc;xml;media;richtext;propgrid;html;adv;core;net;base" \
            -DwxWidgets_CONFIGURATION="gtk3u" \
            -DwxWidgets_ROOT_DIR="$INSTALL_DIR" \
            -DwxWidgets_VERSION="3.2.6" \
            -DwxWidgets_LIB_DIR="$INSTALL_DIR/lib/" \
            -DwxLua_LUA_LIBRARY_USE_BUILTIN=FALSE \
            -DwxLua_LUA_INCLUDE_DIR="$INSTALL_DIR/include/luajit-2.1" -DwxLua_LUA_LIBRARY="$INSTALL_DIR/lib/libluajit-5.1.so"
cmake --build .
cmake --build . --target install
cd "$INSTALL_DIR/lib"
ln -s libwx.so wx.so
cd $STRIMBLE_ROOT

# pollnet
cd 3rdparty/pollnet
cargo build --release
cp target/release/libpollnet.so "$INSTALL_DIR/lib/lua/5.1/libpollnet.so"
# TODO bin/clibs
cd $STRIMBLE_ROOT

# lfs
cd 3rdparty/luafilesystem
gcc -shared -O2 -Wall -fPIC -W -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic -I"$INSTALL_DIR/include/luajit-2.1" -L"$INSTALL_DIR/lib" src/lfs.c -o lfs.so -lluajit-5.1
cp lfs.so "$INSTALL_DIR/lib/lua/5.1/lfs.so"
cd $STRIMBLE_ROOT

# lua-utf8

cd 3rdparty/luautf8
gcc -shared -O2 -Wall -fPIC -W -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic -I"$INSTALL_DIR/include/luajit-2.1" -L"$INSTALL_DIR/lib" lutf8lib.c -o lua-utf8.so -lluajit-5.1
cp lua-utf8.so "$INSTALL_DIR/lib/lua/5.1/lua-utf8.so"
cd $STRIMBLE_ROOT

# lsqlite3
cd 3rdparty/lsqlite
gcc -shared -O2 -Wall -fPIC -W -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic -I"$INSTALL_DIR/include/luajit-2.1" -L"$INSTALL_DIR/lib" -DLSQLITE_VERSION=\"0.9.5\" -Dluaopen_lsqlite3=luaopen_lsqlite3complete -DSQLITE_ENABLE_JSON1=1 sqlite3.c lsqlite3.c -o lsqlite3complete.so -lluajit-5.1
cp lsqlite3complete.so "$INSTALL_DIR/lib/lua/5.1/lsqlite3complete.so"
cd $STRIMBLE_ROOT

# raudio
cd 3rdparty/raudio/projects/CMake
#cmake -DSUPPORT_MODULE_RAUDIO=TRUE -DRAUDIO_STANDALONE=TRUE -DSUPPORT_SHARED_LIBRARY=TRUE -DSUPPORT_FILEFORMAT_WAV=TRUE -DSUPPORT_FILEFORMAT_OGG=TRUE -DSUPPORT_FILEFORMAT_MP3=TRUE -DSUPPORT_FILEFORMAT_FLAC=TRUE
cmake -DSUPPORT_MODULE_RAUDIO=TRUE -DSUPPORT_SHARED_LIBRARY=TRUE -DSUPPORT_FILEFORMAT_WAV=TRUE -DSUPPORT_FILEFORMAT_OGG=TRUE -DSUPPORT_FILEFORMAT_MP3=TRUE -DSUPPORT_FILEFORMAT_FLAC=TRUE
cmake --build . --target raudio
cp libraudio.so "$INSTALL_DIR/lib/lua/5.1/libraudio.so"
cd $STRIMBLE_ROOT

# run

# LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/user/strimble-app/deps/lib/ ./strimble
