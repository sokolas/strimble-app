# Strimble
![](https://www.strimble.app/img/actions.png)

Strimble (funny way of saying *stream*) is an integration center for live streamers, with the focus on customization and extensibility.
"Integration center" means it's not just a Twitch chat bot, but a program that can connect to a lot of other programs often used by strimblers, like OBS or VTube Studio, and online services (donations, etc).
With extensibility and open source in mind, Strimble can connect virtually to anything, with the help of pluging and scripts.

# Vision and Goals
* **open source**: this kind of software is not rocket science, there are no secrets and know-hows to keep, and I hope this project inspires others to create their own tools like this.
* **extensibility**: this is the main goal of writing Strimble; need a new integration or action? Just look for a script/plugin that does that or write it yourself!
* **modularity**: everything (well, within reason) should be pluggable. Don't need that VTube Studio integration? Turn it off, and never browse through 20 tabs of useless stuff (I'm looking at you, streamerbot)
* **Lua** as the main language: it is widely used for creating and modding games, and there are a lot of people who have some degree of experience with it.
* **Native look-and-feel** and the controls most Windows users are familiar with. No fancy skins, browser-as-an-app, 10 different variants of buttons, or weird foreign toolkits. If you know how to use classic Windows programs, you should have no issues with using Strimble.
* **No official Discord**: all the documentation and discussions (with ideas, questions, and solutions) must be indexed by the search engines, and accessible for anyone, without the need to create an account in yet another service.
  For now, there are [discussions](https://github.com/sokolas/strimble-app/discussions) and [wiki](https://github.com/sokolas/strimble-app/wiki) hosted right here on Github.

# Installation
Get the [latest release](https://github.com/sokolas/strimble-app/releases/latest), unzip it, and run strimble.exe. Everything is kept in that folder. Want to uninstall it or start fresh? Just delete it!

# Usage
Please refer to the [wiki](https://github.com/sokolas/strimble-app/wiki) for guildes/tutorials and [discussions](https://github.com/sokolas/strimble-app/discussions) for troubleshooting.

# Structure
Strimble consists of the binary "core" and Lua "main application". The "core" is the starter and a set of libraries that have to be compiled into DLLs. Most of them are included in this repo as git submodules.
Normally, there's little need to update or modify those. Some of them were forked by me in order to adjust the build process or some settings that were not worth merging back into the main repo.
lua-sqlite, for example, was fully copied because it is hosted on Fossil and it's just not possible to have it as a submodule.

`3rdparty` is for the libraries that need to be compiled;

`data` is where the user data is stored. It should be kept as empty as possible.

`images` are the icons and other images used in the UI. 

`lualibs` is for Lua libraries. While it is possible to have them in `src` as well, it's better to keep everything that doesn't directly belong to this project a bit separated.

`scripts` is for extensions (not implemented yet). The examples would also go there.

`src` is the directory with the main logic.

`starter` is an old C starter, it's not really needed, most probably will be deleted at some point.

`bin` (not in the repo, but is in the end-user release archive) is for the DLLs. I would like to keep all the DLLs there, but it's just too cumbersome for the "core" libraries, wxWidgets and Lua itself, and those are kept in the root dir.

> All of the libraries used have compatible licenses; they are either in their repos, in their respective directories, or directly in the files. If you notice any 3rd party code missing a license, it is not intentional. Please open an issue so it can be fixed!

# Development

If you don't need to modify or add your own binary libraries, and only want to work on the main (Lua) part, then the best way to develop Strimble would be the following:
* clone this repo *without submodules*
* download the release
* copy `bin` and all `.exe` and `.dll` files from the root directory of the release to the repo

  
Binaries are ignored by git so that shouldn't be an issue when commiting the changes.
The entry point to Lua code is `src/main.lua` and that path is hard-coded into the starter.
Open the code in your favourite editor, hack away, and then run `strimble.exe` to test it.

The UI is build using [wxFormBuilder](https://github.com/wxFormBuilder/wxFormBuilder). `.fbp` project file is converter into `.xrc` taht can be loaded by the main application.
The set of controls that it supports *somewhat* overlaps with the set of controls that wxLua supports, so it's not the full UI, just the basic structure.

If you need to build the supporting libraries yourself, take a look at the [github workflow](https://github.com/sokolas/strimble-app/blob/main/.github/workflows/main.yml). You can find all the build commands for those there.
Currently the build is tested with Visual Studio 2019 and 2022. It *may* work with MSYS/MinGW, but is not guaranteed.
