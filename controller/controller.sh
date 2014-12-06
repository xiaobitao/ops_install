#!/bin/sh

#验证IP地址
CheckIPAddr()
{
    echo $1|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null;
    #IP地址必须为全数字
    if [ $? -ne 0 ]
    then
    return 1
    fi
    ipaddr=$1
    a=`echo $ipaddr|awk -F . '{print $1}'` #以"."分隔，取出每个列的值
    b=`echo $ipaddr|awk -F . '{print $2}'`
    c=`echo $ipaddr|awk -F . '{print $3}'`
    d=`echo $ipaddr|awk -F . '{print $4}'`
    for num in $a $b $c $d
    do
    if [ $num -gt 255 ] || [ $num -lt 0 ]   #每个数值必须在0-255之间
    then
    return 1
    fi
    done
    return 0
}
    
#check input

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
 
if [ $# -lt 2 ]; then
    echo "args error"
    echo "example:./sh <eth0ip> <eth1ip>"
    exit 1
    else
    	CheckIPAddr $1
    	if [ $? -eq "1"  ];then
    		echo "eth0ip error"
    		exit 1
    	fi
    	CheckIPAddr $2
    	if [ $? -eq "1"  ];then
    		echo "eth1ip error"
    		exit 1
    	fi
fi

CONTROLLER=$1
INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS=$2

umask 022

TOP_DIR=$(cd $(dirname "$0") && pwd)
REBOOT_CMD="sh ""${TOP_DIR}""/controller2.sh ""${CONTROLLER}"" ""${INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS}"">""${TOP_DIR}""/install.log &"
PACKAGETAR="Packages.tar.gz"

if [ ! -f "${PACKAGETAR}" ]
	then 
		echo "not find ${PACKAGETAR}"
		exit -1
fi 


tar zxvf ${PACKAGETAR}
#cp -rf conf conf_temp

echo "+++++++++++++++++update sources.list+++++++++++++++++"
mv /etc/apt/sources.list /etc/apt/sources.list.openstackback
echo "deb file://${TOP_DIR} Packages/" > /etc/apt/sources.list
#echo "deb file://${TOP_DIR} Packages/" >> /etc/apt/sources.list
cat /etc/apt/sources.list

#install
#apt-get install python-software-properties
#add-apt-repository cloud-archive:icehouse
apt-get update

#config mysql
echo "+++++++++++++++++check mysql+++++++++++++++++"
r=`dpkg -l | grep "ii  mysql-server"`
if [ -z "$r" ]
	then
		echo "install mysql-server"
		apt-get -y --force-yes install mysql-server
		sleep 2
fi

cp -f conf/my.cnf /etc/mysql/my.cnf
service mysql restart
mysql_install_db
mysql_secure_installation
#end mysql

apt-get -y --force-yes dist-upgrade

sed -i '$i\openstack_sh'  /etc/rc.local
sed -i "s#openstack_sh#${REBOOT_CMD}#" /etc/rc.local
echo ${REBOOT_CMD}
reboot
