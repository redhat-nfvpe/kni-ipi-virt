
all: build
clean:
	./vms/clean-vms.sh
	./dhcp/stop.sh
	./dns/stop.sh
build:
	./prep_host.sh
	./iptables/gen_iptables.sh
	./dhcp/start.sh
	./dns/start.sh
	./vms/prov-vms.sh
	./prep_ansible.sh
