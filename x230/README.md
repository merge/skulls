# Skulls - [Thinkpad X230](https://pcsupport.lenovo.com/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x230) and X230T

![seabios_bootmenu](front.jpg)

## Latest release
Get it from our [release page](https://github.com/merge/coreboot-x230/releases)
* __coreboot__: We take coreboot's master branch at the time we build a release image.
* __microcode update__: revision `0x21` from 2019-02-13
* __SeaBIOS__: version [1.12.1](https://seabios.org/Releases) from 2019-02-04

### release images to choose from
We release multiple different, but _very similar_ images you can choose from.
They all should work on all versions of the X230/X230T. These are the
differences; (xxxxxxxxxx stands for random characters in the filename):
* `x230_coreboot_seabios_xxxxxxxxxx_top.rom` includes the _proprietary_
[VGA BIOS](https://en.wikipedia.org/wiki/Video_BIOS) from [Intel](https://www.intel.com/content/www/us/en/intelligent-systems/intel-embedded-graphics-drivers/faq-bios-firmware.html)
which is non-free software. It is executed in "secure" mode.
* `x230_coreboot_seabios_free_xxxxxxxxxx_top.rom` includes the
[VGA BIOS](https://en.wikipedia.org/wiki/Video_BIOS)
[SeaVGABIOS](https://www.seabios.org/SeaVGABIOS) which is free software.
While technically more interesting, visually this is currently not as
beautiful:
  * The [bootspash image is not shown](https://github.com/merge/skulls/issues/59).
  * Early boot console messages (after your HDD's bootloader has started a kernel) might be [missing](https://github.com/merge/skulls/issues/46).


## table of contents
* [TL;DR](#tldr)
* [First-time installation](#first-time-installation)
* [Updating](#updating)
* [Moving to Heads](#moving-to-heads)
* [Why does this work](#why-does-this-work)
* [How to rebuild](#how-to-reproduce-the-release-images)

## TL;DR
1. run `sudo ./x230_skulls.sh` on your current X230 Linux system
2. Power down, remove the battery. Remove the keyboard and palmrest. Connect
a hardware flasher to an external PC (or a Raspberry Pi with a SPI 8-pin chip clip
can directly be used), and run
`sudo ./external_install_bottom.sh` on the lower chip
and `sudo ./external_install_top.sh` on the top chip of the two.
3. For updating later, run `./x230_skulls.sh`. No need to disassemble.

And always use the latest [released](https://github.com/merge/coreboot-x230/releases)
package. This will be tested. The git master
branch is _not_ meant to be stable. Use it for testing only.

## First-time installation
#### before you begin
Before starting, run Linux on your X230, install `dmidecode` and run
`sudo ./x230_skulls.sh`. It simply prints system information and
helps you to be up to date.
Also make sure you have the latest skulls-x230 package release by running `./x230_skulls.sh -U`.

#### original BIOS update / EC firmware (optional)
Before flashing coreboot, consider doing one original Lenovo upgrade process
in case you're not running the latest version. This is not supported anymore,
once you're running coreboot (You'd have to manually flash back your backup
images first, see later chapters).

Also, this updates the BIOS _and_ Embedded Controller (EC) firmware. The EC
is not updated anymore, when running coreboot. The latest EC version is 1.14
and that's unlikely to change.

In case you're not running the latest BIOS version, either

* use [the latest original CD](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x230/downloads/ds029187) and burn it, or
* use the same, only with a patched EC firmware that allows using any aftermarket-battery:
By default, only original Lenovo batteries are allowed.
Thanks to [this](http://zmatt.net/unlocking-my-lenovo-laptop-part-3/)
[project](https://github.com/eigenmatt/mec-tools) we can use Lenovo's bootable
upgrade image, change it and create a bootable _USB_ image (even with EC updates
that allows one to use 3rd party aftermarket batteries). For this, follow instructions
at [github.com/hamishcoleman/thinkpad-ec](https://github.com/hamishcoleman/thinkpad-ec).

#### preparation: required hardware
* An 8 Pin SOIC Clip, for example from
[Pomona electronics](https://www.pomonaelectronics.com/products/test-clips/soic-clip-8-pin)
(for availability, check
[aliexpress](https://de.aliexpress.com/item/POMONA-SOIC-CLIP-5250-8pin-eeprom-for-tacho-8pin-cable-for-pomana-soic-8pin/32814247676.html) or
[elsewhere](https://geizhals.eu/?fs=pomona+test+clip+5250))
or alternatively hooks like
[E-Z-Hook](http://catalog.e-z-hook.com/viewitems/test-hooks/e-z-micro-hooks-single-hook-style)
* 6 [female](https://electronics.stackexchange.com/questions/37783/how-can-i-create-a-female-jumper-wire-connector)
[jumper wires](https://en.wikipedia.org/wiki/Jump_wire) like
[these](https://geizhals.eu/jumper-cable-female-female-20cm-a1471094.html)
to connect the clip to a hardware flasher (if not included with the clip)
* a hardware flasher
[supported by flashrom](https://www.flashrom.org/Flashrom/0.9.9/Supported_Hardware#USB_Devices), see below for the examples we support

#### open up the X230
Remove the 7 screws of your X230 to remove the keyboard (by pushing it towards the
screen before lifting) and the palmrest. You'll find the chips using the photo
below. This is how the SPI connection looks like on both of the X230's chips:


		Screen (furthest from you)
			     ______
		  MOSI  5 --|      |-- 4  GND
		   CLK  6 --|      |-- 3  N/C
		   N/C  7 --|      |-- 2  MISO
		   VCC  8 --|______|-- 1  CS

		   Edge (closest to you)


... choose __one of the following__ supported flashing hardware examples:

#### Hardware Example: Raspberry Pi 3
A Raspberry Pi can directly be a flasher through it's I/O pins, see below.
Use a test clip or hooks, see [required hardware](#preparation-required-hardware).

On the RPi we run [Raspbian](https://www.raspberrypi.org/downloads/raspbian/)
and have the following setup:
* Connect to the console: Either
  * connect a screen and a keyboard, or
  * Use the [Serial connection](https://elinux.org/RPi_Serial_Connection) using a
USB-to-serial cable (like [Adafruit 954](http://www.adafruit.com/products/954),
[FTDI TTL-232R-RPI](http://www.ftdichip.com/Products/Cables/RPi.htm) or
[others](https://geizhals.eu/usb-to-ttl-serial-adapter-cable-a1461312.html)) and
picocom (`picocom -b 115200 /dev/ttyUSB0`) or minicom
* in the SD Cards's `/boot/config.txt` file `enable_uart=1` and `dtparam=spi=on`
* [For flashrom](https://www.flashrom.org/RaspberryPi) we put `spi_bcm2835`
and `spidev` in /etc/modules
* [Connect to a wifi](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md)
or ethernet to `sudo apt-get install flashrom`
* connect the Clip to the Raspberry Pi 3 (there are
[prettier images](https://github.com/splitbrain/rpibplusleaf) too):


		   Edge of pi (furthest from you)
		               (UART)
		 L           GND TX  RX                           CS
		 E            |   |   |                           |
		 F +---------------------------------------------------------------------------------+
		 T |  x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x  |
		   |  x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x  |
		 E +----------------------------------^---^---^---^-------------------------------^--+
		 D                                    |   |   |   |                               |
		 G                                   3.3V MOSIMISO|                              GND
		 E                                 (VCC)         CLK
		   Body of Pi (closest to you)


![Raspberry Pi at work](rpi_clip.jpg)

Now copy the Skulls release tarball over to the Rasperry Pi and
[continue](#unpack-the-skulls-release-archive) on the Pi.

#### Hardware Example: CH341A based
The CH341A from [Winchiphead](http://www.wch.cn/), a USB interface chip,
is used by some cheap memory programmers.
The one we describe can be bought at
[aliexpress](http://www.aliexpress.com/item/Free-Shipping-CH341A-24-25-Series-EEPROM-Flash-BIOS-DVD-USB-Programmer-DVD-programmer-router-Nine/32583059603.html),
but it's available [elsewhere](https://geizhals.eu/?fs=ch341a) too.
Also, we don't use the included 3,3V power output (provides too little power),
but a separate power supply. If you don't have any, consider getting a AMS1117
based supply for a second USB port (like [this](https://de.aliexpress.com/item/1PCS-AMS1117-3-3V-Mini-USB-5V-3-3V-DC-Perfect-Power-Supply-Module/32785334595.html) or [this](https://www.ebay.com/sch/i.html?_nkw=ams1117+usb)).

* Leave the P/S Jumper connected (programmer mode, 1a86:5512 USB device)
* Connect 3,3V from your external supply to the Pomona clip's (or hook) VCC
* Connect GND from your external supply to GND on your CH341A programmer
* Connect your clip or hooks to the rest of the programmer's SPI pins
* Connect the programmer (and power supply, if USB) to your PC's USB port

![ch341a programmer with extra USB power supply](ch341a.jpg)

#### unpack the Skulls release archive


	tar -xf skulls-x230-<version>.tar.xz
	cd skulls-x230-<version>


#### ifd unlock and me_cleaner: the 8MB chip

Flashing the bottom chip (closer to you) is optional. It has the same pinout
than the upper chip. This allows you to enable/disable in-system flashing
(without disassembling the Thinkpad) and/or to neuter the
[Intel Management Engine](https://en.wikipedia.org/wiki/Intel_Management_Engine)
for [security reasons](https://en.wikipedia.org/wiki/Intel_Management_Engine#Security_vulnerabilities).


	sudo ./external_install_bottom.sh -m -k <backup-file-to-create>


That's it. Keep the backup safe. Here are the options (just so you know):

* The `-m` option applies `me_cleaner -S -d` before flashing back, see
[me_cleaner](https://github.com/corna/me_cleaner).
* The `-l` option will (re-)lock your flash ROM, in case you want to force
yourself (and others) to hardware-flashing, see [updating](#updating).

#### BIOS: the 4MB chip


	sudo ./external_install_top.sh -k <backup-file-to-create>


Select the image to flash and that's it.
Keep the backup safe, assemble and
turn on the X230. coreboot will do hardware init and start SeaBIOS.

## Updating
If you have locked your flash (i.e. `./external_install_bottom -l`) you can
flash externally using `external_install_top.sh` just like the
first time, see above. Only the "upper" 4MB chip has to be written.

It is recommended to do the the update directly on your X230 using Linux
though. This is considered more safe for your hardware and is very convenient -
just install the "flashrom" program and run  `./x230_skulls.sh`, see below.

1. boot Linux with the `iomem=relaxed` boot parameter (for example in /etc/default/grub `GRUB_CMDLINE_LINUX_DEFAULT`)
2. [download](https://github.com/merge/skulls/releases) the latest Skulls release tarball and unpack it or check for updates by running `./x230_skulls.sh -U`.
3. run `sudo ./x230_skulls.sh` and choose the image to flash.

Hint: In case your Linux distribution's GRUB bootloader doesn't use the full
screen, put the line `GRUB_GFXMODE=1366x768x32` in your `/etc/default/grub` file
(and run `update_grub`).

## Moving to Heads
[Heads](http://osresearch.net/) is an alternative BIOS system with advanced
security features. It's more complicated to use though. When having Skulls
installed, installing Heads is as easy as updating Skulls. You can directly
start using it:

* [build Heads](https://github.com/osresearch/heads)
* boot Linux with the `iomem=relaxed` boot parameter
* copy Heads' 12M image file `build/x230/coreboot.rom` to Skulls' x230 directory
* run `sudo ./x230_heads.sh`

That's it. Heads is a completely different project. Please read the
[documentation](http://osresearch.net/) for how to use it and report bugs
[over there](https://github.com/osresearch/heads/issues)

Switching back to Skulls is the same as [updating](#updating). Just run
`./x230_skulls.sh`.

## Why does this work?
On the X230, there are 2 physical "BIOS" chips. The "upper" 4MB
one holds the actual bios we can generate using coreboot, and the "lower" 8MB
one holds the rest that you can [modify yourself once](#first-time-installation),
if you like, but strictly speaking, you
[don't need to touch it at all](https://www.coreboot.org/Board:lenovo/x230#Building_Firmware).
What's this "rest"?
Mainly a tiny binary used by the Ethernet card and the Intel Management Engine.
Read the [coreboot documentation](https://doc.coreboot.org/mainboard/lenovo/xx30_series.html)
for more details.

## how to reproduce the release images
* `git clone https://github.com/merge/skulls`
* `cd skulls/x230`
* `git checkout 0.1.5` for the release you want to build. In this example 0.1.5.
* `./build.sh` and choose the configuration you want to build

### replace the splashscreen image
In order to create your own splashscreen image, before building,
overwrite the `splashscreen.jpg` with your own JPEG, using
* "Progressive" turned off, and
* "4:2:0 (chroma quartered)" Subsampling
