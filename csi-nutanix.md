### Initial Install  
* https://portal.nutanix.com/page/documents/details?targetId=CSI-Volume-Driver-v2_6:CSI-Volume-Driver-v2_6
* install the iscsi-initiator-utils on all worker nodes  
* install eventually the multipathd driver  
* setenforce 0 on workers  
* customize the /etc/iscsi/initiator-name on each worker  
* install the snapshot driver first  
   helm install nutanix-csi-snapshot nutanix/nutanix-csi-snapshot -n ntnx-system --create-namespace  
* install the csi then
   helm install nutanix-csi nutanix/nutanix-csi-storage -n ntnx-system --set volumeClass=true --set prismEndPoint=192.168.3.56 --set username="mk417@lalux.local" --set password="******Shine\$\$" --set defaultStorageClass=volume --set storageContainer=postgres-test
  
### Config
```bash
[localadmin@vsl-tst-master-001 ntnx]$ cat sc_iscsi.yaml
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  annotations:
    meta.helm.sh/release-name: nutanix-csi
    meta.helm.sh/release-namespace: ntnx-system
    storageclass.kubernetes.io/is-default-class: "true"
  creationTimestamp: "2024-05-14T09:45:53Z"
  labels:
    app.kubernetes.io/managed-by: Helm
  name: nutanix-iscsi-storageclass
  resourceVersion: "107373"
  uid: b77e9b75-ca79-42de-86db-667b6264f63d
parameters:
  csi.storage.k8s.io/controller-expand-secret-name: ntnx-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: ntnx-system
  csi.storage.k8s.io/fstype: xfs
  csi.storage.k8s.io/node-publish-secret-name: ntnx-secret
  csi.storage.k8s.io/node-publish-secret-namespace: ntnx-system
  csi.storage.k8s.io/provisioner-secret-name: ntnx-secret
  csi.storage.k8s.io/provisioner-secret-namespace: ntnx-system
  description: nutanix-volume
  isSegmentedIscsiNetwork: "false"
  storageContainer: postgres-test
  storageType: NutanixVolumes
provisioner: csi.nutanix.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
[localadmin@vsl-tst-master-001 ntnx]$ cat sc_lvm.yaml
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
    annotations:
        storageclass.kubernetes.io/is-default-class: "false"
    name: nutanix-lvm-storageclass
parameters:
   csi.storage.k8s.io/provisioner-secret-name: ntnx-secret
   csi.storage.k8s.io/provisioner-secret-namespace: ntnx-system
   csi.storage.k8s.io/node-publish-secret-name: ntnx-secret
   csi.storage.k8s.io/node-publish-secret-namespace: ntnx-system
   csi.storage.k8s.io/controller-expand-secret-name: ntnx-secret
   csi.storage.k8s.io/controller-expand-secret-namespace: ntnx-system
   csi.storage.k8s.io/fstype: xfs
   storageContainer: postgres-test
   storageType: NutanixVolumes
   isLVMVolume: "true"
   numLVMDisks: "4"
   #blockDeviceQueueParams:
   readAhead: none
provisioner: csi.nutanix.com
reclaimPolicy: Delete
```  
### Tests
```bash
[localadmin@vsl-tst-master-001 ntnx]$ cat pvctest2.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
   name: test-pvc
   labels:
     descr: test-iscsi-simple
spec:
   accessModes:
      - ReadWriteOnce
   resources:
      requests:
         storage: 2Gi
   storageClassName: nutanix-iscsi-storageclass2
---
kind: Pod
apiVersion: v1
metadata:
  name: test-pod
  labels:
    descr: test-iscsi-simple
spec:
  containers:
    - name: test
      image: alpine
      command: ["sleep","infinity"]
      volumeMounts:
        - name: iscsivol
          mountPath: /data
  volumes:
    - name: iscsivol
      persistentVolumeClaim:
        claimName: test-pvc

```
### TakeAways 
* no need to create pv it will be dynaéically get created through the pvc claim
* it will then create a volume group in the storage container
* the mounting process will trigger iscsi and iscsid on the worker to start communication with the target
* the enable client external is automatically checked - no need to whitelist any IP
* remember ReadWriteOnce will allow only one node at a time

### issues
* **kayl went down**.
* the storage was fine, pv, pvc were in a goot state
* on the workers, seen broken pipes in the iscsi comm (systemctl status iscsi iscsid)
* on the cluster itself, kubect get events --> show Failedmount state
* i end up delete the pod (forcefully) and as expected the statefulset recreated it and it came back healthy, but it moved it to node02 (leudelange)
* lsscsi can show that the node02 now have the control over the data volume
  
