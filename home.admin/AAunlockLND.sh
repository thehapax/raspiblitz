#!/bin/bash

# load raspiblitz config data (with backup from old config)
source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf
if [ ${#network} -eq 0 ]; then network=`cat .network`; fi
if [ ${#network} -eq 0 ]; then network="bitcoin"; fi
if [ ${#chain} -eq 0 ]; then
  echo "gathering chain info ... please wait"
  chain=$(${network}-cli getblockchaininfo | jq -r '.chain')
fi

clear
echo ""
echo "****************************************************************************"
echo "Unlock LND Wallet --> lncli --chain=${network} unlock"
echo "****************************************************************************"
echo "HELP: Enter your PASSWORD C"
echo "You may wait some seconds until you get asked for password."
echo "****************************************************************************"
while :
  do
    sudo -u bitcoin /usr/local/bin/lncli --chain=${network} unlock
    sleep 4
    locked=$(sudo tail -n 1 /mnt/hdd/lnd/logs/${network}/${chain}net/lnd.log | grep -c unlock)
    if [ ${locked} -eq 0  ]; then
      break
    fi

    echo ""
    echo "network(${network}) chain(${chain})"
    sudo tail -n 1 /mnt/hdd/lnd/logs/${network}/${chain}net/lnd.log
    echo "Wallet still locked - please try again or Cancel with CTRL+C"
  done
