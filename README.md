cclite
======

A cc emulator written in lua

Forum topic: [Link](http://www.computercraft.info/forums2/index.php?/topic/13445-lightweight-cc-emulator-download-now/)

TODO:
-----

Fix random freezes.

Add in more error checking

Add in virtual peripheral types

Add in virtual redstone system

Make peripheral api interface with virtual peripheral system.

Rework the entire fs.open function

**Complete FS api:**

  * append mode
  * binary modes

**Add in missing globals:**

  * __inext
  * bit.*
  * disk.*
  * gps.*
  * os.computerID

**Remove (or hide) extra functions:**

  * math.mod
  * string.gfind
