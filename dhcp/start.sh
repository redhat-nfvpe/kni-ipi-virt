#!/bin/bash

# shellcheck disable=SC1091
source "common.sh"

"$PROJECT_DIR"/dhcp/stop.sh

OUTPUT_DIR="$PROJECT_DIR/dhcp/generated"

CONTAINER_NAME="ipi-dnsmasq-bm"

mkdir -p "$OUTPUT_DIR"/bm/etc/dnsmasq.d
mkdir -p "$OUTPUT_DIR"/bm/var/run
 
envsubst < "$PROJECT_DIR/dhcp/dnsmasq.conf.tmpl" > "${OUTPUT_DIR}"/bm/etc/dnsmasq.d/dnsmasq.conf

BM_MAC="$(ip l show "$BM_INTF" | grep "link/ether" | awk {'print $2'})"
DNSMASQ_HOSTS="$BM_MAC,$BM_GW_IP,provisioner.$CLUSTER_NAME.$CLUSTER_DOMAIN"

for i in $(seq 0 $((NUM_MASTERS - 1))); do
    DNSMASQ_HOSTS="$DNSMASQ_HOSTS\n$MASTER_BM_MAC_PREFIX$i,10.0.1.12$i,$CLUSTER_NAME-master-$i.$CLUSTER_NAME.$CLUSTER_DOMAIN"
done

for i in $(seq 0 $((NUM_WORKERS - 1))); do
    DNSMASQ_HOSTS="$DNSMASQ_HOSTS\n$WORKER_BM_MAC_PREFIX$i,10.0.1.13$i,$CLUSTER_NAME-worker-$i.$CLUSTER_NAME.$CLUSTER_DOMAIN"
done

echo -e "$DNSMASQ_HOSTS" > "${OUTPUT_DIR}"/bm/etc/dnsmasq.d/dnsmasq.hostsfile

CONTAINER_NAME="ipi-dnsmasq-bm"
CONTAINER_IMAGE="quay.io/poseidon/dnsmasq"

sudo podman run -d --name "$CONTAINER_NAME" --net=host \
            -v "$OUTPUT_DIR/bm/var/run:/var/run/dnsmasq:Z" \
            -v "$OUTPUT_DIR/bm/etc/dnsmasq.d:/etc/dnsmasq.d:Z" \
            -p 67:67/udp -p 69:69/udp \
            --expose=69/udp --expose=67/udp --cap-add=NET_ADMIN "$CONTAINER_IMAGE" \
            --conf-file=/etc/dnsmasq.d/dnsmasq.conf -u root -d -q