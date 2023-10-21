#!/bin/bash

# Master
## Clone master_template.qcow2

## Modify IP addr with ansible
id="cluster-100"
virt-clone -o master1-template -n "master1-${id}" --file "./master1-${id}.qcow2"
virsh metadata master1-${id} --uri qemu:///system --key label --set "<label>${id}</label>"
virsh start "master1-${id}"
virt-clone -o worker1-template -n "node1-${id}" --file "./node1-${id}.img"
virsh metadata "node1-${id}" --uri qemu:///system --key label --set "<label>${id}</label>"
virsh start "node1-${id}"
virt-clone -o worker2-template -n "node2-${id}" --file "./node2-${id}.img"
virsh metadata "node2-${id}" --uri qemu:///system --key label --set "<label>${id}</label>"
virsh start "node2-${id}"
virt-clone -o worker3-template -n "node3-${id}" --file "./node3-${id}.img"
virsh metadata "node3-${id}" --uri qemu:///system --key label --set "<label>${id}</label>"
virsh start "node3-${id}"
sleep 10
ansible-playbook -e host=cluster-100 set_ip.yml -i inventory
