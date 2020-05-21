#!/bin/bash

source "common.sh"

#
# Check OS
#

printf "\nChecking OS...\n\n"

OS_NAME="$(sudo head -3 /etc/os-release | grep ID | cut -d '"' -f 2)"
OS_VERSION="$(sudo grep "VERSION_ID" /etc/os-release | cut -d '"' -f 2 | cut -d '.' -f 1)"

if [[ ($OS_NAME != "rhel" && $OS_NAME != "centos") || $OS_VERSION != "8" ]]; then
    echo "Only RHEL/CentOS 8 are supported."
    exit 1
fi

if [[ "$OS_NAME" == "rhel" ]]; then
    sudo subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms --enable=rhel-8-for-x86_64-baseos-rpms
fi

#
# Install needed packages
#

printf "\nInstalling prerequisite packages...\n\n"

sudo dnf install -y libvirt python3-pip virt-install ipmitool gcc python3-devel qemu-kvm
sudo pip3 uninstall pyghmi -y
sudo pip3 install virtualbmc dnspython netaddr ansible jmespath pyghmi==1.0.22
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

#
# Create vbmcd service and start it
#

printf "\nCreating vmbcd service...\n\n"

sudo tee "/usr/lib/systemd/system/vbmcd.service" > /dev/null << EOF
[Install]
WantedBy = multi-user.target

[Service]
BlockIOAccounting = True
CPUAccounting = True
ExecReload = /bin/kill -HUP $MAINPID
ExecStart = /usr/local/bin/vbmcd --foreground
Group = root
MemoryAccounting = True
PrivateDevices = False
PrivateNetwork = False
PrivateTmp = False
PrivateUsers = False
Restart = on-failure
RestartSec = 2
Slice = vbmc.slice
TasksAccounting = True
TimeoutSec = 120
Type = simple
User = root

[Unit]
After = libvirtd.service
After = syslog.target
After = network.target
Description = vbmc service
EOF

sudo systemctl daemon-reload
sudo systemctl start vbmcd

#
# Add provisioning and baremetal bridge placeholders
#

printf "\nAdding stand-alone provisioning and baremetal bridges...\n\n"

sudo nmcli con delete "$PROV_INTF"
sudo nmcli con delete "$BM_INTF"
sudo nmcli con delete "bridge-slave-$PROV_INTF"
sudo nmcli con delete "bridge-slave-$BM_INTF"
sudo nmcli con delete "$PROV_BRIDGE"
sudo nmcli con delete "$BM_BRIDGE"
sudo nmcli connection add ifname "$PROV_BRIDGE" type bridge con-name "$PROV_BRIDGE" ip4 172.22.0.1/24
sudo nmcli connection add ifname "$BM_BRIDGE" type bridge con-name "$BM_BRIDGE" ip4 "$BM_GW_IP"/24
sudo nmcli con add type bridge-slave ifname "$PROV_INTF" master "$PROV_BRIDGE"
sudo nmcli con add type bridge-slave ifname "$BM_INTF" master "$BM_BRIDGE"
sudo nmcli con down "$BM_BRIDGE"
sudo nmcli con up "$BM_BRIDGE"
sudo nmcli con down "$PROV_BRIDGE"
sudo nmcli con up "$PROV_BRIDGE"

#
# Add firewalld rules for DNS
#

printf "\nAdding firewalld rules for cluster...\n\n"

sudo systemctl start firewalld
sudo firewall-cmd --add-interface="$BM_BRIDGE" --zone=public --permanent
sudo firewall-cmd --add-interface="$PROV_BRIDGE" --zone=public --permanent
sudo firewall-cmd --zone=public --permanent --add-service=ssh
sudo firewall-cmd --zone=public --permanent --add-service=http
sudo firewall-cmd --zone=public --permanent --add-port=53/tcp 
sudo firewall-cmd --zone=public --permanent --add-port=53/udp 
sudo firewall-cmd --zone=public --permanent --add-port=67/udp 
sudo firewall-cmd --zone=public --permanent --add-port=69/udp 
sudo firewall-cmd --zone=public --permanent --add-port=6443/tcp
sudo firewall-cmd --zone=public --permanent --add-port=8080/tcp 
sudo firewall-cmd --zone=public --permanent --add-port=5000/tcp
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --direct --permanent --add-rule ipv4 nat POSTROUTING 0 -o "$EXT_INTF" -j MASQUERADE
sudo firewall-cmd --direct --permanent --add-rule ipv4 filter FORWARD 0 -i "$BM_BRIDGE" -o "$EXT_INTF" -j ACCEPT 
sudo firewall-cmd --direct --permanent --add-rule ipv4 filter FORWARD 0 -i "$EXT_INTF" -o "$BM_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo systemctl stop firewalld
sudo systemctl start firewalld

#
# Allow lower ports for rootless containers (for DNS and DHCP)
#

printf "\nModifying sysctl to allow lower unprivileged ports for containers...\n\n"

if [[ "$(sudo grep "net.ipv4.ip_unprivileged_port_start=50" /etc/sysctl.conf)" == "" ]]; then
    echo -e "\nnet.ipv4.ip_unprivileged_port_start=50" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi


#
# Remove certain ICMP admin rejects from nftables
#

printf "\nTweaking nftables ICMP-admin-reject rules...\n\n"

FILTER_INPUT_REJECT="$(sudo nft -a list chain inet firewalld filter_INPUT | grep "reject with icmpx type admin-prohibited" | cut -d '#' -f 2 | cut -d ' ' -f 3)"
FILTER_FORWARD_REJECT="$(sudo nft -a list chain inet firewalld filter_FORWARD | grep "reject with icmpx type admin-prohibited" | cut -d '#' -f 2 | cut -d ' ' -f 3)"

if [[ -n "$FILTER_INPUT_REJECT" ]]; then
    sudo nft delete rule inet firewalld filter_INPUT handle "$FILTER_INPUT_REJECT" > /dev/null
fi

if [[ -n "$FILTER_FORWARD_REJECT" ]]; then
    sudo nft delete rule inet firewalld filter_FORWARD handle "$FILTER_FORWARD_REJECT" > /dev/null
fi

#
# Set up NetworkManager DNS overlay
#

printf "\nSetting up NetworkManager DNS overlay...\n\n"

DNSCONF=/etc/NetworkManager/conf.d/openshift.conf
DNSCHANGED=""
if ! [ -f "${DNSCONF}" ]; then
    echo -e "[main]\ndns=dnsmasq" | sudo tee "${DNSCONF}"
    DNSCHANGED=1
fi

DNSMASQCONF=/etc/NetworkManager/dnsmasq.d/openshift.conf
DNSMASQCONF_CONTENT=$(grep "server=/$CLUSTER_DOMAIN/$DNS_IP" ${DNSMASQCONF})

if [ ! -f "${DNSMASQCONF}" ] || [ -z "${DNSMASQCONF_CONTENT}" ]; then
    echo server=/"$CLUSTER_DOMAIN"/"$DNS_IP" | sudo tee "${DNSMASQCONF}"
    DNSCHANGED=1
fi

if [ -n "$DNSCHANGED" ]; then
    sudo systemctl restart NetworkManager
fi
