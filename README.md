# Magic-Mirror
**Proxmox CT Server, Raspberry Pi0/1/2/3/4 Client**

I'm going to assume that IF youre setting MagicMirror up this way, then you're comfortable with creating a CT in Proxmox AND are able to SSH into a RPi after SDCard creation as well as assigning static IPs to your kit/CTs.

Here is the process i used to create a containered MM Server and an MM Client utilising a Raspberry Pi0 (rev1.2). For the next couple of months i may add to this as i find more streamlined ways of doing things via suggestions/research but **please only consider this info accurate up to June 2022.** I'm a n00b and I'll for get this is here unless I get an email for something i did wrong, soo yeah bear that in mind ;)


Walkthroughs I am duplicating here, incase sources disappear, I take no credit for the creation/deletion of these.

[Server (MM Forum)](https://forum.magicmirror.builders/topic/11003/getting-mm-running-on-debian-10-not-on-a-rpi "Server (MM Forum)")

[Client (github.io)](https://reelyactive.github.io/diy/pi-kiosk/ "Client (github.io)")

[Auto Login (Proxmox Forum Post)](https://forum.proxmox.com/threads/is-it-possible-to-have-containers-auto-login-on-the-web-gui-like-the-node.62097/post-391377 "Auto Login (Proxmox Forum Post)")

------------

## LXC / Proxmox CT Server Setup

**Proxmox 7.2-4, Create CT, Debian 11.0-1 (LXC base Image available from Proxmox)... 4GiB disk, 256MiB Mem (memory can be dropped after install if desired i dropped mine to 128MiB), 1CPU Core, Unprivilege = No, Nesting = 1 (after CT generation), Network = enabled, Static IP preferable** 

![prox](https://user-images.githubusercontent.com/48180011/175961753-b9a17946-af2f-48be-9a0c-6bdf6d6a131e.png)

------------

First we'll do an update of the container. 
```
apt update && apt upgrade -y
```

------------

### Required Packages
To allow your CT to actually be a server for your MagicMirror. We need to install a small handful of packages, as they dont come "pre-bundled" with your CT Image (a CT is stripped of the usual tools you will find in OS), so we'll need to install "Sudo", "Curl", "Wget" & "Git" "build-essential" "unzip" "gcc" "g++" "make"
  
We will need to pull the latest copy of Node.js, for install, from NodeSource. (v18.x at the time of writing this), update the repos and install.
  
Next, we'll need NPM (NPM Installed with nodejs, hence no 'individual' install line) and Yarn (which is the bit that lets NPM and JS stuff play nicely together)

```
apt install sudo curl wget git build-essential unzip gcc g++ make
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt install nodejs
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && apt update && apt install yarn
```
  
------------

### Installing MagicMirror

Now thats all the underlying systems taken care off, its time to "git" MM.
```
git clone https://github.com/MichMich/MagicMirror
```
Change working directory to...
```
cd MagicMirror/
```

...and do this usual step so we dont loose the default layout or break anything permenently.
```
cp config/config.js.sample config/config.js
```
Now we install the NPM goodies along with an audit fix, which seems to fix any warnings that crop up, then force the latest version (at time of writing 8.13.1)
"--only=prod --omit=dev" args seem to be required as stated at MM install page.

![npmold](https://user-images.githubusercontent.com/48180011/175962006-45a8ae9a-2ade-4301-9057-672047fed6a9.png)![npminstall](https://user-images.githubusercontent.com/48180011/175962021-760b9dbe-e695-4776-ad7c-0f4c26da7ff3.png)
```
npm install --only=prod --omit=dev
npm audit fix
npm install -g npm@8.13.1
```
Last little bit of housekeeping
```
apt update && apt upgrade -y && apt autoremove -y
```

------------

### IP Settings
To get the Server to be viewable from a Client or any web browser on your network are now going to tell the server which IP to attach itself to and which IPs are allowed to access the server.
```
nano /root/MagicMirror/config/config.js
```
Change the address IP to your Static IP allocation for the CT (no real NEED to delete the 127.x.x.x address that is there. I just wanted to remove variables when I was testing)

Modify the ipWhitelist entry to give any number of devices on your network access to the server. You can list any number of, comma separated, individual IPs or IP Ranges, also dont forget the "" marks around your IP entries.

![config](https://user-images.githubusercontent.com/48180011/175962259-096cac65-7d14-4219-8c06-fb7056c5d459.png)

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
**Now to set up the Client for attchment to your screen in you MagicMirror.**

Set yourself up with a Pi0/Pi0 W/Pi0 WH/Pi0 2 W/Pi/Pi2/Pi3/Pi4, running PiOS Lite, have a WiFi Dongle attached (if "non-W" varient), SSH Enabled, and your wpa-supplicant set. 
SSH into it with user 'pi'

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
Now we setup the Kiosk display most of this is pretty uniform accross MM builds so im not explaining it

```
nano ~/kiosk
```
and insert
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
Insert at the bottom. dont know if it matters but its what worked for me
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
