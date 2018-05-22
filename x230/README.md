# Skulls - [Thinkpad X230](https://pcsupport.lenovo.com/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x230).

![seabios_bootmenu](front.jpg)

## Latest release (config overview and version info)
* Get it from our [release page](https://github.com/merge/coreboot-x230/releases)
* The only proprietary binary, the VGA BIOS is executed in "secure" mode ([PCI_OPTION_ROM_RUN_YABEL](https://www.coreboot.org/Coreboot_Options))

### coreboot
* We simply take coreboot's current state in it's master branch at the time we build a release image.
That's the preferred way to use coreboot. The git revision we use is always included in the release.

### Intel microcode
* revision `1f` from 2018-02-07 see package [20180312](https://downloadcenter.intel.com/download/27591) under [Intel's license](LICENSE.microcode)

### SeaBIOS
* version [1.11.1](https://seabios.org/Releases) from 2018-03-19

## table of contents
* [TL;DR](#tldr)
* [First-time installation](#firsttime-installation)
* [Updating](#updating)
* [Moving to Heads](#moving-to-heads)
* [Why does this work](#why-does-this-work)

## TL;DR
1. run `sudo ./x230_before_first_install.sh` on your current X230 Linux system
2. Power down, remove the battery. Remove the keyboard and palmrest. Connect
a hardware flasher to an external PC (a Raspberry Pi with a SPI 8-pin chip clip
can directly be used), and run
`sudo ./external_install_bottom.sh` on the lower chip
and `sudo ./external_install_top.sh` on the top chip of the two.
3. For updating later, run `./x230_update.sh`. No need to disassemble.

And always use the latest [released](https://github.com/merge/coreboot-x230/releases)
package. This will be tested. The git master
branch is _not_ meant to be stable. Use it for testing only.

## First-time installation
#### before you begin
Before starting, run Linux on your X230, install `dmidecode` and run
`sudo ./x230_before_first_install.sh`. It simply prints system information and helps
you find out your RAM voltage. Make sure you have RAM that uses 1,5V, not 1,35V.

#### original BIOS update / EC firmware (optional)
Before flashing coreboot, consider doing one original Lenovo upgrade process
in case you're not running the latest version. This is not supported anymore,
once you're running coreboot (You'd have to manually flash back your backup
images first, see later chapters).

Also, this updates the BIOS _and_ Embedded Controller (EC) firmware. The EC
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

#### preparation: required hardware
* An 8 Pin SOIC Clip, for example from
[Pomona electronics](https://www.pomonaelectronics.com/products/test-clips/soic-clip-8-pin)
or alternatively hooks, for example from
[E-Z-Hook](http://catalog.e-z-hook.com/viewitems/test-hooks/e-z-micro-hooks-single-hook-style)
* 6 [female](https://electronics.stackexchange.com/questions/37783/how-can-i-create-a-female-jumper-wire-connector)
[jumper wires](https://en.wikipedia.org/wiki/Jump_wire) to connect the clip to
a hardware flasher
* a hardware flasher
[supported by flashrom](https://www.flashrom.org/Flashrom/0.9.9/Supported_Hardware#USB_Devices)
but we currently only support using a [Raspberry Pi](https://www.raspberrypi.org/products/)

#### open up the X230
Remove the 7 screws of your X230 to remove the keyboard (by pushing it towards the
screen before lifting) and the palmrest. You'll find the chips using the photo
below. This is how the SPI connection looks on both of the X230's chips:


		Screen (furthest from you)
			     __
		  MOSI  5 --|  |-- 4  GND
		   CLK  6 --|  |-- 3  N/C
		   N/C  7 --|  |-- 2  MISO
		   VCC  8 --|__|-- 1  CS

		   Edge (closest to you)


... choose one of the following supported flashing hardware examples:

#### Hardware Example: Raspberry Pi 3
A Raspberry Pi can directly be a flasher through it's I/O pins, see below.
Use a test clip or hooks, see [required hardware](#preparation-required-hardware).

On the RPi we run [Raspbian](https://www.raspberrypi.org/downloads/raspbian/)
and have the following setup:
* [Serial connection](https://elinux.org/RPi_Serial_Connection) using a
"USB to Serial" UART Adapter and picocom or minicom (yes, in this case you
need a second PC connected to the RPi over UART)
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

Now copy the Skulls release tarball over to the Rasperry Pi and continue on the Pi.

#### Hardware Example: CH341A based
CH341A, a USB interface chip, is used by some cheap memory programmers.

TODO

#### unpack the Skulls release archive


	mkdir skulls
	tar -xf skulls-x230-<version>.tar.xz -C skulls
	cd skulls


#### ifd unlock and me_cleaner: the 8MB chip
The [Intel Management Engine](https://en.wikipedia.org/wiki/Intel_Management_Engine)
resides on the 8MB chip (at the bottom, closer to you).
We don't need to touch it for coreboot-upgrades in the future, but to
enable internal flashing, we need to unlock it once, and remove the Management
Engine for
[security reasons](https://en.wikipedia.org/wiki/Intel_Management_Engine#Security_vulnerabilities):


	sudo ./external_install_bottom.sh -m -k <backup.bin>


That's it. Keep the backup safe.


Background (just so you know):

* The `-m` option above also runs `me_cleaner -S` before flashing back, see [me_cleaner](https://github.com/corna/me_cleaner).
* The `-l` option will (re-)lock your flash ROM, in case you want to force
yourself (and others) to hardware-flashing.
* Connecting an ethernet cable as a power-source for SPI (instead of the VCC pin)
is not necessary (some other flashing how-to guides mention this).
Setting a fixed (and low) SPI speed for flashrom offeres the same stability.
Our scripts do this for you.

#### BIOS: the 4MB chip


	sudo ./external_install_top.sh -i <release-image-file>.rom -k <backup>


That's it. Keep the backup safe, assemble and turn on the X230. coreboot will
do hardware init and start SeaBIOS.

## Updating
Only the "upper" 4MB chip has to be written.
You can again flash externally, using `external_install_top.sh` just like the
first time, see above.

Instead you can run the update directly on your X230
using Linux. That's of course very convenient - just install flashrom from your
Linux distribution - but according to the
[flashrom manpage](https://manpages.debian.org/stretch/flashrom/flashrom.8.en.html)
this is very dangerous:

1. Boot Linux with the `iomem=relaxed` boot parameter (for example in /etc/default/grub `GRUB_CMDLINE_LINUX_DEFAULT`)
2. [download](https://github.com/merge/skulls/releases) the latest Skulls release tarball and unpack it
3. run `sudo ./x230_update.sh` for generating all necessary files and instructions

## Moving to Heads
[Heads](http://osresearch.net/) is an alternative BIOS system with advanced
security features. When having Skulls installed, installing Heads should be
as easy as updating Skulls.

TODO


## Why does this work?
On the X230, there are 2 physical "BIOS" chips. The "upper" 4MB
one holds the actual bios we can generate using coreboot, and the "lower" 8MB
one holds the rest that you can [modify yourself once](#flashing-for-the-first-time),
if you like, but strictly speaking, you
[don't need to touch it at all](https://www.coreboot.org/Board:lenovo/x230#Building_Firmware).
What's this "rest"?
Mainly a tiny binary used by the Ethernet card and the Intel Management Engine.
