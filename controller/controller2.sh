#!/bin/sh

#function

KeystoneCheckResult()
{
	sleep 2
	KEYSTONE_CMD="keystone ""$1""-list"
	echo $KEYSTONE_CMD
    if ${KEYSTONE_CMD}|grep $2>/dev/null 2>&1
	then
		return 0
	else
		echo "===================>ERROR:""$1 ""$2"
		return 1
	fi
}

#clean
sed -if '/controller2.sh/d' /etc/rc.local

#prepare
echo "+++++++++++++++++prepare+++++++++++++++++"
CONTROLLER=$1
echo ${CONTROLLER}
INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS=$2
echo ${INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS}

umask 022

TOP_DIR=$(cd $(dirname "$0") && pwd)
echo ${TOP_DIR}
CONF_DIR=${TOP_DIR}/conf
DASHBOARD_DIR=${TOP_DIR}/ui
echo ${CONF_DIR}
CONTROLLER_HOST=${CONTROLLER}"	controller"

#network config
echo "+++++++++++++++++network config+++++++++++++++++"
hostname controller
echo "controller" >/etc/hostname
#su

sed -i '1i\openstack_controller'  /etc/hosts
sed -if "s#openstack_controller#${CONTROLLER_HOST}#" /etc/hosts
echo ${CONTROLLER_HOST}

#install
echo "+++++++++++++++++install ntp+++++++++++++++++"
apt-get -y --force-yes install ntp

echo "+++++++++++++++++install mysql+++++++++++++++++"
#apt-get install python-mysqldb mysql-server
apt-get -y --force-yes install python-mysqldb
sleep 2

#cp -f ${CONF_DIR}/my.cnf /etc/mysql/my.cnf
service mysql restart

#mysql_install_db
#mysql_secure_installation

echo "+++++++++++++++++install Messaging server+++++++++++++++++"
apt-get -y --force-yes install rabbitmq-server
echo "change password..."
rabbitmqctl change_password guest RABBIT_PASS
sleep 10

echo "+++++++++++++++++install keystone+++++++++++++++++"
apt-get -y --force-yes install keystone
sleep 2
echo "init keystone"
cp -f ${CONF_DIR}/keystone.conf /etc/keystone/keystone.conf
rm -f /var/lib/keystone/keystone.db
sleep 2

MYSQL_CMD="mysql -uroot"
echo ${MYSQL_CMD}
create_db_sql="create database IF NOT EXISTS keystone"
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库

if [ $? -ne 0 ]                                                                  #判断是否创建成功
	then
		echo "create databases keystone failed ..."
fi

MYSQL_CMD1="GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'KEYSTONE_DBPASS'"
MYSQL_CMD2="GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS'"
echo ${MYSQL_CMD1}  | ${MYSQL_CMD}
echo ${MYSQL_CMD2}  | ${MYSQL_CMD}

sleep 5

keystone-manage db_sync
sleep 15

ADMIN_TOKEN=`openssl rand -hex 10`
echo ${ADMIN_TOKEN}

sed -i "/^admin_token/c admin_token = ${ADMIN_TOKEN}" /etc/keystone/keystone.conf

service keystone restart

(crontab -l -u keystone 2>&1 | grep -q token_flush) || echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/crontabs/keystone

sleep 2

echo "+++++++++++++++++config keystone+++++++++++++++++"
export OS_SERVICE_TOKEN=${ADMIN_TOKEN}
echo ${ADMIN_TOKEN}
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0
echo ${OS_SERVICE_ENDPOINT}

keystone user-create --name=admin --pass=ADMIN_PASS --email=ADMIN_EMAIL
sleep 5
KeystoneCheckResult user admin
keystone role-create --name=admin
sleep 5
KeystoneCheckResult role admin
keystone tenant-create --name=admin --description="Admin Tenant"
sleep 5
KeystoneCheckResult tenant admin
keystone user-role-add --user=admin --tenant=admin --role=admin
sleep 5
#KeystoneCheckResult user-role admin
keystone user-role-add --user=admin --role=_member_ --tenant=admin
sleep 5
#KeystoneCheckResult user-role _member_

keystone user-create --name=demo --pass=DEMO_PASS --email=DEMO_EMAIL
sleep 5
KeystoneCheckResult user demo
keystone tenant-create --name=demo --description="Demo Tenant"
sleep 5
KeystoneCheckResult tenant demo
keystone user-role-add --user=demo --role=_member_ --tenant=demo
sleep 5
#KeystoneCheckResult user-role demo
keystone tenant-create --name=service --description="Service Tenant"
sleep 5
KeystoneCheckResult tenant service

keystone service-create --name=keystone --type=identity --description="OpenStack Identity"
sleep 5
KeystoneCheckResult service keystone

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl=http://controller:5000/v2.0 \
--internalurl=http://controller:5000/v2.0 \
--adminurl=http://controller:35357/v2.0

sleep 5
KeystoneCheckResult endpoint http://controller:5000/v2.0


echo "+++++++++++++++++install glance+++++++++++++++++"
apt-get -y --force-yes install glance python-glanceclient
sleep 2

rm -f /var/lib/glance/glance.sqlite

create_db_sql2="create database IF NOT EXISTS glance"
echo ${create_db_sql2}  | ${MYSQL_CMD}                         #创建数据库

if [ $? -ne 0 ]                                                                  #判断是否创建成功
then
 echo "create databases glance failed ..."
fi

MYSQL_CMD1="GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS'"
MYSQL_CMD2="GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS'"
echo ${MYSQL_CMD1}  | ${MYSQL_CMD}
echo ${MYSQL_CMD2}  | ${MYSQL_CMD}

sleep 5

glance-manage db_sync
sleep 15

keystone user-create --name=glance --pass=GLANCE_PASS --email=glance@example.com
sleep 5
KeystoneCheckResult user glance
keystone user-role-add --user=glance --tenant=service --role=admin
sleep 5
#KeystoneCheckResult user-role glance
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
sleep 5
KeystoneCheckResult service glance

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://controller:9292 \
--internalurl=http://controller:9292 \
--adminurl=http://controller:9292
sleep 15
KeystoneCheckResult endpoint http://controller:9292

cp -f ${CONF_DIR}/glance-api.conf /etc/glance/glance-api.conf
cp -f ${CONF_DIR}/glance-registry.conf /etc/glance/glance-registry.conf
sleep 2

service glance-registry restart
service glance-api restart

echo "+++++++++++++++++install nova+++++++++++++++++"
apt-get -y --force-yes install nova-api
apt-get -y --force-yes install nova-cert
apt-get -y --force-yes install nova-conductor
apt-get -y --force-yes install nova-consoleauth
apt-get -y --force-yes install nova-novncproxy
apt-get -y --force-yes install nova-scheduler
apt-get -y --force-yes install python-novaclient

#apt-get -y --force-yes install nova-api nova-cert nova-conductor nova-consoleauth \
#nova-novncproxy nova-scheduler python-novaclient

sleep 5

rm -f /var/lib/nova/nova.sqlite

create_db_sql="create database IF NOT EXISTS nova"
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库

if [ $? -ne 0 ]                                                                  #判断是否创建成功
then
 echo "create databases nova failed ..."
fi

MYSQL_CMD1="GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS'"
MYSQL_CMD2="GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS'"
echo ${MYSQL_CMD1}  | ${MYSQL_CMD}
echo ${MYSQL_CMD2}  | ${MYSQL_CMD}

sleep 5

nova-manage db sync
sleep 25
keystone user-create --name=nova --pass=NOVA_PASS --email=nova@example.com
sleep 5
KeystoneCheckResult user nova
keystone user-role-add --user=nova --tenant=service --role=admin
sleep 5
#KeystoneCheckResult user-role nova

echo "+++++++++++++++++config nova+++++++++++++++++"
cp -f ${CONF_DIR}/nova.conf /etc/nova/nova.conf
sleep 2

sed -i "/^my_ip/c my_ip = ${CONTROLLER}" /etc/nova/nova.conf
sed -i "/^vncserver_listen/c vncserver_listen = ${CONTROLLER}" /etc/nova/nova.conf
sed -i "/^vncserver_proxyclient_address/c vncserver_proxyclient_address = ${CONTROLLER}" /etc/nova/nova.conf

keystone service-create --name=nova --type=compute --description="OpenStack Compute"
sleep 5
KeystoneCheckResult service nova
keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://controller:8774/v2/%\(tenant_id\)s \
--internalurl=http://controller:8774/v2/%\(tenant_id\)s \
--adminurl=http://controller:8774/v2/%\(tenant_id\)s
sleep 15
KeystoneCheckResult endpoint http://controller:8774

service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echo "+++++++++++++++++install neutron+++++++++++++++++"

cp -f ${CONF_DIR}/sysctl.conf /etc/sysctl.conf
sysctl -p

create_db_sql="create database IF NOT EXISTS neutron"
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库

if [ $? -ne 0 ]                                                                  #判断是否创建成功
then
 echo "create databases neutron failed ..."
fi

MYSQL_CMD1="GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS'"
MYSQL_CMD2="GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS'"
echo ${MYSQL_CMD1}  | ${MYSQL_CMD}
echo ${MYSQL_CMD2}  | ${MYSQL_CMD}

sleep 5

keystone user-create --name neutron --pass NEUTRON_PASS --email neutron@example.com
sleep 5
KeystoneCheckResult user neutron
keystone user-role-add --user neutron --tenant service --role admin
sleep 5
#KeystoneCheckResult user-role neutron
keystone service-create --name neutron --type network --description "OpenStack Networking"
sleep 5
KeystoneCheckResult service neutron
keystone endpoint-create \
--service-id $(keystone service-list | awk '/ network / {print $2}') \
--publicurl http://controller:9696 \
--adminurl http://controller:9696 \
--internalurl http://controller:9696
sleep 15
KeystoneCheckResult endpoint http://controller:9696

echo ">>>>>>>>>control node"
apt-get -y --force-yes install neutron-server neutron-plugin-ml2 python-neutronclient
sleep 2
echo ">>>>>>>>>net node"

#apt-get -y --force-yes install neutron-plugin-ml2 neutron-plugin-openvswitch-agent \
#openvswitch-datapath-dkms \
#neutron-l3-agent neutron-dhcp-agent
#install in network node
#apt-get -y --force-yes install neutron-plugin-ml2
#apt-get -y --force-yes install neutron-plugin-openvswitch-agent
#apt-get -y --force-yes install openvswitch-datapath-dkms
#apt-get -y --force-yes install neutron-l3-agent neutron-dhcp-agent
sleep 2

cp -f ${CONF_DIR}/neutron.conf /etc/neutron/neutron.conf
SERVICE_TENANT_ID=$(keystone tenant-get service | awk '/ id / {print $4}') 
echo ${SERVICE_TENANT_ID}
sleep 2

sed -i "/^nova_admin_tenant_id/c nova_admin_tenant_id = ${SERVICE_TENANT_ID}" /etc/neutron/neutron.conf

cp -f ${CONF_DIR}/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
cp -f ${CONF_DIR}/l3_agent.ini /etc/neutron/l3_agent.ini
cp -f ${CONF_DIR}/dhcp_agent.ini /etc/neutron/dhcp_agent.ini
cp -f ${CONF_DIR}/metadata_agent.ini /etc/neutron/metadata_agent.ini
sleep 2

sed -i "/^local_ip/c local_ip = ${INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS}" /etc/neutron/plugins/ml2/ml2_conf.ini
echo ">>>>>>>>>>>>>>>config l3>>>>>>>>>>>>>>>>"
#neutron router-create demo-router
#sleep 15

#ROUTER_ID=$(neutron router-list  | awk '/ demo-router / {print $2}') 
#echo ${ROUTER_ID}
#neutron net-create ext-net --shared --router:external=True
#sleep 15

#EXT_NET_ID=$(neutron net-list  | awk '/ ext-net / {print $2}') 
#echo ${EXT_NET_ID}

#neutron router-gateway-set router1 EXT_NET_ID
#sed -i "/^router_id/c router_id = ${ROUTER_ID}" /etc/neutron/l3_agent.ini
#sed -i "/^gateway_external_network_id/c gateway_external_network_id = ${EXT_NET_ID}" /etc/neutron/l3_agent.ini
neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head
echo ">>>>>>>>>>>>>>>config l3 over>>>>>>>>>>>>>"

echo "+++++++++++++++++restart control node service+++++++++++++++++"
#control node service
service nova-api restart
service nova-scheduler restart
service nova-conductor restart
service neutron-server restart

echo "+++++++++++++++++restart net node service+++++++++++++++++"
#net node service
service openvswitch-switch restart
ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex
#ovs-vsctl add-port br-ex eth2

service neutron-plugin-openvswitch-agent restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart

echo "+++++++++++++++++install dashboard+++++++++++++++++"
apt-get -y --force-yes install apache2 memcached libapache2-mod-wsgi openstack-dashboard
apt-get -y --force-yes remove --purge openstack-dashboard-ubuntu-theme
sed -i '/^OPENSTACK_HOST/c OPENSTACK_HOST = "controller"' /etc/openstack-dashboard/local_settings.py

'''
echo "+++++++++++++++++install cinder+++++++++++++++++"
apt-get -y --force-yes install cinder-api
apt-get -y --force-yes install cinder-scheduler

cp -f ${CONF_DIR}/cinder.conf /etc/cinder/cinder.conf

create_db_sql="create database IF NOT EXISTS cinder"
echo ${create_db_sql}  | ${MYSQL_CMD}                         #创建数据库

if [ $? -ne 0 ]                                                                  #判断是否创建成功
then
 echo "create databases cinder failed ..."
fi


MYSQL_CMD2="GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'CINDER_DBPASS'"
MYSQL_CMD3="GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'CINDER_DBPASS'"
echo ${MYSQL_CMD1}  | ${MYSQL_CMD}
echo ${MYSQL_CMD2}  | ${MYSQL_CMD}

sleep 5

cinder-manage db sync
sleep 15

keystone user-create --name=cinder --pass=CINDER_PASS --email=cinder@example.com
sleep 5
KeystoneCheckResult user cinder

keystone user-role-add --user=cinder --tenant=service --role=admin

keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
sleep 5
KeystoneCheckResult service cinder

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volume / {print $2}') \
--publicurl=http://controller:8776/v1/%\(tenant_id\)s \
--internalurl=http://controller:8776/v1/%\(tenant_id\)s \
--adminurl=http://controller:8776/v1/%\(tenant_id\)s

sleep 15
KeystoneCheckResult endpoint http://controller:8776/v1

keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
sleep 5
KeystoneCheckResult service cinderv2

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
--publicurl=http://controller:8776/v2/%\(tenant_id\)s \
--internalurl=http://controller:8776/v2/%\(tenant_id\)s \
--adminurl=http://controller:8776/v2/%\(tenant_id\)s

sleep 15
KeystoneCheckResult endpoint http://controller:8776/v2

service cinder-scheduler restart
service cinder-api restart
'''
#restart service
echo "+++++++++++++++++restart service+++++++++++++++++"

#clean
'''
echo "+++++++++++++++++clean+++++++++++++++++"
rm -rf /etc/apt/sources.list
mv /etc/apt/sources.list.openstackback /etc/apt/sources.list
#sed -i '$d' /etc/apt/sources.list
rm -rf Packages
'''
echo "+++++++++++++++++Install over+++++++++++++++++"
