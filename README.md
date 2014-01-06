CCLite ComputerCraft Emulator
=============================

**Description:**

This is an experimental branch of CCLite. The goal here is to seperate rendering and emulation so the screen can update while lua is running.

It kinda currently works, but has lots of kinks and design flaws to fix. I do not recommend using this, it seems impossible to Terminate code at the moment.

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

Verify all functions work for 0.9.0 upgrade, fix those that are broken.

Add in more error checking

Add in virtual redstone system

Fix odd endPage bug in virtual printer.

Figure out how to manage disk drives and mounting.

Make Error Levels report C functions properly.

Make peripheralAttach only add valid sides.

Have virtual Disk Drives work with Treasure disks

Don't load HTTP apis when conf.enableAPI_http is false

**Add in missing globals:**

  * __inext
