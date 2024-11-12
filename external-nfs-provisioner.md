* check:
  `helm list -A`
* Add the repo:  
  `helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/`
* Install:  
  `helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=192.168.128.170 --set nfs.path=/k8s/nfs --set storageClass.name=nfs-client -n nfs-provisioner --create-namespace`

  
