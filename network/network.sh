TOP_DIR=$(cd $(dirname "$0") && pwd)
echo ${TOP_DIR}
CONF_DIR=${TOP_DIR}/conf

#sysctl 
cp -f ${CONF_DIR}/sysctl.conf /etc/sysctl.conf
sysctl -p
source admin-openrc.sh
CheckIPAddr()
{
    echo $1|grep "^[0-9]\{1,3\}\.\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}$" > /dev/null;
    #IPµØÖ·±ØÐëÎªÈ«Êý×Ö
    if [ $? -ne 0 ]
    then
    return 1
    fi
    ipaddr=$1
    a=`echo $ipaddr|awk -F . '{print $1}'` #ÒÔ"."·Ö¸ô£¬È¡³öÃ¿¸öÁÐµÄÖµ
    b=`echo $ipaddr|awk -F . '{print $2}'`
    c=`echo $ipaddr|awk -F . '{print $3}'`
    d=`echo $ipaddr|awk -F . '{print $4}'`
    for num in $a $b $c $d
    do
    if [ $num -gt 255 ] || [ $num -lt 0 ]   #Ã¿¸öÊýÖµ±ØÐëÔÚ0-255Ö®¼ä
    then
    return 1
    fi
    done
    return 0
}


if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ $# -lt 3 ]; then
    echo "args error"
    echo "example:./sh controller <conroll_ip> <date_ip>"
    exit 1
    else
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
	CheckIPAddr $1
        if [ $? -eq "1"  ];then
                echo "controll ip error"
                exit 1
        fi


fi
CONTROLLER=$1
NETWORK=$2
TUNNEL_IP=$3
#CONTROLLER=$2
#INSTANCE_TUNNELS_INTERFACE_IP_ADDRESS=$3
echo "${CONTROLLER}      controller">>/etc/hosts
echo "${NETWORK}        network">>/etc/hosts
apt-get update

#apt-get install python-software-properties
#apt-get install software-properties-common
#this is the version of openstack
#add-apt-repository cloud-archive:juno
#apt-get update




apt-get -y --force-yes install neutron-plugin-ml2 neutron-plugin-openvswitch-agent \
openvswitch-datapath-dkms \
neutron-l3-agent neutron-dhcp-agent
#install in network node
apt-get -y --force-yes install neutron-plugin-ml2
apt-get -y --force-yes install neutron-plugin-openvswitch-agent
apt-get -y --force-yes install openvswitch-datapath-dkms
apt-get -y --force-yes install neutron-l3-agent neutron-dhcp-agent

cp -f ${CONF_DIR}/neutron.conf /etc/neutron/neutron.conf
SERVICE_TENANT_ID=$(keystone tenant-get service | awk '/ id / {print $4}')
echo ${SERVICE_TENANT_ID}
sleep 2


sed -i "/^nova_admin_tenant_id/c nova_admin_tenant_id = ${SERVICE_TENANT_ID}" /etc/neutron/neutron.conf
cp -f ${CONF_DIR}/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini
cp -f ${CONF_DIR}/l3_agent.ini /etc/neutron/l3_agent.ini
cp -f ${CONF_DIR}/dhcp_agent.ini /etc/neutron/dhcp_agent.ini
cp -f ${CONF_DIR}/metadata_agent.ini /etc/neutron/metadata_agent.ini
#sed -i "/local_ip =/c local_ip = ${TUNNEL_IP}" /etc/neutron/plugins/ml2/ml2_conf.ini
sleep 2

sed -i "/^local_ip/c local_ip = ${TUNNEL_IP}" /etc/neutron/plugins/ml2/ml2_conf.ini
echo ">>>>>>>>>>>>>>>config l3>>>>>>>>>>>>>>>>"
neutron router-create demo-router
sleep 15


ROUTER_ID=$(neutron router-list  | awk '/ demo-router / {print $2}')
echo ${ROUTER_ID}
neutron net-create ext-net --shared --router:external=True
sleep 15

EXT_NET_ID=$(neutron net-list  | awk '/ ext-net / {print $2}')
echo ${EXT_NET_ID}

#neutron router-gateway-set router1 EXT_NET_ID
sed -i "/^router_id/c router_id = ${ROUTER_ID}" /etc/neutron/l3_agent.ini
sed -i "/^gateway_external_network_id/c gateway_external_network_id = ${EXT_NET_ID}" /etc/neutron/l3_agent.ini

