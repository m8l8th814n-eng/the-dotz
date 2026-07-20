sudo systemctl stop bluetooth
sudo btmgmt -i hci0 power off
sudo btmgmt -i hci0 static-addr 38:68:A4:21:DD:75
sudo btmgmt -i hci0 power on
sudo systemctl start bluetooth
