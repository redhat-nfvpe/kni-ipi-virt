#!/bin/bash

source "common.sh"
source "$PROJECT_DIR/vms/vbmc-funcs.sh"

MASTER_PROV_MAC_PREFIX="52:54:00:82:68:4"

WORKER_PROV_MAC_PREFIX="52:54:00:82:68:5"

MASTER_VBMC_PORT_PREFIX=624
WORKER_VBMC_PORT_PREFIX=625

(
    "$PROJECT_DIR"/vms/clean-vms.sh
) || exit 1

for i in $(seq 0 $((NUM_MASTERS - 1))); do
    name="$CLUSTER_NAME-master-$i"

    sudo virt-install --ram $MASTER_MEM --vcpus $MASTER_CPUS --os-variant rhel8.0 --cpu host-passthrough --disk size=60,pool=$LIBVIRT_STORAGE_POOL,device=disk,bus=virtio,format=qcow2 --import --noautoconsole --vnc --network=bridge:provisioning,mac="$MASTER_PROV_MAC_PREFIX$i" --network=bridge:baremetal,mac="$MASTER_BM_MAC_PREFIX$i" --name "$name" --os-type=linux --events on_reboot=restart --boot hd,network

    vm_ready=false
    for k in {1..10}; do 
        if [[ -n "$(sudo virsh list | grep $name | grep running)" ]]; then 
            vm_ready=true
            break; 
        else 
            echo "wait $k"; 
            sleep 1; 
        fi;  
    done
    if [ $vm_ready = true ]; then 
        create_vbmc "$name" "$MASTER_VBMC_PORT_PREFIX$i"

        # sudo firewall-cmd --zone=public --add-port=$MASTER_VBMC_PORT_PREFIX$i/udp --permanent
        # sudo firewall-cmd --reload

        sleep 2

        ipmi_output=$(ipmitool -I lanplus -U ADMIN -P ADMIN -H 127.0.0.1 -p "$MASTER_VBMC_PORT_PREFIX$i" power off)

        RETRIES=0

        while [[ "$ipmi_output" != "Chassis Power Control: Down/Off" ]]; do
            if [[ $RETRIES -ge 2 ]]; then
                echo "FAIL: Unable to start $name vBMC!"
                exit 1
            fi

            echo "IPMI failure detected -- trying to start $name vBMC again..."
            vbmc start "$name" > /dev/null 2>&1
            sleep 1
            ipmi_output=$(ipmitool -I lanplus -U ADMIN -P ADMIN -H 127.0.0.1 -p "$MASTER_VBMC_PORT_PREFIX$i" power off)
            RETRIES=$((RETRIES+1))
        done

        echo "$name vBMC started and IPMI command succeeded!"
    fi
done

for i in $(seq 0 $((NUM_WORKERS - 1))); do
    name="$CLUSTER_NAME-worker-$i"

    sudo virt-install --ram $WORKER_MEM --vcpus $WORKER_CPUS --os-variant rhel8.0 --cpu host-passthrough --disk size=60,pool=$LIBVIRT_STORAGE_POOL,device=disk,bus=virtio,format=qcow2 --import --noautoconsole --vnc --network=bridge:provisioning,mac="$WORKER_PROV_MAC_PREFIX$i" --network=bridge:baremetal,mac="$WORKER_BM_MAC_PREFIX$i" --name "$name" --os-type=linux --events on_reboot=restart --boot hd,network

    vm_ready=false
    for k in {1..10}; do 
        if [[ -n "$(sudo virsh list | grep $name | grep running)" ]]; then 
            vm_ready=true
            break; 
        else 
            echo "wait $k"; 
            sleep 1; 
        fi;  
    done
    if [ $vm_ready = true ]; then 
        create_vbmc "$name" "$WORKER_VBMC_PORT_PREFIX$i"

        # sudo firewall-cmd --zone=public --add-port=$WORKER_VBMC_PORT_PREFIX$i/udp --permanent
        # sudo firewall-cmd --reload

        sleep 2

        ipmi_output=$(ipmitool -I lanplus -U ADMIN -P ADMIN -H 127.0.0.1 -p "$WORKER_VBMC_PORT_PREFIX$i" power off)

        RETRIES=0

        while [[ "$ipmi_output" != "Chassis Power Control: Down/Off" ]]; do
            if [[ $RETRIES -ge 2 ]]; then
                echo "FAIL: Unable to start $name vBMC!"
                exit 1
            fi

            echo "IPMI failure detected -- trying to start $name vBMC again..."
            vbmc start "$name" > /dev/null 2>&1
            sleep 1
            ipmi_output=$(ipmitool -I lanplus -U ADMIN -P ADMIN -H 127.0.0.1 -p "$WORKER_VBMC_PORT_PREFIX$i" power off)
            RETRIES=$((RETRIES+1))
        done

        echo "$name vBMC started and IPMI command succeeded!"
    fi
done

# Need to restart firewall to make sure vBMC ports are added there
sudo systemctl restart firewalld

echo "Finished provisioning VMs for \"$CLUSTER_NAME\" cluster"
