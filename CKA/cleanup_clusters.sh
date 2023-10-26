#!/bin/bash
if [ $# -eq 0 ];then
	echo -e "Usage: ./destroy_cluster <id_cluster>\n\te.g. ./destroy_cluster cluster-100\n"
	exit 127
fi

cluster_id=$1

for vm in $(virsh list --all | grep -viE "id|---" | awk '{print $2}' | tr -s "\n")
do
	label=$(virsh metadata $vm --uri qemu:///system --key label 2>/dev/null)
	if [[ $label == "<label>$cluster_id</label>" ]];then
		echo $vm
                virsh destroy $vm; virsh undefine $vm --remove-all-storage
	fi
done
virsh undefine node --remove-all-storage
rm -f ./base-kvm.img
cp ~/virtinstall-test/network-config.yaml .
