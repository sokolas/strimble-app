#!/bin/bash

#Batch script to build Strimble App

windres resources/res/app.rc -o app.o
# gcc -Os -s -mwindows -static-libgcc -mfpmath=sse -mieee-fp -fno-exceptions -fdata-sections -ffunction-sections -Wl,--gc-sections -fipa-pta -ffreestanding -fno-stack-check -fno-ident -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -Wl,--build-id=none -Wl,-O1 -Wl,--as-needed -Wl,--no-insert-timestamp -Wl,--no-seh -flto -o "../strimble.exe" win32_starter.c app.o -lshlwapi
gcc -O2 -s -mwindows -mfpmath=sse -mieee-fp -fno-exceptions -fdata-sections -ffunction-sections -Wl,--gc-sections -fipa-pta -ffreestanding -fno-stack-check -fno-ident -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -Wl,--build-id=none -Wl,-O1 -Wl,--as-needed -Wl,--no-insert-timestamp -Wl,--no-seh -flto -o "../strimble.exe" win32_starter.c app.o -lshlwapi
rm app.o