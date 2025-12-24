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
```adduser mm```
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
sudo nano MagicMirror/config/config.js
```
Change the address IP to your Static IP allocation for the CT (no real NEED to delete the 127.x.x.x address that is there. I just wanted to remove variables when I was testing)

Modify the ipWhitelist entry to give any number of devices on your network access to the server. You can list any number of, comma separated, individual IPs or IP Ranges, also dont forget the "" marks around your IP entries.

![config](https://user-images.githubusercontent.com/48180011/175962259-096cac65-7d14-4219-8c06-fb7056c5d459.png)

<img width="1151" height="474" alt="image" src="https://github.com/user-attachments/assets/d2021371-f805-40b3-91c3-5eaf3515a324" />


Good job on opening your server to your network!

------------

### Finally, start the server!!

Ensure you're in "/root/MagicMirror", we need to use this command and wait for the terminal to show:-
"Ready to go! Please Point your browser to..."
```
node serveronly
```
![MMServerrunning](https://user-images.githubusercontent.com/48180011/175963138-93fae6b1-6bde-45d3-abae-35ee1ae5fef2.png)

To exit the 'node serveronly' script just Ctrl+C back to CLI


------------

### **OPTIONAL** Auto login for CT

I wanted mine to auto login and run the script, for instance after a PVE reboot/shutdown, here's how i did it. N.B. make sure you have a password setup for @root for security reasons.

```
systemctl edit container-getty@.service
```

insert
```
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 $TERM
```
![autologin](https://user-images.githubusercontent.com/48180011/175963211-7ba76e74-9ffa-452d-bd70-31f50d853e70.png)

------------

### **OPTIONAL** Autorun at CT Start & Restart on Crash
For this we can use [PM2]([url](https://pm2.keymetrics.io/docs/usage/quick-start/)) a Process Manager that looks after restarts (enabled by default) and start-on-boot (using the autostart command).
```
npm install pm2 -g && pm2 autostart
```
now we need to give PM2 a .sh file to load in
```
touch /root/MagicMirror/MagicMirror.sh && nano /root/MagicMirror/MagicMirror.sh
```
only need to give this a two liner
```
cd /root/MagicMirror/
npm run server
```
Tell PM2 to start your .sh file as a process and pm2 save to remember your choices.
```
pm2 start /root/MagicMirror/MagicMirror.sh && pm2 save
```

Reboot to confirm server comes up with CT

![serverstatus](https://user-images.githubusercontent.com/48180011/175962458-c95805e3-23de-4e5f-8670-ee21eee29e49.png)

------------
------------

# Raspberry Pi 0/1/2/3/4 Client Setup
**Now to set up the Client for attchment to your screen in you MagicMirror. Auto install Script is now available in my other Repo https://github.com/D3dl3g/MM-Client Script takes care of all of the install, you only need to give it a clean build of PiOS Lite Bullseye**

Set yourself up with a Pi0/Pi0 W/Pi0 WH/Pi0 2 W/Pi/Pi2/Pi3/Pi4, running PiOS Lite Bullseye (Later OSes dont appear to work Bookworm has some funky issues with the way i have the script working. im yet to do more testing to confirm/deny), have a WiFi Dongle attached (if "non-W" varient), SSH Enabled, and your wpa-supplicant set. 
SSH into it with user 'pi',
```
sudo raspi-config
```
Select options "1 > S5 > B2" to run console autologin at boot

Aim of the game here is to keep as light as we can so this is about as stripped down as i could find a 'kiosk' based walkthrough.

------------

First off, you guessed it, house keeping
```
sudo apt update && sudo apt upgrade -y
```

Disable and remove swap file. Reduces read/write wear on SD cards, i still dont know why this is default on for RPi... imho theres really no need for it given the intended use of the SBC.

First we stop the swapping service:
```
sudo service dphys-swapfile stop
```

Then we check if the swapping is switched off:
```
free
```

If the “Swap” line only has “0” values, we can disable the swap service.
```
sudo systemctl disable dphys-swapfile
```


Or remove completely.
```
sudo apt-get purge dphys-swapfile
```

A restart is not necessary.

------------

### X11

We need a bunch of X11 stuff since we used Pi OS Lite, to give us a GUI output to our screen. Chromium which we can set up into a "kiosk" mode later and a windows manager because we have X11 and we have a browser, but we need something inbetween... like a little raspi sandwich... xautomation and unclutter help to keep your screen free of litter
```
sudo apt install --no-install-recommends -y xserver-xorg xinit x11-xserver-utils chromium-browser matchbox-window-manager unclutter
```

------------

### Kiosk Window
Now we setup the Kiosk display most of this is pretty uniform accross kiosk builds so im not explaining what all the triggers do.

```
nano ~/kiosk
```
and insert (dont forget to modify **MM SERVER IP** on the last line, you can use DNS Name or IP for your instance, for example http://MMServer.home:8080 or http://192.168.0.20:8080)
```
#!/bin/sh
xset -dpms     # disable DPMS (Energy Star) features.
xset s off     # disable screen saver
xset s noblank # don't blank the video device
matchbox-window-manager -use_titlebar no &
unclutter &    # hide X mouse cursor unless mouse activated
chromium-browser --display=:0 --kiosk --incognito --window-position=0,0 http://**MM SERVER IP**
```

Now we set the virtual terminal, so it displays properly on a physical screen.
```
nano ~/.bashrc
```
Insert at the bottom. this starts the X server, and runs the script in the previously created `kiosk` file
`/pi/` will need to be replaced with whatever your user is. if your user is `pi` then this code addition will be fine
```
xinit /home/pi/kiosk -- vt$(fgconsole)
```

------------

# Fin
THATS IT. Your client is set up now!! (aside from a quick reboot)

Connect it to a screen power it up and you should see an output from your server.

------------
------------

### A couple of points worthy of note

I experienced difficulty in getting 1080p output to my display, it defaulted to 1024x768 which, spacing wise, isnt... ideal. im not 100% sure why it didnt pick the monitor up automatically. so if you do come accross this heres a solution that worked for me.

Whilst still in the SSH window... but with display connected.

Find connected display options from EDID
```
DISPLAY=:0 xrandr --verbose
```
Choose your desired resolution from the supported list (no need to worry about framerate, I'm lead to believe it can get messy, fast)

setting for **Display :0**(Primary Display), i want  **xrandr** to control my screen  **-s**ize, and i want it to be **1920x1080**, Type:
```
DISPLAY=:0 xrandr -s 1920x1080
```
Go and check your ouput on your display, it should now be the resolution you desire.
sadly on reboot it wont stay that way, so we want to set it to apply the new setting every time it boots. 

------------


looking back at the verbose output First 2 lines of  the output it should look alittle something like this:

`** Screen 0 **: minimum 320 x 200, current 1024 x 768, maximum 2048 x 2048`

`** HDMI-1 ** connected primary 1024x768+0+0 (0x53) normal (normal left inverted right x axis y axis) 797mm x 334mm`

Note "**Screen ***" and "**HDMI-***"
because now we need to create/modify xorg.conf. Chances are itll be a create because it doesnt come, out of the box, with any parameters set. From what i have read, on the internet, be it true or not,  /etc/X11/xorg.conf will be, one of, if not, THE LAST file location that X11 will look for a config and its a pretty short dir tree to type, so may as well put config file there, right!
```
sudo nano /etc/X11/xorg.conf
```
Identifier and Device are the figures you noted from your --verbose output earlier. If theyre different than mine, adjust as required.
```
Section "Screen"
        Identifier "Screen 0"
        Device "HDMI-1"
        SubSection "Display"
                Modes "1920x1080"
        EndSubSection
EndSection
```

Ctrl+X, Y, Enter, to Save.  aaaand reboot. 
