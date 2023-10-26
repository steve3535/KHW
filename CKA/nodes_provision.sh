#!/bin/bash
cls1cp1=192.168.122.10
cls1n1=192.168.122.11
cls1n2=192.168.122.12
cls2cp1=192.168.122.20
cls2n1=192.168.122.21
cls3cp1=192.168.122.30
cls3n1=192.168.122.31
cp ~/virtinstall-test/network-config.yaml netcfg

echo "building base image ..."
cp lunar-server-cloudimg-amd64-disk-kvm.img base-kvm.img
qemu-img resize base-kvm.img 20G
sudo virt-customize -a base-kvm.img \
 --root-password password:123456 \
 --upload network-config.yaml:/etc/netplan/00-config.yaml \
 --upload sudo-k8s:/etc/sudoers.d/ \
 --run-command 'netplan apply' \
 --run-command "ssh-keygen -A;systemctl enable ssh;systemctl start ssh" \
 --run-command "useradd -m k8s -s /bin/bash;chown root.root /etc/sudoers.d/sudo-k8s;chmod 0440 /etc/sudoers.d/sudo-k8s" \
 --ssh-inject k8s:file:/home/steve/.ssh/id_rsa.pub
virt-install --name node --os-variant ubuntu23.04 --vcpus 1 -r 2048 --import --disk path=base-kvm.img,bus=virtio --graphics none -w network=default,model=virtio --noautoconsole
sleep 5
virsh destroy node

echo "spinning cluster-1 ..."
id="cluster1"
virt-clone -o node -n "${id}-controlplane1" --file "./${id}-controlplane1.img"
virsh metadata "${id}-controlplane1" --uri qemu:///system --key label --set "<label>${id}</label>"
virsh start "${id}-controlplane1"

virt-clone -o node -n "${id}-node1" --file "${id}-node1.img"
virsh metadata "${id}-node1" --uri qemu:///system --key label --set "<label>${id}</label>"
sed -i "s/$cls1cp1/$cls1n1/g" network-config.yaml
sudo virt-customize -a "./${id}-node1.img" -upload network-config.yaml:/etc/netplan/00-config.yaml --run-command 'netplan apply'
virsh start "${id}-node1"
cp netcfg network-config.yaml

virt-clone -o node -n "${id}-node2" --file "./${id}-node2.img"
virsh metadata "${id}-node2" --uri qemu:///system --key label --set "<label>${id}</label>"
sed -i "s/$cls1cp1/$cls1n2/g" network-config.yaml
sudo virt-customize -a "./${id}-node2.img" -upload network-config.yaml:/etc/netplan/00-config.yaml --run-command 'netplan apply'
virsh start "${id}-node2"
cp netcfg network-config.yaml

echo "spinning cluster2 ..."
id="cluster2"

virt-clone -o node -n "${id}-controlplane1" --file "./${id}-controlplane1.img"
virsh metadata "${id}-controlplane1" --uri qemu:///system --key label --set "<label>${id}</label>"
sed -i "s/$cls1cp1/$cls2cp1/g" network-config.yaml
sudo virt-customize -a "./${id}-controlplane1.img" -upload network-config.yaml:/etc/netplan/00-config.yaml --run-command 'netplan apply'
virsh start "${id}-controlplane1"
cp netcfg network-config.yaml

virt-clone -o node -n "${id}-node1" --file "./${id}-node1.img"
virsh metadata "${id}-node1" --uri qemu:///system --key label --set "<label>${id}</label>"
sed -i "s/$cls1cp1/$cls2n1/g" network-config.yaml
sudo virt-customize -a "./${id}-node1.img" -upload network-config.yaml:/etc/netplan/00-config.yaml --run-command 'netplan apply'
virsh start "${id}-node1"
cp netcfg network-config.yaml

echo "spinning cluster3 ..."
id="cluster3"
virt-clone -o node -n "${id}-controlplane1" --file "./${id}-controlplane1.img"
virsh metadata "${id}-controlplane1" --uri qemu:///system --key label --set "<label>${id}</label>"
sed -i "s/$cls1cp1/$cls3cp1/g" network-config.yaml
sudo virt-customize -a "./${id}-controlplane1.img" -upload network-config.yaml:/etc/netplan/00-config.yaml --run-command 'netplan apply'
virsh start "${id}-controlplane1"
cp netcfg network-config.yaml

virt-clone -o node -n "${id}-node1" --file "./${id}-node1.img"
virsh metadata "${id}-node1" --uri qemu:///system --key label --set "<label>${id}</label>"
sed -i "s/$cls1cp1/$cls3n1/g" network-config.yaml
sudo virt-customize -a "./${id}-node1.img" -upload network-config.yaml:/etc/netplan/00-config.yaml --run-command 'netplan apply'
virsh start "${id}-node1"
cp netcfg network-config.yaml

sleep 10

ansible-playbook -e host=cluster1,cluster2,cluster3 set_ip.yml -i inventory

