#!/bin/bash

### BEGIN variables that MUST be changed ###
export EXT_DNS_IP="10.11.5.19" # DNS server to forward non-cluster-resolvable DNS requests
export EXT_INTF="eno1" # External interface used in NAT / masquerade / DNS fowarding
### END variables that MUST be changed ###

### BEGIN variables that can optionally be changed ###
export BM_INTF="" # NIC used for baremetal network, if external nodes (outside the prov host) will be later added
export CLUSTER_NAME="test"
export CLUSTER_DOMAIN="ipi.testing"
export CREATE_LOCAL_REG="true" # Whether to create and use an "offline" container image registry
export DHCP_BM_MACS="" # Override auto-generated dnsmasq hostfile MACs for the baremetal network.  List MACs like so: <master0>,..,<masterN>,<worker0>,..,<workerN>
export KNI_USERNAME="$(whoami)" # Non-root user
export CLUSTER_CONFIGS_DIR="/home/$KNI_USERNAME/clusterconfigs" # Where to place cluster configs for deployment
export LIBVIRT_STORAGE_POOL="default" # Storage pool used for VM disk backends
export MASTER_CPUS=4 # Number of vCPUs to allocate to master VMs
export MASTER_MEM=16384 # Amount of memory to allocate to master VMs
export NUM_MASTERS=1 # Number of masters to deploy in the cluster
export NUM_WORKERS=2 # Number of workers to deploy in the cluster
export OCP_SOURCE="ga" # Whether to use GA or development builds of OpenShift (use "ga" or "dev")
export OCP_VERSION="latest-4.3" # Which OpenShift version to install (see "version" variable discussed here: https://openshift-kni.github.io/baremetal-deploy/latest/Ansible%20Playbook%20Install.html#ansible-playbook-modifying-the-inventoryhosts-file)
export PROJECT_DIR="/home/$KNI_USERNAME/kni-ipi-virt" # Where does this repo live locally?
export PROV_INTF="eno2" # NIC used for provisioning network,, if external nodes (outside the prov host) will be later added
export PULL_SECRET_PATH="/home/$KNI_USERNAME/pull-secret.txt" # Path to your OpenShift pull secret
export WORKER_CPUS=4 # Number of vCPUs to allocate to worker VMs
export WORKER_MEM=16384 # Amount of memory to allocate to worker VMs
### END variables that can optionally be changed ###

### BEGIN variables that can usually be left alone ###
export API_VIP="10.0.1.4"
export BM_BRIDGE="baremetal"
export BM_CIDR="10.0.1.0/24"
export BM_GW_IP="10.0.1.2"
export DNS_IP="$BM_GW_IP"
export DNS_VIP="10.0.1.3"
export INGRESS_VIP="10.0.1.5"
export MASTER_BM_MAC_PREFIX="52:54:00:82:69:4"
export PROV_BRIDGE="provisioning"
export WORKER_BM_MAC_PREFIX="52:54:00:82:69:5"
### END variables that can usually be left alone ###
