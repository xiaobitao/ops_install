#!/bin/sh

sed -if '/compute2.sh/d' /etc/rc.local

#prepare
echo "+++++++++++++++++prepare+++++++++++++++++"
CONTROLLER=$1
LOCAL=$2
LOCAL2=$3

umask 022

TOP_DIR=$(cd $(dirname "$0") && pwd)
CONF_DIR=${TOP_DIR}/conf
echo ${CONF_DIR}
CONTROLLER_HOST=${CONTROLLER}"	controller"

#install
echo "+++++++++++++++++install packages+++++++++++++++++"
apt-get -y install ntp

#apt-get install python-mysqldb
#apt-get install python-software-properties
echo -e "\n" |apt-get -y --force-yes install nova-compute-kvm
apt-get -y --force-yes install python-guestfs

sleep 2

dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-$(uname -r)
cp ${CONF_DIR}/statoverride  /etc/kernel/postinst.d/

sleep 2

apt-get -y --force-yes install neutron-common
apt-get -y --force-yes install neutron-plugin-ml2
apt-get -y --force-yes install neutron-plugin-openvswitch-agent
apt-get -y --force-yes install openvswitch-datapath-dkms

sleep 5

#config
echo "+++++++++++++++++config+++++++++++++++++"
cp -f ${CONF_DIR}/ntp.conf /etc/
cp -f ${CONF_DIR}/nova.conf /etc/nova/nova.conf

sleep 2

sed -i "/^my_ip/c my_ip = ${LOCAL}" /etc/nova/nova.conf
sed -i "/^vncserver_proxyclient_address/c vncserver_proxyclient_address = ${LOCAL}" /etc/nova/nova.conf
sed -i "/novncproxy_base_url/s/controller/${CONTROLLER}/" /etc/nova/nova.conf
rm -f /var/lib/nova/nova.sqlite

cp -f ${CONF_DIR}/sysctl.conf /etc/sysctl.conf
sysctl -p

cp -f ${CONF_DIR}/neutron.conf /etc/neutron/neutron.conf
cp -f ${CONF_DIR}/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini

sleep 2

sed -i "/^local_ip/c local_ip = ${LOCAL2}" /etc/neutron/plugins/ml2/ml2_conf.ini

#network config
echo "+++++++++++++++++network config+++++++++++++++++"
sed -i '1i\openstack_controller'  /etc/hosts
sed -if "s#openstack_controller#${CONTROLLER_HOST}#" /etc/hosts

#restart service
echo "+++++++++++++++++restart service+++++++++++++++++"
service openvswitch-switch restart
ovs-vsctl add-br br-int
service nova-compute restart
service neutron-plugin-openvswitch-agent restart

#clean
echo "+++++++++++++++++clean+++++++++++++++++"
rm -rf /etc/apt/sources.list
mv /etc/apt/sources.list.openstackback /etc/apt/sources.list
#sed -i '$d' /etc/apt/sources.list
sleep 2
rm -rf Packages

echo "+++++++++++++++++Install over+++++++++++++++++"
