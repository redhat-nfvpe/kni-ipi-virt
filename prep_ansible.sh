#!/bin/bash

source "common.sh"

#
# Clone openshift-kni/baremetal-deploy Ansible tool if not already present
#

if [[ ! -d baremetal-deploy ]]; then
    printf "\nCloning openshift-kni/baremetal-deploy Ansible tool...\n\n"

    git clone https://github.com/openshift-kni/baremetal-deploy.git
    sed -i "s/remote_user=kni/remote_user=$KNI_USERNAME/" baremetal-deploy/ansible-ipi-install/ansible.cfg
fi

if [[ ! -f "$PULL_SECRET_PATH" ]]; then
    echo "ERROR: $PULL_SECRET_PATH not found!"
    exit 1
fi

#
# Generate inventory hosts file
#

HOSTS_FILE="[all:vars]\n\
build=\"$OCP_SOURCE\"\n\
cache_enabled=True\n\
dir=$CLUSTER_CONFIGS_DIR\n\
baremetal_bridge=$BM_BRIDGE\n\
provisioning_bridge=$PROV_BRIDGE\n\
prov_ip=172.22.0.3\n\
prov_nic=$PROV_INTF\n\
masters_prov_nic=enp1s0\n\
pub_nic=$BM_INTF\n\
version=\"$OCP_VERSION\"\n\
\n\
domain=\"$CLUSTER_DOMAIN\"\n\
cluster=\"$CLUSTER_NAME\"\n\
extcidrnet=\"$BM_CIDR\"\n\
dnsvip=\"$DNS_VIP\"\n\
hardware_profile=libvirt\n\
numworkers=\"$NUM_WORKERS\"\n\
nummasters=\"$NUM_MASTERS\"\n\
pullsecret='$(cat "$PULL_SECRET_PATH")'\n"

HOSTS_FILE="$HOSTS_FILE\n[masters]\n"

for i in $(seq 0 $((NUM_MASTERS - 1))); do
    HOSTS_FILE="${HOSTS_FILE}master-$i name=master-$i role=master ipmi_user=ADMIN ipmi_password=ADMIN ipmi_address=$BM_GW_IP ipmi_port=624$i provision_mac=52:54:00:82:68:4$i\n"
done

HOSTS_FILE="$HOSTS_FILE\n[workers]\n"

for i in $(seq 0 $((NUM_WORKERS - 1))); do
    HOSTS_FILE="${HOSTS_FILE}worker-$i name=worker-$i role=worker ipmi_user=ADMIN ipmi_password=ADMIN ipmi_address=$BM_GW_IP ipmi_port=625$i provision_mac=52:54:00:82:68:5$i\n"
done

HOSTS_FILE="$HOSTS_FILE\n[provisioner]\n\
provisioner.$CLUSTER_NAME.$CLUSTER_DOMAIN ansible_connection=local\n"

if [[ "$CREATE_LOCAL_REG" == "true" ]]; then
HOSTS_FILE="$HOSTS_FILE\n[registry_host]\n\
provisioner.$CLUSTER_NAME.$CLUSTER_DOMAIN ansible_connection=local\n"

HOSTS_FILE="$HOSTS_FILE\n[registry_host:vars]\n\
cert_country=US\n\
cert_state=MA\n\
cert_locality=Westford\n\
cert_organization=Red Hat\n\
cert_organizational_unit=CTO Networking\n\
registry_dir=$PROJECT_DIR/registry\n"
fi

echo -e "$HOSTS_FILE" > baremetal-deploy/ansible-ipi-install/inventory/hosts

# HACK: Workaround for issue https://github.com/openshift-kni/baremetal-deploy/issues/508
# in the baremetal Ansible installer
sed -i 's#pullsecret_file: "{{ ansible_user_dir }}/clusterconfigs/pull-secret.txt"#pullsecret_file: "{{ dir }}/pull-secret.txt"#g' baremetal-deploy/ansible-ipi-install/roles/installer/vars/main.yml

SKIP_TAGS=""

if [[ -z "$PROV_INTF" ]] || [[ -z "$BM_INTF" ]]; then
  SKIP_TAGS="--skip-tags=network"
fi

ansible-playbook -i baremetal-deploy/ansible-ipi-install/inventory/hosts baremetal-deploy/ansible-ipi-install/playbook.yml "$SKIP_TAGS"
