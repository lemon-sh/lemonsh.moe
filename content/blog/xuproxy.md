+++
title="xuproxy: Outsource your XMPP attachment storage!"
date=2022-01-20
+++
## File sharing in XMPP
While I was setting up my new XMPP server using Prosody, I've looked at a few different options of handling attachment uploads.
XMPP has defined standards for file sharing, including direct P2P transfer, but the most popular option seems to be the [XEP-0363](https://xmpp.org/extensions/xep-0363.html), *"HTTP File Upload"*.

Since this means *uploading* files to the server, as the administrator you need to provide some storage for them.
This was obviously not ideal for my tiny VPS at [mikr.us](https://mikr.us) with 10GB of storage, so I've decided to create an *alternative solution*.

## If you need space, just steal it!
I've implemented a HTTP service in Rust using [warp](https://github.com/seanmonstar/warp) compatible with the [mod_http_upload_external](https://modules.prosody.im/mod_http_upload_external.html) Prosody module. You can find it [on my git](https://git.karx.xyz/lemonsh/xuproxy).

Plot twist: Unlike other implementations, *xuproxy* doesn't store the files on the disk.
Instead, it sends them off to a Discord webhook (or any other compatible webhook), so you only need to provide a MB or two
for the SQLite3 database that keeps track of all the uploaded files and their Discord URLs.
Additionaly, you can set up a daily cleanup task that will wipe old entries from the database and your Discord channel.

## Installation
First, compile *xuproxy*:
```sh
git clone https://git.karx.xyz/lemonsh/xuproxy
cd xuproxy
cargo build --release
```
Then, create a config file for it:
```toml
# Listen address
address = "[::]:443"

# Discord (or compatible) webhook
webhook = "https://discord.com/api/webhooks/..."

# Secret, you can generate it with `head -c18 /dev/urandom | base64`
secret = "cDN/bd4V79jtlQ7xnwO6n7xQ"

# SQlite3 database path
dbpath = "/root/xuproxy.db"

# Attachment retention period in *hours*, see previous section
cleanup = 72  # 3 days

# Delete the tls section to disable TLS.
# You should only do that when you're running the service behind a reverse proxy.

[tls]
key = "/etc/ssl/key.pem"
cert = "/etc/ssl/cert.pem"
```
Now, run *xuproxy* with the following environment variables set:
* *XUPROXY_LOG* - Loglevel, can be one of *trace*, *debug*, *info*, *warn*, *error*. I recommend using *info* here.
* *XUPROXY_CONFIG* - Path to the config TOML file.

## OpenRC init file
Assuming you run the only truly *based* Linux distro, **Alpine Linux**,
you can use the following OpenRC scripts to run xuproxy as a daemon.

*/etc/init.d/xuproxy*
```bash
#!/sbin/openrc-run
command="$XUPROXY_EXECUTABLE"
command_background=true
pidfile="/run/xuproxy.pid"
error_log="/var/log/xuproxy.log"

depend() {
        use logger
}

start_pre() {
        checkpath --file --mode 0644 --owner root:root "/var/log/xuproxy.log"
}
```
*/etc/conf.d/xuproxy*
```bash
export XUPROXY_LOG=info
export XUPROXY_CONFIG="/root/xuproxy.toml"
XUPROXY_EXECUTABLE="/root/xuproxy"
```
Enable the executable bit and start the service:
```bash
chmod +x /etc/init.d/xuproxy
service xuproxy start
```

Remember, since this is a HTTP service, you will also need to expose it.
XMPP clients will connect directly to it, completely bypassing the XMPP server, so it needs to be available on the Internet.

## Configuring Prosody
Append this to your *prosody.cfg.lua*:
```bash
Component "upload.lemonsh.moe" "http_upload_external"
        # Externally reachable URL of xuproxy's HTTP service
        http_upload_external_base_url = "https://upload.lemonsh.moe/"
        # This should be the same as the secret field in xuproxy.toml
        http_upload_external_secret = "cDN/bd4V79jtlQ7xnwO6n7xQ"
```

**Note:** On some distros (including Alpine), Prosody doesn't come with the *http_upload_external* module.
Thus, you need to grab it from the official repo:
```bash
apk add mercurial
cd /tmp
hg clone https://hg.prosody.im/prosody-modules/ prosody-modules
cd prosody-modules
mv http_uploa* /usr/lib/prosody/modules/
```

Restart Prosody and you should be good to go:
```bash
service prosody restart
```

*Thanks for reading!*