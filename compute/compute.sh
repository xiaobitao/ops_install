#!/bin/sh

#��֤IP��ַ
CheckIPAddr()
{
    echo $1|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null;
    #IP��ַ����Ϊȫ����
    if [ $? -ne 0 ]
    then
    return 1
    fi
    ipaddr=$1
    a=`echo $ipaddr|awk -F . '{print $1}'` #��"."�ָ���ȡ��ÿ���е�ֵ
    b=`echo $ipaddr|awk -F . '{print $2}'`
    c=`echo $ipaddr|awk -F . '{print $3}'`
    d=`echo $ipaddr|awk -F . '{print $4}'`
    for num in $a $b $c $d
    do
    if [ $num -gt 255 ] || [ $num -lt 0 ]   #ÿ����ֵ������0-255֮��
    then
    return 1
    fi
    done
    return 0
}

#prepare

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ $# -lt 3 ]; then
    echo "args error"
    echo "example:./sh <controllerIp> <eth0ip> <eth1ip>"
    exit 1
    else
    	CheckIPAddr $1
    	if [ $? -eq "1"  ];then
    		echo "controllerIp error"
    		exit 1
    	fi
    	CheckIPAddr $2
    	if [ $? -eq "1"  ];then
    		echo "eth0ip error"
    		exit 1
    	fi
    	CheckIPAddr $3
    	if [ $? -eq "1"  ];then
    		echo "eth1ip error"
    		exit 1
    	fi
fi

CONTROLLER=$1
LOCAL=$2
LOCAL2=$3

umask 022

TOP_DIR=$(cd $(dirname "$0") && pwd)
REBOOT_CMD="${TOP_DIR}""/compute2.sh ""${CONTROLLER}"" ""${LOCAL}"" ""${LOCAL2} "">""${TOP_DIR}""/install.log &"
PACKAGETAR="Packages.tar.gz"

if [ ! -f "${PACKAGETAR}" ]; then 
echo "not find ${PACKAGETAR}"
exit -1
fi 


tar zxvf ${PACKAGETAR}
#cp -rf conf conf_temp

mv /etc/apt/sources.list /etc/apt/sources.list.openstackback
echo "deb file://${TOP_DIR} Packages/" > /etc/apt/sources.list
#echo "deb file://${TOP_DIR} Packages/" >> /etc/apt/sources.list

#install
apt-get update
apt-get -y --force-yes dist-upgrade

sed -i '$i\openstack_sh'  /etc/rc.local
sed -i "s#openstack_sh#${REBOOT_CMD}#" /etc/rc.local
echo ${REBOOT_CMD}
reboot
