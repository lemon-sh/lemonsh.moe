+++
title="The day I became the Mumble server"
date=2023-04-22
+++

# The Powerbank

I know this might sound completely unrelated to the post title, but bear with me...

I was looking for a powerbank recently, because I got tired of constantly keeping track of my phone's battery charge level every time I leave the house.
Initially, I wanted to get one of those [18650 Li-Ion cell cases](https://allegro.pl/oferta/obudowa-powerbank-na-8-ogniw-18650-usb-c-skrecana-13064464029), but the [GC PowerPlay20](https://www.x-kom.pl/p/575269-powerbank-green-cell-powerplay20-20000mah-usb-c-pd-18w-qc-30.html) caught my attention.
It's reasonably priced for the capacity it offers, and supports **fast charging**, so I decided to get it.

After ordering the device and reading a bit through the specs in more detail, I thought to myself...

## ...what is fast charging anyway?

I've never really dug into how the fast charging technology works before buying the powerbank, but once I had the device in my hands, I got curious and did some research.

I quickly learned that there are thousands of fast charging solutions (most of which are proprietary), but one particular solution stands out - USB-C Power Delivery. It's an **open standard** for fast charging. I will refer to it as PD in the rest of the post.

I figured, there *must* be a board of some sort that would deal with the PD protocol for me and give me the raw 12V output. Turns out, that's correct! Moreover, I could easily [get such a board locally](https://kamami.pl/wyzwalacze-usb-pd/584721-wyzwalacz-pd-usb-typu-c-12v-5a-bez-zlacza.html). The same store also sells [cables with it](https://kamami.pl/przewody-zasilajace/1181212-przewod-zasilajacy-z-wyzwalaczem-pd-12v-usb-typu-c-dc-55x25mm-12m.html), so I've immediately ordered one.

# The crazy idea

I've always been fascinated with the idea of a mobile Linux server that I could take anywhere and let other people use.

One good option for building one is obviously the Raspberry Pi, but due to the low specs of its internal WiFi, I didn't even bother trying to set it up. But what if I used an actual WiFi router?

Unfortunately, my WiFi router turned out not to be powerful enough to set up services on it, so instead, I used a classic RPi Zero (without wifi) plugged in to the actual router.

***Note:** I know that I could possibly get even better results with a good quality USB WiFi card and an external antenna, but carrying an actual home router and powering it from a powerbank is just cooler :3*

## Choosing a distro

I've initially wanted to go with the official Raspberry Pi OS, but the flashbacks from spending hours debloating the thing, made me conclude that flashing such a bloated operating system on such a breathtakingly underpowered device is a crime. Thus, I've decided to go with [DietPi](https://dietpi.com/).

*Oh, I should also mention that due to the **blazing** performance of the SD card, the kernel update that DietPi does at startup took almost 2 hours! Still marginally better than the Raspberry Pi OS, though.*

## RPi Zero's network connectivity

The particular RPi Zero I'm going to use in this project doesn't actually come with a wireless module, so it has literally zero onboard network capability. Fortunately, it turns out that the Pi Zero supports a so-called "Gadget mode", which basically turns the Pi from a USB host into a USB device.

The most common way of using the Gadget mode is running a "virtual Ethernet cable" over the USB connection. This means, the Pi can get both the power and network connectivity from the router with a single USB cable!

Unfortunately, OpenWRT doesn't come with the required RNDIS kernel module out of the box (the same module that's used for Android tethering, by the way). Thankfully, this problem can easily be solved by installing the `kmod-usb-net-rndis` package using `opkg`.

After [setting the ethernet gadget up](https://learn.adafruit.com/turning-your-raspberry-pi-zero-into-a-usb-gadget/ethernet-gadget), the Pi shows up in the Interfaces section of the OpenWRT web interface as `usb0`:

{{ img(caption="`usb0` inteface on my OpenWRT router", src="https://imgs.lemonsh.moe/20230405/usb0.png") }}

Upon adding the `usb0` interface to the LAN bridge, the Pi gets access to the internet and I can ssh into it from my computer.

## Okay, what now?

Now that the pain of getting the network part done is over, it's time to actually set something up on the Pi. I figured it would be cool to run a [Mumble](https://www.mumble.info/) server there!

## Mumble

Due to the constrained resources of the Pi Zero, I used [uMurmur](https://umurmur.net/) instead of the official Mumble server. Life, of course, would be too simple if it was available in the repos, so I had to compile myself.

Not wanting to wait hours for the Pi to install GCC and compile the software, I quickly downloaded the Raspberry Pi OS rootfs and chrooted into it on my PC. I also had to use `qemu-user-static`, as the chroot obviously uses the 32-bit ARM architecture. I built the `umurmurd` binary and transferred it over to the Pi.

I've written a simple systemd unit file for it and set it to start at boot. Miraculously, it worked without any manual intervention on every router power on.

## Worth?

Yes and no.

I tested the solution with my friend from the Attic Project (I'll probably write a blog post about that in the future), and the results were not much worse than what I expected.

On a distance of roughly 50m with no obstacles, we maintained a RSSI of around -65, which is a great value, and allows me to think that the solution would work fine on even longer distances. Unfortunately - although as expected - after I moved behind a concrete building, we lost connection completely.

At the end of the day, I learned a ***lot*** about configuring OpenWRT thanks to this project, and I think that's more important than the actual usefulness of the solution.
