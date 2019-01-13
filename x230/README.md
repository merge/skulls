# Skulls - [Thinkpad X230](https://pcsupport.lenovo.com/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x230) and X230T

![seabios_bootmenu](front.jpg)

## Warning up-front
This may brick/destroy/detonate your Thinkpad. Proceed at your own discretion.

## Latest release
Get it from our [release page](https://github.com/merge/coreboot-x230/releases)
* __coreboot__: We take coreboot's master branch at the time we build a release image.
* __microcode update__: revision `20` from 2018-04-10 (includes mitigations for Spectre Variant 3a and 4)
* __SeaBIOS__: version [1.12.0](https://seabios.org/Releases) from 2018-11-17

## Table of contents
* [TL;DR](#tldr)
* [First-time installation](#first-time-installation)
* [Updating](#updating)
* [Moving to Heads](#moving-to-heads)
* [Why does this work](#why-does-this-work)
* [How to rebuild](#how-to-reproduce-the-release-images)

## TL;DR
1. If your Thinkpad is already running linux: run `sudo ./x230_before_first_install.sh` on it
2. Power down, remove the battery. Remove the keyboard and palmrest.
3. Connect a hardware flasher to an external PC (or a Raspberry Pi with a SPI 8-pin chip clip
can directly be used)
4. Run `sudo ./external_install_bottom.sh` on the lower chip
5. Run `sudo ./external_install_top.sh` on the top chip of the two
6. Optionally: For updating later, run `./x230_skulls.sh`. No need to disassemble.

And always use the latest [released](https://github.com/merge/coreboot-x230/releases)
package. This will be tested. The git master branch is _not_ meant to be stable. Use it for testing only.

## First-time installation

### If you are still on Windows and Lenovo BIOS

Before flashing coreboot, consider doing one original Lenovo upgrade process
in case you're not running the latest version. This is not supported anymore,
once you're running coreboot (You'd have to manually flash back your backup
images first, see later chapters).

Check the [Lenovo Support site (which is quite good and actually helpful)](https://pcsupport.lenovo.com/de/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x230) and e.g. run the _Lenovo System Update for Windows_ to check for old BIOS, EC- or battery-firmware or other updateable firmwar.

Also, this updates the BIOS (latest 2.74) _and_ Embedded Controller (EC) firmware. The EC
is not updated anymore, when running coreboot. The latest EC version is 1.14
and that's unlikely to change.

In case you're not running the latest BIOS version, either

* use [the latest original CD](https://support.lenovo.com/at/en/downloads/ds029188) and burn it, or
* use the same, only with a patched EC firmware that allows using any aftermarket-battery:
By default, only original Lenovo batteries are allowed.
Thanks to [this](http://zmatt.net/unlocking-my-lenovo-laptop-part-3/)
[project](https://github.com/eigenmatt/mec-tools) we can use Lenovo's bootable
upgrade image, change it and create a bootable _USB_ image, with an EC update
that allows us to use any 3rd party aftermarket battery:


		sudo apt-get install build-essential git mtools libssl-dev
		git clone https://github.com/hamishcoleman/thinkpad-ec && cd thinkpad-ec
		make patch_disable_keyboard clean
		make patch_enable_battery clean
		make patched.x230.img


That's it. You can create a bootable USB stick: `sudo dd if=patched.x230.img of=/dev/sdx`
and boot from it. Alternatively, burn `patched.x230.iso` to a CD. And make sure
you have "legacy" boot set, not "UEFI" boot.

### Optionally: If your Thinkpad already is on Linux
Before starting, run Linux on your X230, install `dmidecode` and run
`sudo ./x230_before_first_install.sh`. It simply prints system information and
helps you to be up to date.
Also make sure you have the latest skulls-x230 package release by running `./upgrade.sh`.

### Preparation: required hardware
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

There are plenty of cheap chinese SOIC-clips, their build-quality is reported to be problematic. Consider getting one of the above mentioned brand clips.

### Open up the X230
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
		   N/C = not connected

... choose __one of the following__ supported flashing hardware examples:

### Option 1: Raspberry Pi 3
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
		 L           GND                                  CS
		 E            |                                   |
		 F +---------------------------------------------------------------------------------+
		 T |  x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x  |
		   |  x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x  |
		 E +----------------------------------^---^---^---^-------------------------------^--+
		 D                                    |   |   |   |                              
		 G                                   3.3V MOSIMISO|                              
		 E                                 (VCC)         CLK
		   Body of Pi (closest to you)

![Raspberry Pi at work](rpi_clip.jpg)

Now copy the Skulls release tarball over to the Rasperry Pi and
[continue](#unpack-the-skulls-release-archive) on the Pi.

### Option 2: CH341A based
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

### Side note
Connecting an ethernet cable as a power-source for SPI (instead of the VCC pin)
is not necessary (some other flashing how-to guides mention this).
Setting a fixed (and low) SPI speed for flashrom offeres the same stability.
Our scripts do this for you.

We checked around on excactly when and how one should connect the clip. There has been no clear advice, it seems to be safest to first connect all cables between the flashing device and the clip, and once correctly configured, connect the clip to the chip.

## Get and unpack the Skulls release archive
After choosing one flasher-option [download](https://github.com/merge/skulls/releases) the latest release and untar it:

	tar -xf skulls-x230-<version>.tar.xz
	cd skulls-x230-<version>

Make sure to verify the checksum with e.g.:

	sha256sum skulls-x230-0.1.0.tar.xz anc compare this to the [checksum](https://github.com/merge/skulls/releases/download/0.1.0/skulls-x230-0.1.0.tar.xz.sha256)

### Side note
Flashing with these low speeds takes time. Be patient. E.g. unlocking the bottom chip with its two reads, one write and one verify step usually takes approximately one hour in total. Again, be patient!

If you need to configure the -c option when flashing top- or bottom-chip it may well be that different chips are used. So, it may be neccessary to e.g. configure _external_install_bottom_ with the _-c EN25QH64_ option, but when flashing the top-chip it only works without _-c_ or with a different chip.

## First, optional step: Connect to the bottom chip
There are a few reasons why you may start with connecting your clip to the bottom (at the bottom, closer to you) chip (it has the same pinout than the upper chip):
- You may want to enable in system updates in the future. The advantage is that you can update and change whatever you decide to flash in the upper chip. The disadvantage is that any software can flash you BIOS with this setting. Choose wisely (Heads - see below - may be of use here).
- You may want to neuter the [Intel Management Engine](https://en.wikipedia.org/wiki/Intel_Management_Engine) for
[security reasons](https://en.wikipedia.org/wiki/Intel_Management_Engine#Security_vulnerabilities)
- You simply may want to backup the firmware in this chip.

If you don't want any of this skip to the upper chip. Else choose the correct command line options here

	sudo ./external_install_bottom.sh -m -k <backup-file-to-create>

* The `-m` option above also runs `me_cleaner -S` before flashing back, see [me_cleaner](https://github.com/corna/me_cleaner).
* The `-l` option will (re-)lock your flash ROM, in case you want to force
yourself (and others) to hardware-flashing. Unlocking is standard if you don't specify this.
* The `-k` creates a backup-file if two reads succeeded and produced the same checksum.

#### Second, the main step: "Butter bei die Fische"
The upper- or top-chip (the one nearer to the display) houses the BIOS to be replaced. If you are finished with the bottom-chip (or you decided no to touch it) connect the clip in the same configuration to the top-chip. Then run:

	sudo ./external_install_top.sh -k <backup-file-to-create>

Select the image to flash and that's it. The image named "free" includes
[SeaVGABIOS](https://www.seabios.org/SeaVGABIOS) instead of
[Intel's VGA Bios](https://www.intel.com/content/www/us/en/intelligent-systems/intel-embedded-graphics-drivers/faq-bios-firmware.html).

Keep the backup safe, assemble and turn on the X230. coreboot will do hardware init and start SeaBIOS.
You are done, everything below is optional. _Enjoy your liberated Thinkpad!_

## Updating
Two possibilities:

_If you unlocked the bottom chip (see above) then you can flash in place:_

That's of course very convenient - just install flashrom from your
Linux distribution - but according to the
[flashrom manpage](https://manpages.debian.org/stretch/flashrom/flashrom.8.en.html)
this is very dangerous:

1. boot Linux with the `iomem=relaxed` boot parameter (for example in /etc/default/grub `GRUB_CMDLINE_LINUX_DEFAULT`)
2. [download](https://github.com/merge/skulls/releases) the latest Skulls release tarball and unpack it
3. run `sudo ./x230_skulls.sh` and choose the image to flash.

_If you decided against flashing in place, just repeat the steps for the top-chip:_

You can again flash externally, using `external_install_top.sh` just like the
first time, see above.

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
one holds the rest that you can [modify yourself once](#flashing-for-the-first-time),
if you like, but strictly speaking, you
[don't need to touch it at all](https://www.coreboot.org/Board:lenovo/x230#Building_Firmware).
What's this "rest"?
Mainly a tiny binary used by the Ethernet card and the Intel Management Engine.

## How to reproduce the release images
* `git clone https://github.com/merge/skulls`
* rename one of the included config files to `config-xxxxxxxxxx`.
* The x230 directory's `./build.sh` should produce the exact corresponding release image file.

## Further reading / more pictures
* [Flashing the X230 with coreboot while slaying Intel-ME](https://steemit.com/tutorial/@joeyd/run-don-t-walk-from-the-blob)
* [Step by Step easy guide to flashing Coreboot (X230, but should work for others too)](https://www.reddit.com/r/thinkpad/comments/4zrmf8/step_by_step_easy_guide_to_flashing_coreboot_x230/)
