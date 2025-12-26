# Magic-Mirror
**Proxmox CT Server, Raspberry Pi0/1/2/3/4 Client**

I'm going to assume that IF youre setting MagicMirror up this way, then you're comfortable with creating a CT in Proxmox AND are able to SSH into a RPi after SDCard creation as well as assigning static IPs to your kit/CTs.

Here is the process i used to create a containered MM Server and an MM Client utilising a Raspberry Pi0 (rev1.2). **please only consider this info accurate up to Jan 2026.** I'm a n00b and I'll for get this is here unless I get an email for something i did wrong, soo yeah bear that in mind ;)


Walkthroughs I am duplicating here (abeit with updated packages), incase sources disappear, I take no credit for the creation/deletion of these.

[Server (MM Forum)](https://forum.magicmirror.builders/topic/11003/getting-mm-running-on-debian-10-not-on-a-rpi "Server (MM Forum)")

[Client (github.io)](https://reelyactive.github.io/diy/pi-kiosk/ "Client (github.io)")

[Auto Login (Proxmox Forum Post)](https://forum.proxmox.com/threads/is-it-possible-to-have-containers-auto-login-on-the-web-gui-like-the-node.62097/post-391377 "Auto Login (Proxmox Forum Post)")

------------

## LXC / Proxmox CT Server Setup

**Proxmox 9.0.11, Create CT, Debian 13.1-2 (LXC base Image available from Proxmox)... 4GiB disk, 256MiB Mem & Swap , 1CPU Core, Unprivilege = Yes or No, Nesting = 1 (if "Unprivilege = no" after CT generation you will have to enable nesting), Network = enabled, Static IP preferable** 

<img width="506" height="297" alt="image" src="https://github.com/user-attachments/assets/70911176-1f64-42ee-a736-fd4f91a6d243" />


------------

First we'll do an update of the container. 
```
apt update && apt upgrade -y
```
------------

### Creating a User

If using linux for anything its pretty solid practice to install packages and things via a user rather than root, creation of a user should be done as root, as it allows for groups to be set, especially the "sudo" ability of the user. since its a fresh container, the only user currently is root, so that solves a problem. you can call your user anything, i am using the user `mm` for this guide
```
adduser mm
```
<img width="419" height="249" alt="image" src="https://github.com/user-attachments/assets/a9673e6a-c12c-4033-b787-4c67a67e5614" />

After user creation, we add the `user` to the `sudo` group (which allows us to execute `sudo` commands when required) 
`-a` (Append) Adds the user to the specified group without removing them from other groups, 
`-G` (Group) Specifies the group to which the user should be added. In this case `sudo`.

```
usermod -aG sudo mm
```

We can check the groups of the `user` by using the `groups` command
```
groups mm
```

you can do this before and after `usermod` to confirm changes have stuck

<img width="288" height="87" alt="image" src="https://github.com/user-attachments/assets/c0aafcdb-4e63-4edb-9fd4-0dd9ceea2f61" />


Lastly we need to install the `sudo` & `curl` package as `root` to allow `sudo` & `curl` commands to be undertaken by the new user. 

```
apt install sudo curl
```
<img width="687" height="326" alt="image" src="https://github.com/user-attachments/assets/b5a96966-7a52-430d-938e-dac694d559d8" />


all further install steps should be undertaken as this new user. we'll switch to user and change the working directory to `mm home`

```
su mm
```
```
cd #
```
<img width="192" height="66" alt="image" src="https://github.com/user-attachments/assets/dd4386ea-ae6a-4cb9-9de0-9c2fef82bb29" />




Since initial writing of this guide i have been made aware of a more streamlined way of installing and updating a MM Server instance.

https://github.com/sdetweil/MagicMirror_scripts

using this install script it doesnt really matter if you y/n the screensaver diasable promt as it will be a server
I, personally, use PM2 for easier process interaction. completely your choice, i will cover the setup of PM2 further down

<img width="1016" height="1121" alt="image" src="https://github.com/user-attachments/assets/557d6eee-32df-4332-8726-5ee4eb1d5e71" />



 
------------

### IP Settings

To find out which IP your CT is on we need to ask it look for the IP tied to the interface you are using, in this example,`eth0@if5` so an IP of `192.168.0.227` at this point you can all so see its MAC address `bc:24:11:6d:ab:d4` copy and save these somewhere safe for later & we'll set up static IPs
```
ip -a
```
<img width="839" height="277" alt="image" src="https://github.com/user-attachments/assets/468e9e94-2ae8-4bb1-ae26-a7fdd4f92716" />



To get the Server to be viewable from a Client or any web browser on your network are now going to tell the server which IP to attach itself to and which IPs are allowed to access the server.
```
sudo nano ~/MagicMirror/config/config.js
```
Change the address IP the IP we found earlier (for me i am happy to have `...0.227` as my static/reserved IP. No real NEED to delete the 127.x.x.x address that is there. I just wanted to remove variables when I was testing)

Modify the ipWhitelist entry to give any number of devices on your network access to the server. You can list any number of, comma separated, individual IPs or IP Ranges, also dont forget the "" marks around your IP entries.

![config](https://user-images.githubusercontent.com/48180011/175962259-096cac65-7d14-4219-8c06-fb7056c5d459.png)

<img width="1151" height="474" alt="image" src="https://github.com/user-attachments/assets/d2021371-f805-40b3-91c3-5eaf3515a324" />


At this stage you will have to set your networks DHCP client to reserve the IP address. This ensures that your MM Server always appears in the same place and the DHCP does not "duplicate" the IP/give it out to a different device.
Most routers are different in their process for DHCP reservation, but you will at least need the MAC and the desired IP.


Good job on opening your server to your network!

------------

### Finally, start the server!!

Ensure you're in "~/MagicMirror", we need to use this command and wait for the terminal to show:-
"Ready to go! Please Point your browser to..."
```
node serveronly
```
<img width="839" height="858" alt="image" src="https://github.com/user-attachments/assets/4c9b416f-de30-49e4-aa8d-e79b36e05b2b" />


To exit the 'node serveronly' script just Ctrl+C back to CLI

------------

### **OPTIONAL** Auto login for CT

I wanted mine to auto login and run the script, for instance after a PVE reboot/shutdown, here's how i did it. N.B. make sure you have a password setup for @root for security reasons.

```
sudo systemctl edit container-getty@.service
```

insert at Line 3
```
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin mm --noclear --keep-baud tty%I 115200,38400,9600 $TERM
```
<img width="757" height="130" alt="image" src="https://github.com/user-attachments/assets/7d9a74e1-fbf4-43e3-be7a-6d0b860463a2" />


------------

### Autorun PM2 at CT Start & Restart on Crash
For this we can use [PM2]([url](https://pm2.keymetrics.io/docs/usage/quick-start/)) a Process Manager that was installed if chosen from the setup link above. 

We need to give PM2 a .sh file to load in
```
nano ~/MagicMirror/installers/mm-server.sh
```
only need to give this a two liner
```
cd ~/MagicMirror
npm run server
```

```
pm2 delete 0 && pm2 start ~/MagicMirror/installers/mm-server.sh && pm2 save
```

Reboot to confirm server comes up with CT with 
```
pm2 status
```
<img width="1121" height="107" alt="image" src="https://github.com/user-attachments/assets/4a34ea61-5223-4e53-b5a9-0b1286ce5e6c" />


------------
------------

# Raspberry Pi 0/1/2/3/4/5 Client Setup

Now outlined in my `MM-Client` repo. Auto installer for most rpis, I have confirmed Pi Zero W (a little slow, but works fine for a client), Zero 2W, 3 and 4. I do not own any others for testing. I'd expect Pi 1 & 2 to also struggle, mileage may vary.

https://github.com/D3dl3g/MM-Client
