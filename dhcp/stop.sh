#!/bin/bash

CONTAINER_NAME="ipi-dnsmasq-bm"

CONTAINER_EXISTS="$(sudo podman ps -a | grep "$CONTAINER_NAME")"

if [[ -n "$CONTAINER_EXISTS" ]]; then
    sudo podman stop "${CONTAINER_NAME}"
    sudo podman rm "${CONTAINER_NAME}"
fi