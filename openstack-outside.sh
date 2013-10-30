#!/bin/sh

. /root/keystonerc_admin

device=eth0
vlan=192.168.0
start=$vlan.129
end=$vlan.163
gw=$vlan.1
dns1=4.2.2.2
dns2=
hwaddr=`cat /etc/udev/rules.d/70-persistent-net.rules | grep $device | cut -d, -f4 | sed 's/ ATTR{address}=="//g' | sed 's/"//g'`
IP=`ifconfig $device|grep -w inet|awk '{print $2}'|cut -d: -f2`

echo debug $IP

public(){
neutron router-create PublicRouter
neutron net-create PublicLAN --router:external=True
neutron subnet-create PublicLAN $vlan.0/24 --name PublicLAN --enable_dhcp=False --allocation-pool start=$start,end=$end --gateway=$gw --dns_nameservers list=true $dns1 $dns2
neutron router-gateway-set PublicRouter PublicLAN
}

##determine one physical nic or more
##if one nic move ip from nic to br-ex in /etc/sysconfig/network-scripts
device_exist(){
ifconfig $device > /dev/null  2>&1
if ! [ $? -eq 0 ]
then
	echo " ERROR: $device not found"
	exit 1
fi
if [ -f /etc/sysconfig/network-scripts/ifcfg-br-ex ]
then
	echo " ERROR: br-ex already configured! Rerunning?"
	exit 1
fi
}

device_primary(){
cat >> /etc/sysconfig/network-scripts/ifcfg-$device << EOF
DEVICE=$device
HWADDR=$hwaddr
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-ex
ONBOOT=yes
EOF
}

device_bridge(){
cat >> /etc/sysconfig/network-scripts/ifcfg-br-ex << EOF
DEVICE=br-ex
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=static
IPADDR=$IP
NETMASK=255.255.255.0 
GATEWAY=$gw 
DNS1=$dns1
DNS2=$dns2
DNS3=$dns3
ONBOOT=yes
EOF
}

backup(){
mv /etc/sysconfig/network-scripts/ifcfg-$device /root/ifcfg-$device
}

ovs(){ #open vswitch
ovs-vsctl add-port br-ex $device; service network restart
}

 ###MAIN
device_exist
backup
device_primary
device_bridge
ovs
public