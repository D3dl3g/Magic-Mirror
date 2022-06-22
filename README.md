# Magic-Mirror
Proxmox CT Server, Raspberry Pi0 Client

Im going to assume that IF youre setting MagicMirror up this way, then youre comfortable with creating a CT in Proxmox AND are able to SSH into a RPi after SDCard creation


Walk throughs i am duplicating here, incase sources disappear, i take no credit for the creation of these.

https://forum.magicmirror.builders/topic/11003/getting-mm-running-on-debian-10-not-on-a-rpi

https://reelyactive.github.io/diy/pi-kiosk/

------------

## LXC / Proxmox CT Server Setup

**Proxmox 7.2-4, Create CT, Debian 11.0-1 (LXC base Image available from Proxmox)... 4GiB disk, 256MiB Mem, 1CPU Core, Unprividlege = No, Nesting = 1 (after CT generation)**

------------
First we'll do an update of the container. 
```
apt update && apt upgrade -y && apt -autoremove -y 
```

------------

### Required Packages
To allow your CT to actually be a server for your MagicMirror. We need to install a small handful of packages, as they dont come "pre-bundled" with your CT Image (a CT is stripped of the usual tools you will find in OS), so we'll need to install "Sudo", "Curl", "Wget", "Git", "Build Essentials", "unzip", "GCC", "G++" and finally "Make"
  
We will need to pull the latest copy of Node.js, for install, from NodeSource. (v18.x at the time of writing this), update the repos and install.
  
Next, we'll need NPM and Yarn (which is the bit that lets NPM and JS stuff play nicely together)
```
apt -y install sudo curl wget git build-essential unzip gcc g++ make
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash - && apt update && apt install -y nodejs
apt install -y npm
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && apt update && apt install yarn
```
  

------------
### Installing MagicMirror

Now thats all the underlying systems taken care off, its time to "git" MM.
```
git clone --depth=1 https://github.com/MichMich/MagicMirror.git
```
Change working directory to...
```
cd MagicMirror/
```

...and do this usual step so we dont loose the default layout or break anything permenently.
```
cp config/config.js.sample config/config.js
```
Now we install the NPM goodies along with an audit fix, which seems to fix any warnings that crop up, then force the latest version (at time of writing 8.12.2)
```
npm install && npm audit fix && npm install -g npm@8.12.2
```
Last little bit of housekeeping
```
apt update && apt upgrade -y && apt -autoremove
```

------------

### IP Settings
To get the Server to be viewable from a Client or any web browser on your network are now going to tell the server which IP to attach itself to and which IPs are allowed to access the server.
```
nano /MagicMirror/Config/config.js
```
Change the address IP to your Static IP allocation for the CT (no real NEED to delete the 127.x.x.x address that is there. I just wanted to remove variables when I was testing)

Modify the ipWhitelist entry to give any number of devices on your network access to the server. You can list any number of, comma separated, individual IPs or IP Ranges, also dont forget the "" marks around your IP entries.

Good job on opening your server to the network!

------------


### Finally, start the server!!

Ensure you're in "~/MagicMirror", we need to use this command and wait for the terminal to show:-
"Ready to go! Please Point your browser to..."
```
node serveronly
```
To exit the 'node serveronly' script just Ctrl+C back to CLI


------------


------------

## Raspberry Pi 0 Client Setup
Now to set up the Client for attchment to your screen in you MagicMirror.

Set yourself up with a Pi0/Pi0 W/Pi0 WH/Pi0 2 W, running PiOS Lite, have a WiFi Dongle attached, SSH Enabled, and your wpa-supplicant set. 
SSH into it with user 'pi'

Aim of the game here is to keep as light as we can so this is about as stripped down as i could find a 'kiosk' based walkthrough.

------------


First off, you guessed it, house keeping
```
 sudo apt update && sudo apt upgrade -y
 ```

------------

### X11

We need a bunch of X11 stuff since we used Pi OS Lite, to give us a GUI output to our screen. Chromium which we can set up into a "kiosk" mode later and a windows manager because we have X11 and we have a browser, but we need something inbetween... like a little raspi sandwich... xautomation and unclutter help to keep your screen free of litter
```
sudo apt install --no-install-recommends xserver-xorg -y && sudo apt install --no-install-recommends xinit -y && sudo apt install --no-install-recommends x11-xserver-utils -y && sudo apt install chromium-browser -y && sudo apt install matchbox-window-manager xautomation unclutter -y
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

### A point worthy of note

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

`**Screen 0**: minimum 320 x 200, current 1024 x 768, maximum 2048 x 2048`

`**HDMI-1** connected primary 1024x768+0+0 (0x53) normal (normal left inverted right x axis y axis) 797mm x 334mm`

Note "**Screen ***" and "**HDMI-***"
because now we need to create/modify xorg.conf. Chances are itll be a create because it doesnt come, out of the box, with any parameters set. From what i have read, on the internet, be it true or not,  /etc/X11/xorg.conf will be, one of, if not, THE LAST file location that X11 will look for a config and its a pretty short dir tree to type, so may as well put config file there, right!
```
sudo nano /etc/X11/xorg.conf
```
Identifier and Device are the figures you noted from your --verbose output earlier. If theyre different than mine, adjust as required.
````
Section "Screen"
        Identifier "Screen 0"
        Device "HDMI-1"
        SubSection "Display"
                Modes "1920x1080"
        EndSubSection
EndSection
```
Ctrl+X, Y, Enter, to Save.  aaaand reboot. 
