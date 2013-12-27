cclite
======

A cc emulator written in lua

The forum topic below has a bit outdated and buggy version of cclite and is not recommended for usage.

Forum topic: [Link](http://www.computercraft.info/forums2/index.php?/topic/13445-lightweight-cc-emulator-download-now/)

This branch is a port of cclite to LOVE 0.9.0 and even though 0.9.0 has not been released, it will still be better to do this now then later.

This branch requires a version of Love built on a Fully Resumable VM such as the [LoveJIT builds](http://love2d.org/forums/viewtopic.php?f=3&t=70979#p149956)

**Screenshots:**

![Demonstration](http://i.imgur.com/rcwxN8M.png)

TODO:
-----

Verify all functions work, fix those that are broken.

Fix random freezes.

Add in more error checking

Add in virtual redstone system

Fix odd endPage bug in virtual printer.

Figure out how to manage disk drives and mounting.

Rework the fs.open text read mode to use File objects.

Fix Error Levels

Make peripheralAttach only add valid sides.

**Add in missing globals:**

  * __inext
