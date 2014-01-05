cclite
======

A cc emulator written in lua

The forum topic below has a bit outdated and buggy version of cclite and is not recommended for usage.

Forum topic: [Link](http://www.computercraft.info/forums2/index.php?/topic/13445-lightweight-cc-emulator-download-now/)

Since Love2D 0.9.0 is now being built on LuaJIT by default, a Fully Resumable VM is already given. [Download Love2D 0.9.0](http://love2d.org/)

**Screenshots:**

![Demonstration](http://i.imgur.com/rcwxN8M.png)

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

Don't load HTTP apis when _conf.enableAPI_http is false

**Add in missing globals:**

  * __inext
