#!/bin/bash

# This script runs on after start in background
# as a service and gets restarted on failure
# it runs ALMOST every seconds

# INFOFILE - state data from bootstrap
infoFile="/home/admin/raspiblitz.info"

# CONFIGFILE - configuration of RaspiBlitz
configFile="/mnt/hdd/raspiblitz.conf"

# LOGS see: sudo journalctl -f -u background

# Check if HDD contains configuration
configExists=$(ls ${configFile} | grep -c '.conf')
if [ ${configExists} -eq 1 ]; then
    source ${configFile}
else
    source ${infoFile}
fi

echo "_background.sh STARTED"

counter=0
while [ 1 ]
do

  ###############################
  # Prepare this loop
  ###############################

  # count up
  counter=$(($counter+1))

  # gather the uptime seconds
  upSeconds=$(cat /proc/uptime | grep -o '^[0-9]\+')

  ####################################################
  # RECHECK DHCP-SERVER 
  # https://github.com/rootzoll/raspiblitz/issues/160
  ####################################################

  # every 5 minutes
  recheckDHCP=$((($counter % 300)+1))
  if [ ${recheckDHCP} -eq 1 ]; then
    echo "*** RECHECK DHCP-SERVER  ***"

    # get the local network IP
    localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
    echo "localip(${localip})"

    # detect a missing DHCP config 
    if [ "${localip:0:4}" = "169." ]; then
      echo "Missing DHCP detected ... trying emergency reboot"
      sudo shutdown -r now
    else
      echo "DHCP OK"
    fi

  fi

  ####################################################
  # RECHECK PUBLIC IP
  # when public IP changes, restart LND with new IP
  ####################################################

  # every 15min - not too often
  # because its a ping to external service
  recheckPublicIP=$((($counter % 900)+1))
  updateDynDomain=0
  if [ ${recheckPublicIP} -eq 1 ]; then
    echo "*** RECHECK PUBLIC IP ***"

    # execute only after setup when config exists
    if [ ${configExists} -eq 1 ]; then

      # get actual public IP
      freshPublicIP=$(curl -s http://v4.ipv6-test.com/api/myip.php 2>/dev/null)
      echo "freshPublicIP(${freshPublicIP})"
      echo "publicIP(${publicIP})"

      if [ ${#freshPublicIP} -eq 0 ]; then 

        echo "freshPublicIP is ZERO - ignoring"

      # check if changed
      elif [ "${freshPublicIP}" != "${publicIP}" ]; then

        # 1) update config file
        echo "update config value"
        sed -i "s/^publicIP=.*/publicIP=${freshPublicIP}/g" ${configFile}
        publicIP=${freshPublicIP}

        # 2) only restart LND if dynDNS is activated
        # because this signals that user wants "public node"
        if [ ${#dynDomain} -gt 0 ]; then
          echo "restart LND with new environment config"
          # restart and let to auto-unlock (if activated) do the rest
          sudo systemctl restart lnd.service
        fi

        # 2) trigger update if dnyamic domain (if set)
        updateDynDomain=1

      else
        echo "public IP has not changed"
      fi

    else
      echo "skip - because setup is still running"
    fi

  fi

  ###############################
  # LND AUTO-UNLOCK
  ###############################

  # check every 10secs
  recheckAutoUnlock=$((($counter % 10)+1))
  if [ ${recheckAutoUnlock} -eq 1 ]; then

    # check if auto-unlock feature if activated
    if [ "${autoUnlock}" = "on" ]; then

      # check if lnd is locked
      locked=$(sudo -u bitcoin /usr/local/bin/lncli --chain=${network} --network=${chain}net getinfo 2>&1 | grep -c unlock)
      if [ ${locked} -gt 0 ]; then

        echo "STARTING AUTO-UNLOCK ..."

        # building REST command
        passwordC=$(sudo cat /root/lnd.autounlock.pwd)
        command="sudo python /home/admin/config.scripts/lnd.unlock.py '${passwordC}'"
        bash -c "${command}"
      else
        echo "lncli says not locked"
      fi
    else
      echo "auto-unlock is OFF"
    fi
  fi

  ###############################
  # UPDATE DYNAMIC DOMAIN
  # like afraid.org
  # ! experimental
  ###############################

  # if not activated above, update every 6 hours
  if [ ${updateDynDomain} -eq 0 ]; then
    # dont +1 so that it gets executed on first loop
    updateDynDomain=$(($counter % 21600))
  fi
  if [ ${updateDynDomain} -eq 1 ]; then
    echo "*** UPDATE DYNAMIC DOMAIN ***"
    # check if update URL for dyn Domain is set
    if [ ${#dynUpdateUrl} -gt 6 ]; then
      # calling the update url
      echo "calling: ${dynUpdateUrl}"
      echo "to update domain: ${dynDomain}"
      curl --connect-timeout 6 ${dynUpdateUrl}
    else
      echo "'dynUpdateUrl' not set in ${configFile}"
    fi
  fi

  ###############################
  # Prepare next loop
  ###############################

  # sleep 1 sec
  sleep 1

  # limit counter to max seconds per week:
  # 604800 = 60sec * 60min * 24hours * 7days
  if [ ${counter} -gt 604800 ]; then
    counter=0
    echo "counter zero reset"
  fi

done

