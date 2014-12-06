apt-get update
apt-get install -y --force-yes python-software-properties 
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/juno main">> /etc/apt/sources.list.d/ubuntu-cloud-archive-juno-trusty.list
apt-get install -y --force-yes ubuntu-cloud-keyring
apt-get update && apt-get dist-upgrade
reboot
