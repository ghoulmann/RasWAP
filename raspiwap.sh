#!/bin/bash -ex

#Check for Root
ifaces=/etc/network/interfaces
cp ifaces /etc/network/interfaces.bak
LUID=$(id -u)
if [[ $LUID -ne 0 ]]; then
	echo "$0 must be run as root"
	exit 1
fi

if [ ! -f ./ConfigureMe.sh ]; then
	echo "Configuration file not found."
	exit 1
fi

. ConfigureMe.sh

#install function
install ()
{
	apt-get update
	DEBIAN_FRONTEND=noninteractive apt-get -y \
        -o DPkg::Options::=--force-confdef \
        -o DPkg::Options::=--force-confold \
        install $@
}
install iw \
	hostapd \
	dnsmasq \
	bridge-utils \
	wavemon

#configure static IP for WLAN0
echo "iface wlan0 inet static" >> $ifaces
echo "	address $wlanIP" >> $ifaces
echo "	netmask $netmask" >> $ifaces

sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

#configure hostapd.conf
cat > /etc/hostapd/hostapd.conf <<EOF
interface=wlan0
driver=nl80211
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
ssid=$ssid
hw_mode=g
channel=$channel
wpa=2
wpa_passphrase=$pass
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
beacon_int=100
auth_algs=3
wmm_enabled=1
bridge=br0
EOF

#configure dnsmasq
cat > /etc/dnsmasq.conf <<EOF
interface=wlan0
dhcp-range=10.0.0.2,10.0.0.5,255.255.255.0,12h
EOF

#configure bridge
echo "auto br0" >> /etc/network/interfaces
echo "iface br0 inet dhcp" >> /etc/network/interfaces
echo "bridge_ports eth0 wlan0" >> /etc/network/interfaces
echo "pre-up ifconfig eth0 0.0.0.0 up" >> /etc/network/interfaces
echo "pre-up ifconfig wlan0 0.0.0.0 up" >> /etc/network/interfaces
echo "pre-up brctl addbr br0" >> /etc/network/interfaces
echo "pre-up brctl addif br0 eth0" >> /etc/network/intefaces
echo "post-down ifconfig wlan0 0.0.0.0 down" >> /etc/network/interfaces
echo "post-down ifconfig eth0 0.0.0.0 down" >> /etc/network/interfaces
echo "post-down brctl delif br0 eth0" >> /etc/network/interfaces
echo "post-down brctl delbr br0" >> /etc/network/interfaces


#configure services
update-rc.d hostapd defaults
update-rc.d dnsmasq defaults
