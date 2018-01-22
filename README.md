# coreboot-x230
pre-built coreboot images and documentation on how to flash them for the Thinkpad X230

These images
* include [SeaBIOS](https://seabios.org/SeaBIOS) as coreboot payload, for maximum compatibility.
* are meant to be [flashed externally](#how-to-flash)
* are compatible with Windows and Linux

## Latest build (config overview and version info)
See our [releases](https://github.com/merge/coreboot-x230/releases)

* Lenovo's proprietary VGA BIOS ROM is executed in "secure" mode

### coreboot
* We simply take coreboot's current state in it's master branch at the time we build a release image.
That's the preferred way to use coreboot. The git revision we use is always included in the release.

### Intel microcode
* version [20180108](https://downloadcenter.intel.com/download/27431/Linux-Processor-Microcode-Data-File)
* in 20180108, for the X230's CPU ID (306ax) the latest update is 2015-02-26
* (not yet in coreboot upstream)

### SeaBIOS
* version [1.11.0](https://seabios.org/Releases#SeaBIOS_1.11.0) from 2017-11-10
* (in coreboot upstream)

## When do we do a release?
Either when
* There is a new SeaBIOS release,
* There is a new Intel microcode release (included in coreboot AND affecting our CPU ID),
* There is a coreboot issue that affects us (unlikely), or
* We need to change the config

## TL;DR
Download a released image, connect your hardware SPI flasher to the "upper"
4MB chip in your X230, and do

     flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -w x230_coreboot_seabios_example_top.rom


## Flashing for the first time

### EC firmware (optional)
Enter Lenovo's BIOS with __F1__ and check the embedded controller (EC) version to be
__1.14__ and upgrade using [the latest bootable CD](https://support.lenovo.com/at/en/downloads/ds029188)
if it isn't. The EC cannot be upgraded when coreboot is installed. (In case a newer
version should ever be available (I doubt it), you could temporarily flash back your
original Lenovo BIOS image)

### me_cleaner (optional)
The Intel Management Engine resides on the 8MB chip. We don't need to touch it
for coreboot-upgrades in the future, but while opening up the Thinkpad anyways,
we can save it and run [ifdtool](https://github.com/coreboot/coreboot/tree/master/util/ifdtool)
and [me_cleaner](https://github.com/corna/me_cleaner) on it:


      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E/MX25L3208E" -r ifdmegbe.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E/MX25L3208E" -r ifdmegbe2.rom
      diff ifdmegbe.rom ifdmegbe2.rom
      git clone https://github.com/corna/me_cleaner.git && cd me_cleaner
      ./me_cleaner.py -S -O ifdmegbe_meclean.rom ifdmegbe.rom
      ifdtool -u ifdmegbe_meclean.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E/MX25L3208E" -w ifdmegbe_meclean.rom.new

### save the 4MB chip
(internally, memory of the two chips is mapped together, the 8MB being the lower
part, but we can essientially ignore that)

For the first time, we have to save the original image, just like we did with
the 8MB chip. It's important to keep this image somewhere safe:


      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -r top1.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -r top2.rom
      diff top1.rom top2.rom

## Flashing the coreboot / SeaBIOS image
When __upgrading__ to a new version, for example when a new [SeaBIOS](https://seabios.org/Releases)
version is available, only the "upper" 4MB chip has to be written.

Download the latest release image we provide here and flash it:


     flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -w x230_coreboot_seabios_example_top.rom

## How to flash
We flash externally, using a "Pomona 5250 8-pin SOIC test clip". You'll find
one easily. This is how the X230's SPI connection looks on both chips:


		Screen (furthest from you)
			     __
		  MOSI  5 --|  |-- 4  GND
		   CLK  6 --|  |-- 3  N/C
		   N/C  7 --|  |-- 2  MISO
		   VCC  8 --|__|-- 1  CS

		   Edge (closest to you)


### Example: Raspberry Pi 3
We run [Raspbian](https://www.raspberrypi.org/downloads/raspbian/)
and have the following setup
* [Serial connection](https://elinux.org/RPi_Serial_Connection) using a "USB to Serial" Adapter and picocom or minicom
* in the SD Cards's `/boot/config.txt` file `enable_uart=1` and `dtparam=spi=on`
* [For flashrom](https://www.flashrom.org/RaspberryPi) we put `spi_bcm2835` and `spidev` in /etc/modules
* [Connect to a wifi](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md) or to network over ethernet.
* install `flashrom`
* connect the Clip to the Raspberry Pi 3:


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
`uuencode`:


	host$ uuencode coreboot.rom coreboot.rom.ascii > coreboot.rom.ascii
	rpi$ cat > coreboot.rom.ascii
		(close picocom / minicom on host)
	host$ cat coreboot.rom.ascii > /dev/ttyUSBX
	host$ sha1sum coreboot.rom
		(open picocom / minicom again)
	rpi$ uudecode -o coreboot.rom coreboot.rom.ascii
	rpi$ sha1sum coreboot.rom


## How we build
Everything necessary to build coreboot is included in this project and building
coreboot is not hard at all. Please refer to [coreboot's own documentation](https://www.coreboot.org/Build_HOWTO).

When building, testing and doing a release here, we always try to upload our
result to coreboot's [board status project](https://www.coreboot.org/Supported_Motherboards).

## Why does this work?
On the X230, there are 2 physical "BIOS" chips. The "upper" 4MB
one holds the actual bios we can generate using coreboot, and the "lower" 8MB
one holds the rest that you can [modify yourself once](#flashing-for-the-first-time),
if you like, but strictly speaking, you don't need to touch it at all. What's this "rest"?
Mainly a tiny binary used by the Ethernet card and the Intel Management Engine.
