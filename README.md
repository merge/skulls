# skulls - coreboot your device the easy way
pre-built [coreboot](https://www.coreboot.org/) image and documentation on
how to flash them.

* currently only for the [Thinkpad X230](x230/README.md).

SeaBIOS is used, to be compatible with Windows and Linux, and to be easy to use:
simply a boot menu and a few options to tick.

![seabios_bootmenu](x230/front.jpg)

We want to make it easy to "bootstrap" your laptop to a _working_, _unlocked_,
_up-to-date_ coreboot-based BIOS.

## When do we do a release?
Either when
* There is a new SeaBIOS release,
* There is a new Intel microcode release (for our CPU model),
* There is a coreboot issue that affects us, or
* We change the config

## How we build
* Everything necessary to [build coreboot](https://www.coreboot.org/Build_HOWTO) is included here
* When doing a release, we always try to upload to coreboot's [board status project](https://www.coreboot.org/Supported_Motherboards)
* If we add out-of-tree patches, we always [post them for review](http://review.coreboot.org/) upstream

## Alternatives
We aim to be the easiest possible coreboot distribution - both
to install and to use. And since our images are unlocked to enable easy
software updates, it's easy to try alternative systems too:

* [Heads](https://github.com/osresearch/heads/releases) - coreboot distribution
with pre-built (or reproducibly buildable) flash images (for the X230 and others). Heads
includes Linux, with tools to create a trusted boot chain using your GPG key
and the TPM.
* [libreboot](https://libreboot.org/) - also a coreboot distribution with pre-built
image releases. The X230 is currently not supported (the X200 is) - libreboot
images are built from free software only and include the GRUB bootloader.
