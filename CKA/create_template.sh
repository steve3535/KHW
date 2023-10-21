#!/bin/bash
#Download full ubuntu 22.04 for control plane
wget -N https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso --no-check-certificate

#Install the control plane
virt-install

#Customize with virt-customize
virt-customize -a master_template.qcow2 --root-passwd password:123456
virt-customize -a master_template.qcow2 --ssh-inject :file:/home/steve/.ssh/id_rsa.pub

#Download cloud images for worker nodes
wget -N https://cloud-images.ubuntu.com/lunar/current/lunar-server-cloudimg-amd64-disk-kvm.img --no-check-certificate 

#Customize with virt-customize
cp lunar-server-cloudimg-amd64-disk-kvm.img worker_template.img
qemu-img resize worker_template.img 20G
virt-customize -a worker_template.img --root-password password:123456
virt-customize -a worker_template.img --ssh-inject :file:/home/steve/.ssh/id_rsa.pub
virt-customize -a worker_template.img --run-command 'dhclient eth0'

#Install worker
virt-install --name worker --os-variant ubuntu23.04 --vcpus 1 -r 3072 --import --disk path=worker_template.img,bus=virtio --graphics none -w network=default,model=virtio --noautoconsole
