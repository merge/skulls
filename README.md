# coreboot-x230
pre-built coreboot images and documentation on how to flash them for the Thinkpad X230

These imges:
* include Lenovo's proprietary VGA BIOS ROM. If it might not be needed anymore, I'm happy for hints.
* include [SeaBIOS](https://seabios.org/SeaBIOS) as coreboot payload, for maximum compatibility.
* are meant to be [flashed externally](#how-to-flash)

## Latest build
See our [releases](https://github.com/merge/coreboot-x230/releases)

## Currrent microcode file
* Source: [2018-01-08](https://downloadmirror.intel.com/27431/eng/microcode-20180108.tgz) md5 871df55f0ab010ee384dabfc424f2c12
* 06-3a-09 for Intel(R) Core(TM) i5-3320M CPU @ 2.60GHz

## Flashing for the first time

### EC firmware
Enter Lenovo's BIOS with __F1__ and check the embedded controller (EC) version to be
__1.14__ and upgrade using [the latest bootable CD](https://support.lenovo.com/at/en/downloads/ds029188)
if it isn't. The EC cannot be upgraded when coreboot is installed. (In case a newer
version should ever be available (I doubt it), you could temporarily flash back your
original Lenovo BIOS image)

### me_cleaner
The Intel Management Engine resides on the 8MB chip. We don't need to touch it
for coreboot-upgrades in the future, but while opening up the Thinkpad anyways,
we can save it and run [ifdtool](https://github.com/coreboot/coreboot/tree/master/util/ifdtool)
and [me_cleaner](https://github.com/corna/me_cleaner) on it:


      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E/MX25L3208E" -r ifdmegbe.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E/MX25L3208E" -r ifdmegbe2.rom
      diff ifdmegbe.rom ifdmegbe2.rom
      git clone https://github.com/corna/me_cleaner.git && cd me_cleaner
      ./me_cleaner.py -O ifdmegbe_meclean.rom ifdmegbe.rom
      ifdtool -u ifdmegbe_meclean.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -c "MX25L3206E/MX25L3208E" -w ifdmegbe_meclean.rom.new

### save the 4MB chip
(internally, memory of the two chips is mapped together, the 8MB being the lower
part, but we can essientially ignore that)

For the first time, we have to save the original image, just like we did with
the 8MB chip above:


      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -r top1.rom
      flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -r top2.rom
      diff top1.rom top2.rom

## Flashing the coreboot / SeaBIOS image
When __upgrading__ to a new version, for example when a new [SeaBIOS](https://seabios.org/Releases)
version is available, only this has to be done.

Download the latest release image we provide here and flash it:


     flashrom -p linux_spi:dev=/dev/spidev0.0,spispeed=128 -w x230_coreboot_seabios_example_top.rom

## How to flash
We flash externally, using a "Pomona 5250 8-pin SOIC test clip". You'll find
one easily.

We connect it to a Raspberry Pi 3, running [Raspbian](https://www.raspberrypi.org/downloads/raspbian/)
and the following setup
* in the SD Cards's `/boot/config.txt` file `enable_uart=1` and `dtparam=spi=on`
* [For flashrom](https://www.flashrom.org/RaspberryPi) we put `spi_bcm2835` and `spidev` in /etc/modules
* [Connect to a wifi](https://www.raspberrypi.org/documentation/configuration/wireless/wireless-cli.md)
* install `flashrom`
* connect the Clip to the Raspberry Pi 3:

		   Edge of pi (furthest from you)
		 L                                                CS
		 E                                                |
		 F +---------------------------------------------------------------------------------+
		 T |  x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x  |
		   |  x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x   x  |
		 E +----------------------------------^---^---^---^-------------------------------^--+
		 D                                    |   |   |   |                               |
		 G                                   3.3V MOSIMISO|                              GND
		 E                                 (VCC)         CLK
		   Body of Pi (closest to you)

and you X230:


		Screen (furthest from you)
			     __
		  MOSI  5 --|  |-- 4  GND
		   CLK  6 --|  |-- 3  N/C
		   N/C  7 --|  |-- 2  MISO
		   VCC  8 --|__|-- 1  CS

		   Edge (closest to you)


Now you should be able to run the above mentioned `flashrom` commands.

## How we build
Everything necessary to build coreboot is included in this project and building
coreboot is not hard at all. Please refer to [coreboot's own documentation](https://www.coreboot.org/Build_HOWTO).

When building, testing and doing a release here, we always try to upload our
result to coreboot's [board status project](https://www.coreboot.org/Supported_Motherboards).

