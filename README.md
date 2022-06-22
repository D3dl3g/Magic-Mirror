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
