+++
title="3 fun ways to (ab)use your school OneDrive storage"
date=2022-08-29
+++
If you're a student (or a teacher) and your school/university has an Office 365 plan (e.g. for Microsoft Teams), you probably have an Education Office 365 account, which comes with a whopping 1 TB (!) of OneDrive storage and you're probably not even using 1% of that capacity. Kinda wasteful in my opinion.

But before I list a few fun examples of how you can make use of your school OneDrive, I need to address a few things:
- Everything I talk about here should technically be possible with a Google Education account (or whatever it's called), although I have no experience with that, so YMMV.
- You probably are aware that the administrators of your school Office 365 suite do **not** have access to your files, but you should also know that they have the power to **reset your password** and gain access that way.
- This should be obvious, but your account is **not** permanent - it will eventually be removed (e.g. when you finish school) and you need to be prepared for that.
- The examples I'll be showing are not always the *best* solutions to a given problem, but they are definetely fun ones!

With that out of the way, let's begin!

# rclone

The examples I'll be covering involve the usage of `rclone` - a commandline application that allows you to easily access remote storages of various kinds.

On Windows you can install it with `scoop`, on Linux it should be available in your distro's package manager.

After installation, run `rclone config` and add your OneDrive storage using the `onedrive` remote type - rclone should guide you through that. The rest of this post will assume that the name of the remote is `sch`, so always replace `sch` with *your* remote name if it's different.

# #1: Storing TV Shows, Movies, Music, etc.
The *"default"* way of storing media on OneDrive is inconvenient - gently speaking - so we're gonna use rclone to make it easier and faster. Here's a short quickstart:

### Create a directory for the media
```sh
rclone mkdir 'sch:anime'
```
### Upload media
```sh
rclone copy -P rezero 'sch:anime/rezero'
```
**Note:** When you tell rclone to copy a directory, it copies the **contents** of it, not the directory itself, so it's important to always specify the full destination path, as we did here.

By the way, the `-P` flag adds a nice progress display. If you omit it, rclone will work silently.
### Download media
```sh
rclone copy -P 'sch:anime/rezero/ep1.mkv' .
```
### Get a link to a file (without downloading)
```sh
rclone link 'sch:anime/rezero/ep1.mkv'
```
**Disclaimer:** The generated link likely has your **school name** in it, so don't share it with people you don't trust!

We can use this command with `mpv` in order to stream a video or audio file directly without downloading it:
```sh
mpv $(rclone link 'sch:anime/rezero/ep1.mkv')
```
You can find more rclone commands by doing `rclone --help`.
# #2: Image hosting
Let's say you want to make a website or you just want to have your own hosting of images without exposing the end user to 3rd-party services. Why not make a proxy to your school OneDrive with a cheap VPS or a Raspberry Pi?

*Note: This method requires small Linux server administration knowledge*

In this example I will be using Alpine Linux, but the commands should be easily adaptable to your distribution of choice.

### Setup rclone on the remote machine
Just follow the [rclone](#rclone) section of this post but on your server, **as root/sudo** (we're going to mount the remote and that requires root permissions, so the generated rclone config file should be in the root user's home directory)

You'll also want to create a folder for the images:

```sh
sudo rclone mkdir sch:imgs
```

### Mount the remote
```sh
sudo mkdir /onedrive
sudo rclone mount sch:imgs /onedrive --allow-other -v
```

You should be able to access `/onedrive` as root now. If everything is working properly, you can make the rclone mount persistent using your init system. For example, this is what I made for Alpine (OpenRC):

```sh
#!/sbin/openrc-run
name="onedrive"

depend() {
    need net
    before nginx
    use logger
}

start() {
    checkpath -f -m 0644 -o root:root /var/log/onedrive.log
    rclone mount sch:imgs /onedrive --daemon --allow-other -v --log-file=/var/log/onedrive.log
}

stop() {
    fusermount -uz /onedrive
}

# vim:ft=sh
```

### Configuring the webserver
Setup your webserver to serve static files from /onedrive. You probably want to enable SSL too.

Assuming you're using Nginx, you can add a server block similar to this:

```conf
server {
    listen [::]:443 ssl http2;
    merge_slashes off;

    server_name imgs.lemonsh.moe;
    ssl_certificate /etc/acme/imgs.lemonsh.moe.crt;
    ssl_certificate_key /etc/acme/imgs.lemonsh.moe.key;

    root /onedrive;
}
```
Of course, you need to adapt this config according to your needs.
### Testing the proxy
The `imgs` directory on your OneDrive should now be mapped to your domain's root. For example, in my case, `sch:imgs/image.png` is mapped to `https://imgs.lemonsh.moe/image.png`.

### FAQ
Now you might ask, why can't we just use `rclone link` for the images, just like we did with your media before? Well, there are a few reasons:
- When your current OneDrive account is deleted, all links generated with `rclone link` will become invalid. With a proxy like this, you can migrate the images somewhere else.
- As I've said before, links generated with `rclone link` are likely to contain your school name, which is not desired if you want to embed them on a website, for example.
- You would need to run `rclone link` manually every time you wanted to publish an image, this proxy maps the entire directory instead, so there's no manual intervention required.
- OneDrive generally isn't the fastest file host, so if you run into performance issues with the proxy, you can attempt to fix it - for example, put it behind Cloudflare or [enable the VFS cache in rclone](https://rclone.org/commands/rclone_mount/#vfs-file-caching).

Another question you might have is, why images specifically? Why not music / videos / etc.?

Well, you can technically host any kind of content with this proxy, but I just felt like image hosting is a good demo usecase. Larger files are going to be problematic because for every request, your server needs to use `2 * filesize` of bandwidth (download from OneDrive and then upload to the user), so caching may be unfeasible.

# #3: Storing personal data securely
It's well-known that storing sensitive information in the cloud is a very bad idea, especially with non-private services like OneDrive or Google Drive, because these companies can access your data whenever they want - or when the government wants.

But there's nothing encryption couldn't fix! We can use the `crypt` remote type:

> Rclone `crypt` remotes encrypt and decrypt other remotes.
> A remote of type `crypt` does not access a storage system directly, but instead wraps another remote, which in turn accesses the storage system.

Considering that we're working with sensitive data here, if you have trouble understanding something here, please [RTFM](https://rclone.org/crypt/) so that you don't commit a security fail. With that in mind, let's begin:

### Create an empty folder for the encrypted files
```sh
rclone mkdir sch:enc
```
### Create a `crypt` wrapper
Run `rclone config` and create a new remote of type `crypt` (instead of `onedrive` like we did before). I'll call it `esch`, but you can pick any other name. There are a few things you should know:

- `remote` should be the empty folder you created in the previous step, e.g. `sch:enc`.
- The most secure variant for `filename_encryption` is `standard`, but it has [a few implications](https://rclone.org/crypt/#name-encryption), so you might wanna choose `obfuscate` instead if you think they might be a problem for you.
- You should always generate a random password for security. 128 bits should be a secure enough option.
### Upload something!
You should be able to use the `esch` remote just like any other rclone remote now. The only difference is that its root is mapped to the directory you specified before (e.g. `sch:enc`) and everything going through it is encrypted. So, let's try uploading something now:
```sh
rclone copy -P Pictures/miku-smol.png esch:
```
Let's check if the file was actually uploaded:
```sh
$ rclone lsf esch:
miku-smol.png
```
It was! But how does it look from OneDrive's perspective?
{{ img(caption="`enc` folder on my OneDrive", src="https://imgs.lemonsh.moe/20220828/onedrive.png") }}
As you can see, the file has been encrypted along with its filename.
### Important reminder
Obviously, this doesn't prevent you from uploading sensitive files through the unencrypted `sch` remote or even the OneDrive web interface, so remember to always handle sensitive data through `esch`.
# Config encryption and backup
Your rclone config contains passwords to all of the cloud remotes, so it's wise to protect it somehow. You can do that in `rclone config` by choosing the `s) Set configuration password` option. Upon doing that, you will be asked for a password on every rclone operation. You can always remove the password if you want (e.g. to make manual changes to the config).

In order to backup or migrate all your rclone remotes (including `crypt` if you set that up), you can just copy the entire config file to - for example - a password manager or a different machine. This will work even when you set a password on the file.

The path to the config is `~/.config/rclone/rclone.conf`.

# The end.
~~microsoft please don't arrest me, it's all for educational purposes~~
