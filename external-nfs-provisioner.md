* check:
  `helm list -A`
* Install:  
  `helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=192.168.128.170 --set nfs.path=/k8s/nfs --set storageClass.name=nfs-client -n nfs-provisioner --create-namespace`

  
