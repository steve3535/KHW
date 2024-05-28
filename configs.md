### statefulset for the database  
* main motivation = future setup of postgresql cluster --> need to address each pod individually with the same identity on the network evrytime, need also for each instance to have its own pvc
* in the ss, we use volumelaimTemplate to help reproducing the naming in a clean way for the pvcs
* note that because of allow Expansion set to true, u can change increase the size by setting the new capacity and applying the yaml file
* Q: the storageclass is set to lu651 --> a replica created on kayl will use remote storage ?
* Q: how to make use of worker node affinity ?

### backup/restore 
* for the moment, one of the only imperative: pg_dump and pg_restore installed on master via postgresql package:
  `sudo dnf install postgresql` // NON, car ya pas de port forwarding 
* from the OPM15 server (vsl-dev-idb-001):
  `pg_dump -v -h127.0.0.1 -p 5433 -Fd -f /opt/jboss/iisdb_opm_240516 -j8 -U iisdbadmin -d iisdb_opm`
* transfer to the master on k8s
* first, connect inside the container and create database and schemas:
  `kubectl exec -it postgres-0 -- bash`
  `psql -Uiisdbadmin`
  
  ```
  CREATE DATABASE iisdbtest
  CREATE SCHEMA iisdbtest
  CREATE SCHEMA camunda
  ```
* transfer the dump files inside the db container:
  `kubectl cp /opt/innovas-recette/database/backups/iisdb_opm_240516/ postgres-0:/data/`  
* Restore (inside the container):
  `pg_restore -v -Fd iisdb_opm_240516/ -n iisdbtest -n camunda -d iisdbtest -j8 -Uiisdbadmin`

### Expose the DB
* for the moment, lets forget about ingress controllers: either nginx or traefik
* just create a simple nodeport service
* to address the fact of having to link to individual permanent pod, one should create several services, each pointing to the desired pod , through the use of label selector in the spec
* but for the nodeservice , its not prod friendly : long port numbers, usage of node ips, ...
* better next is loadbalancer type: solution metallb

### MetalLB 
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
kubectl describe validatingwebhookconfigurations.admissionregistration.k8s.io metallb-webhook-configuration
# set failurePolicy of ip addr pool and l2advertisement to Ignore
kubectl edit validatingwebhookconfigurations.admissionregistration.k8s.io metallb-webhook-configuration
kubectl apply -f ipaddr.yaml
```
* note that you can specify a given ip (part of the pool) in the service definition via the annotations.

### Git sidecar  

token developer = 2xV5Hk1WNF1Y6fguD1pN  
account username (developer) = k8s_svc_acc   
!! penser changer ladresse email adossée au svc_Acc  

* aparemmemnt la ligne de cmd git est hyper sensible aux carcteres speciaux: autant eviter
* `kubectl create secret generic git-secrets --from-literal git-username=k8s_svc_acc --from-literal git-password=2xV5Hk1WNF1Y6fguD1pN --from-literal git-host="lu687.lalux.local:8090"`
* 
