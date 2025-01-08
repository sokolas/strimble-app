set INSTALL_DIR=%cd%\deps
@got clone https://github.com/wxWidgets/wxWidgets.git

cd wxWidgets
git checkout "v3.2.6"
git submodule update --init --recursive
cd build\msw
nmake /f makefile.vc BUILD=MinSizeRel SHARED=1 TARGET_CPU=X64 MONOLITHIC=1 RUNTIME_LIBS=static
mkdir %INSTALL_DIR%\vc_x64_dll
cd ..\..
xcopy lib\vc_x64_dll\mswu ..\deps\lib\vc_x64_dll\mswu\ /s /e /i
xcopy lib\vc_x64_dll\*.dll ..\deps\lib\vc_x64_dll\
xcopy lib\vc_x64_dll\*.lib ..\deps\lib\vc_x64_dll\
xcopy include\* ..\deps\include\ /s /e
