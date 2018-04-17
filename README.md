# coreboot-x230
pre-built [coreboot](https://www.coreboot.org/) images and documentation on
how to flash them for the
[Thinkpad X230](https://pcsupport.lenovo.com/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x230).
SeaBIOS is used as coreboot payload to be compatible with Windows and Linux
systems.

## Latest build (config overview and version info)
See our [releases](https://github.com/merge/coreboot-x230/releases)

* Lenovo's proprietary VGA BIOS ROM is executed in "secure" mode

### coreboot
* We simply take coreboot's current state in it's master branch at the time we build a release image.
That's the preferred way to use coreboot. The git revision we use is always included in the release.

### Intel microcode
* revision `1f` from 2018-02-07 (Intel package [20180312](https://downloadcenter.intel.com/download/27591) not yet in coreboot upstream) under [Intel's license](LICENSE.microcode)

### SeaBIOS
* version [1.11.0](https://seabios.org/Releases#SeaBIOS_1.11.0) from 2017-11-10 (part of coreboot upstream)

## table of contents
* [TL;DR](#tl-dr)
* [Flashing for the first time](#flashing-for-the-first-time)
* [How to update](#how-to-update)
* [When do we do a release?](#when-do-we-do-a-release)
* [How we build](#how-we-build)
* [Why does this work](#why-does-this-work)
* [Alternatives](#alternatives)

## TL;DR
Download a released image, connect your hardware SPI flasher to the "upper"
4MB chip in your X230, and do

     flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E" -w x230_coreboot_seabios_example_top.rom

where `linux_spi:` is the example of using your SPI pins of, for example, a
Raspberry Pi. A [Bus Pirate](http://dangerousprototypes.com/docs/Bus_Pirate) with
`buspirate_spi` or others connected to the host directly should be fine too.

## Flashing for the first time
Especially for the first time, you must flash externally. See below for the details
for using a Rapberry Pi, for example.

### flashrom chip config
We use [flashrom](https://flashrom.org/) for flashing. Run `flashrom -p <your_hardware>`
(for [example](#how-to-flash) `flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128` for the
Raspberry Pi) to let flashrom detect the chip. It will probably list a few you need to choose
from when flashing (by adding `-c "<chipname>"`). While there might be specific examples
in the commands below, please review the chip model for your device. In case you are
unsure what to specify, here's some examples we find out there:

#### 4MB chip
* `MX25L3206E` seems to mostly be in use

#### 8MB chip
* `MX25L3206E/MX25L3208E` is seen working with various X230 models.
* `MX25L6406E/MX25L6408E` is used in [this guide](https://github.com/mfc/flashing-docs/blob/master/walkthrough%20for%20flashing%20heads%20on%20an%20x230.md#neutering-me)
* `EN25QH64` is used sometimes


### EC firmware (optional)
Enter Lenovo's BIOS with __F1__ and check the embedded controller (EC) version to be
__1.14__ and upgrade using [the latest bootable CD](https://support.lenovo.com/at/en/downloads/ds029188)
if it isn't. The EC cannot be upgraded when coreboot is installed. (In case a newer
version should ever be available (I doubt it), you could temporarily flash back your
original Lenovo BIOS image)

### ifd unlock (necessary for internal flashing) and me_cleaner (optional)
The Intel Management Engine resides on the 8MB chip. We don't need to touch it
for coreboot-upgrades in the future, but while opening up the Thinkpad anyways,
we can save it and run [ifdtool](https://github.com/coreboot/coreboot/tree/master/util/ifdtool)
and [me_cleaner](https://github.com/corna/me_cleaner) on it:


      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L6406E/MX25L6408E" -r ifdmegbe.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L6406E/MX25L6408E" -r ifdmegbe2.rom
      diff ifdmegbe.rom ifdmegbe2.rom
      git clone https://github.com/corna/me_cleaner.git && cd me_cleaner
      ./me_cleaner.py -S -O ifdmegbe_meclean.rom ifdmegbe.rom
      ifdtool -u ifdmegbe_meclean.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L6406E/MX25L6408E" -w ifdmegbe_meclean.rom.new

### save the 4MB chip
(internally, memory of the two chips is mapped together, the 8MB being the lower
part, but we can essientially ignore that)

For the first time, we have to save the original image, just like we did with
the 8MB chip. It's important to keep this image somewhere safe:


      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E" -r top1.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E" -r top2.rom
      diff top1.rom top2.rom


## How to update
When __upgrading__ to a new release, only the "upper" 4MB chip has to be written.
Download the latest release image we provide and flash it:

### Example: Raspberry Pi 3

Here you'll flash externally, using a "Pomona 5250 8-pin SOIC test clip". You'll find
one easily. This is how the X230's SPI connection looks on both chips:


		Screen (furthest from you)
			     __
		  MOSI  5 --|  |-- 4  GND
		   CLK  6 --|  |-- 3  N/C
		   N/C  7 --|  |-- 2  MISO
		   VCC  8 --|__|-- 1  CS

		   Edge (closest to you)


and the flashrom command you need, looks like so:


     flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E" -w x230_coreboot_seabios_example_top.rom


We run [Raspbian](https://www.raspberrypi.org/downloads/raspbian/)
and have the following setup
* [Serial connection](https://elinux.org/RPi_Serial_Connection) using a "USB to Serial" UART Adapter and picocom or minicom
* Yes, in this case you need a second PC connected to the RPi over UART
* in the SD Cards's `/boot/config.txt` file `enable_uart=1` and `dtparam=spi=on`
* [For flashrom](https://www.flashrom.org/RaspberryPi) we put `spi_bcm2835` and `spidev` in /etc/modules
* [Connect to a wifi](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md) or to network over ethernet to install `flashrom`
* only use the ...top.rom release file
* connect the Clip to the Raspberry Pi 3 (there are [prettier images](https://github.com/splitbrain/rpibplusleaf) too:


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


Now you should be able to copy the image over to your Rasperry Pi and run the
mentioned `flashrom` commands. One way to copy, is convertig it to ascii using
`uuencode` (part of Debian's sharutils package) described below. This is a very
direct, shady and slow way to copy file. Another way is of course using a USB
Stick or scp :) (but you need even more hardware or a network).


		(convert)
	host$ uuencode coreboot.rom coreboot.rom.ascii > coreboot.rom.ascii
		(transfer)
	rpi$ cat > coreboot.rom.ascii
	host$ pv coreboot.rom.ascii > /dev/ttyUSBX
		(wait)
	rpi$ (CTRL-D)
		(convert back)
	rpi$ uudecode -o coreboot.rom coreboot.rom.ascii
		(verify)
	host$ sha1sum coreboot.rom
	rpi$ sha1sum coreboot.rom

![Raspberry Pi at work](rpi_clip.jpg)

### Example: internal
CAUTION: THIS IS NOT ENCOURAGED

* You have to have your 8MB chip flashed externally after `ifdtool -u ifdmegbe.rom` before this, once
* very convenient, but according to the [flashrom manpage](https://manpages.debian.org/stretch/flashrom/flashrom.8.en.html) this is very dangerous!
* Boot Linux with the `iomem=relaxed` boot parameter (for example set in /etc/default/grub)
* download a released 4MB "top" rom image
* run `prepare_internal_flashing.sh` for generating all necessary files and instructions

## When do we do a release?
Either when
* There is a new SeaBIOS release,
* There is a new Intel microcode release (for our CPU model),
* There is a coreboot issue that affects us, or
* We change the config

## How we build
* Everything necessary to build coreboot (while only the top 4MB are usable of course) is included here
* The task of [building coreboot](https://www.coreboot.org/Build_HOWTO) is not too difficult
* When doing a release here, we always try to upload to coreboot's [board status project](https://www.coreboot.org/Supported_Motherboards)
* If we add out-of-tree patches, we always [post them for review](http://review.coreboot.org/) upstream

## Why does this work?
On the X230, there are 2 physical "BIOS" chips. The "upper" 4MB
one holds the actual bios we can generate using coreboot, and the "lower" 8MB
one holds the rest that you can [modify yourself once](#flashing-for-the-first-time),
if you like, but strictly speaking, you
[don't need to touch it at all](https://www.coreboot.org/Board:lenovo/x230#Building_Firmware).
What's this "rest"?
Mainly a tiny binary used by the Ethernet card and the Intel Management Engine.

## Alternatives
* [Heads](https://github.com/osresearch/heads/releases) also releases pre-built
flash images for the X230 - with __way__ more sophisticated functionality.
