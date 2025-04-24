+++
title="Installing Alpine Linux on a Hetzner ARM server"
date=2023-07-24
+++
Recently, I've gotten myself one of those ARM VPSes from [Hetzner](https://www.hetzner.com/cloud), excited about the _very_ good price-to-performance ratio. I fired the server up, and immediately went on to replace the default Ubuntu install with [Alpine](https://alpinelinux.org), as it has long ago become the only server distro I use.

I was disappointed to see that Alpine Linux is not on the list of available ISOs, though. That kinda shocked me, as I was accustomed to the ***insane*** amount of ISO choice Hetzner normally provides with their x86 servers.

## I will not tolerate this.

### Rescue mode

Go to the Hetzner Cloud control panel, and reboot the server into rescue mode (`Rescue > "Enable rescue & power cycle"`). Pick linux64 for the Rescue OS.

Log in to the machine with SSH. In case you have not picked an SSH key, use the root password displayed on the Rescue tab.

### Flashing the ISO

Now we need to flash the Alpine Linux ISO onto the virtual hard disk. Go to the [alpinelinux.org download page](https://alpinelinux.org/downloads) and grab the link for the lastest **aarch64 virtual** release. Download and flash the ISO on the server:

```bash
curl -LO https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/alpine-virt-3.18.2-aarch64.iso
dd if=alpine-virt-3.18.2-aarch64.iso of=/dev/sda
poweroff
```

### Installation

After the server shuts down, turn it back on again using the Hetzner cloud control panel and enter the console (the terminal icon on the top right). Once the server boots, log in as `root`, there's no password.

Before we can proceed with the installation, we need to make a few preparations:

```bash
# copy data from the mounted media to /root
cp -r /.modloop /root
cp -r /media/sda /root

# unmount the media
umount /.modloop /media/sda

# move the data to directories that were the mountpoints
rm /lib/modules
mv /root/.modloop/modules /lib
mv /root/sda /media
```

Now you can install Alpine Linux using `setup-alpine` as you'd do normally and then reboot.
