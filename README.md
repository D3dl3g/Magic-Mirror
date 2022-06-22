# Magic-Mirror
Proxmox Server, Raspberry Pi 0 Client


Info Taken from, duplicating here, incase sources disappear

https://forum.magicmirror.builders/topic/11003/getting-mm-running-on-debian-10-not-on-a-rpi

https://reelyactive.github.io/diy/pi-kiosk/


## LXC / Proxmox CT Server Setup

Proxmox 7.2-4, Create CT, Debian 11.0-1 (LXC base Image available from Proxmox)... 4GiB disk, 256MiB Mem, 1CPU Core, Unprividlege <Deselect>, Nesting <Select> (after CT generation)


  
First we'll do an update of the container. 

apt update && apt upgrade -y && apt -autoremove 


This is the install for the CT to allow it to act as a Server for your Magic Mirror. as were using a CT its core is stripped of the usual tools you will find in Debian OS, so we'll need to install "Sudo", "Curl", "Wget", "Git", "Build Essentials", "unzip", "GCC", "G++" and finally "Make"
  
We will need to Pull the latest copy of Node.js, for install, from NodeSource. (v18.x at the time of writing this) update the repos and install.
  
Next, we'll need NPM and Yarn (which is the bit that lets NPM and JS stuff play nicely together)
apt -y install sudo curl wget git build-essential unzip gcc g++ make
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash - && apt update && apt install -y nodejs
apt install -y npm
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add - && echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list && apt update && apt install yarn

  
Now thats all the underlying systems taken care off, its time to "git" MM.
git clone --depth=1 https://github.com/MichMich/MagicMirror.git

change working directory to...
cd MagicMirror/

...and do this usual step so we dont loose the default layout or break anything permenently.
cp config/config.js.sample config/config.js

now we install the NPM goodies along with an audit fix, which seems to fix any warnings that crop up then force the latest version (at time of writing 8.12.2)
npm install && npm audit fix && npm install -g npm@8.12.2

then the last bit of housekeeping
apt update && apt upgrade -y && apt -autoremove
