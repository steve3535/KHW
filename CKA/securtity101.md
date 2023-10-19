## CKA / Security 101
### There are 3 facets to consider:
  1. **Access to the API**
  2. **Privileges of the pods/containers in their running environment**
  3. **User management by certificates**
### Access to the API server  

the ETCD db is storing every single thing happening and about to happen in the cluster  
You can then imagine that there should be so many requests to read/write from/to the etcd  
HOWEVER, this is a VERY DANGEROUS AND RESTRICTED ZONE: no one cn access the etcd directly ... there are very few though: for e.g. the API server itself and some backup admin via **etcdctl** to fire **snapshot save/snapshot restore**  
NOW, the vast majority of all other people and components (the mortal common) have to go though the central hub: the API server  
We have two kinds of guys: the humans .. and the processes (pods)    
the humans dt have the traditional username/password but rather *PKI credentials* defined in a config file then used by kubectl   
the apps (processes runnin in pods) use *Service Accounts*  
To achieve the access at a namespace level, the object tools used are: **Role**, **User** or **ServiceAccount** and **RoleBinding** to tie them all  
To achieve the access at a cluster level, the object tools used are: **ClusterRole**, **User** or **ServiceAccount** and **ClusterRoleBinding** to tie them all  


