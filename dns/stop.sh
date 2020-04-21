#!/bin/bash

CONTAINER_NAME="ipi-coredns"

CONTAINER_EXISTS="$(podman ps -a | grep "$CONTAINER_NAME")"

if [[ -n "$CONTAINER_EXISTS" ]]; then
    podman stop "${CONTAINER_NAME}"
    podman rm "${CONTAINER_NAME}"
fi