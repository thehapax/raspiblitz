#!/bin/bash

## get basic info
source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf 

# show password info dialog
dialog --backtitle "RaspiBlitz - Recover Setup" --msgbox "Your previous RaspiBlitz config was recovered.

You need to set a new Password A:
A) Master User Password

Passwords B, C & D stay as before.

Follow Password Rules: Minimal of 8 chars,
no spaces and only special characters - or .
Write them down & store them in a safe place.
" 14 52

# call set password a script
sudo /home/admin/config.scripts/blitz.setpassword.sh a

# sucess info dialog
dialog --backtitle "RaspiBlitz" --msgbox "OK - password A was set\nfor all users pi, admin, root & bitcoin" 6 52

# activate lnd & bitcoin service
echo "Enabling Services"
sudo systemctl daemon-reload
sudo systemctl enable lnd.service
sudo systemctl enable ${network}d.service
if [ "${rtlWebinterface}" = "on" ]; then
  sudo systemctl enable RTL
fi

# remove flag that freshly recovered
sudo rm /home/admin/raspiblitz.recover.info

# when auto-unlock is activated then Password C is needed to be restored on SD card
if [ "${autoUnlock}" = "on" ]; then

  # reset auto-unlock feature
  dialog --backtitle "RaspiBlitz - Setup" --msgbox "You had the Auto-Unlock feature enabled.

In the next dialog you need to re-enter your
ACTUAL/OLD Password C to re-activate the
Auto-Unlock feature. Enter a empty password
to deactivate the Auto-Unlock feature.
" 10 52
  sudo /home/admin/config.scripts/lnd.autounlock.sh on
  dialog --backtitle "RaspiBlitz" --msgbox "FINAL REBOOT IS NEEDED." 6 52

else
  dialog --backtitle "RaspiBlitz" --msgbox "OK - SSH password A set.\nFINAL REBOOT IS NEEDED." 6 52
fi

sudo shutdown -r now