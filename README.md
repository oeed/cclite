CCLite ComputerCraft Emulator
=============================

**Description:**

This is a ComputerCraft Emulator written in Love2D. It is not complete, and is still a work in progress.

I will not be handing out builds for this emulator. To use it, [download Love2D 0.9.0](http://love2d.org/) and use the build_src.bat to produce a .love file.

If you have installed Love2D you can just double click on the .love file to run it.

The [forum topic](http://www.computercraft.info/forums2/index.php?/topic/13445-lightweight-cc-emulator-download-now/) for CCLite is from the original author, Sorroko, and features in mine are not guarenteed to be in his, vice versa.

**HTTPS Support:**

For HTTPS support, you'll need to grab:

From LuaSec: [Binaries](http://50.116.63.25/public/LuaSec-Binaries/), [Lua Code](http://www.inf.puc-rio.br/~brunoos/luasec/download/luasec-0.4.1.tar.gz):

  * ssl.dll or ssl.so -> ssl.dll or ssl.so
  
  * luasec-luasec-0.4.1/src/ssl.lua -> ssl.lua
  
  * luasec-luasec-0.4.1/src/https.lua -> ssl/https.lua
  
You most likely also need to instal OpenSSL: [Windows](http://slproweb.com/products/Win32OpenSSL.html)

Place these files where the love executable can get to them, most likely where love is installed.

Then go into conf.lua and set useLuaSec to true

**Screenshots:**

![Demonstration](http://i.imgur.com/87PL9Nb.png)

**NOTES:**

My fork of CCLite has a different save directory than Sorroko's version. Mine will save to the "ccemu" folder while his saves to "cclite"

TODO:
-----

Add in more error checking

Add in virtual redstone system

Make Error Levels report C functions properly

Make peripheralAttach only add valid sides

Have virtual Disk Drives work with Treasure disks

Make virtual Disk Drives use mounting system

**Add in missing globals:**

  * __inext
