#!/bin/bash

sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --direct --permanent --add-rule ipv4 nat POSTROUTING 0 -o "$EXT_INTF" -j MASQUERADE
sudo firewall-cmd --direct --permanent --add-rule ipv4 filter FORWARD 0 -i "$BM_BRIDGE" -o "$EXT_INTF" -j ACCEPT 
sudo firewall-cmd --direct --permanent --add-rule ipv4 filter FORWARD 0 -i "$EXT_INTF" -o "$BM_BRIDGE" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo systemctl restart firewalld

# remove certain problematic REJECT rules
REJECT_RULE=$(sudo iptables -S | grep "INPUT -j REJECT --reject-with icmp-host-prohibited")

if [[ -n "$REJECT_RULE" ]]; then
    sudo iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
fi

REJECT_RULE2=$(sudo iptables -S | grep "FORWARD -j REJECT --reject-with icmp-host-prohibited")

if [[ -n "$REJECT_RULE2" ]]; then
    sudo iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited
fi