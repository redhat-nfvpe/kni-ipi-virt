#!/bin/bash

# remove certain problematic REJECT rules
REJECT_RULE=$(sudo iptables -S | grep "INPUT -j REJECT --reject-with icmp-host-prohibited")

if [[ -n "$REJECT_RULE" ]]; then
    sudo iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
fi

REJECT_RULE2=$(sudo iptables -S | grep "FORWARD -j REJECT --reject-with icmp-host-prohibited")

if [[ -n "$REJECT_RULE2" ]]; then
    sudo iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited
fi