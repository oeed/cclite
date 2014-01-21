CCLite ComputerCraft Emulator
=============================

**Description:**

This is an experimental branch of CCLite. The goal here is to seperate rendering and emulation so the screen can update while lua is running.

It kinda currently works, but is currently being held together with duct tape. It works. But it may be potentially slower (lua speed wise, renderer is still fast as ever!)

This is a ComputerCraft Emulator written in Love2D. It is not complete, and is still a work in progress.

I will not be handing out builds for this emulator. To use it, [download Love2D 0.9.0](http://love2d.org/) and use the build_src.bat to produce a .love file.

If you have installed Love2D you can just double click on the .love file to run it.

The [forum topic](http://www.computercraft.info/forums2/index.php?/topic/13445-lightweight-cc-emulator-download-now/) for CCLite is from the original author, Sorroko, and features in mine are not guarenteed to be in his, vice versa.

**Screenshots:**

![Demonstration](http://i.imgur.com/WBlscYk.png)

**NOTES:**

My fork of CCLite has a different save directory than Sorroko's version. Mine will save to the "ccemu" folder while his saves to "cclite"

TODO:
-----

Add in more error checking

Add in virtual redstone system

Make Error Levels report C functions properly.

Make peripheralAttach only add valid sides.

Have virtual Disk Drives work with Treasure disks

Make virtual Disk Drives use mounting system

Get Yielding working

**Add in missing globals:**

  * __inext
