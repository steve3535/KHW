
* tout ce dont a besoin pour se connecter au cluster se trouve dans .kube/config  
* si on copie ce seul fichier vers une machine tierce, ca suffit pour adresser le cluster:  
  `kubectl --kubeconfig /path/to/configfile get node` OU `export KUBECONFIG=./kubeconfigfile` suivi dun `kubectl get no` 
* Que se passe til si on perd ce fichier ? --> on peut le restorer depuis le controlplane depuis /etc/kubernetes/admin.conf   
* une idee est davoir plusierus config files, et pointer sur differents pour se connecter a differents clusters  
* control plane also runs CRI and kubelet (started by OS - via systemd for e.g.)
* the necessary mandatory pods of the master are: apiserver, scheduler, etcd
* theres a diff between container runtime (CRI-O, containerd) and container engines (docker,podman,...)
* on-prem = standalone, cloud = cluster
* kubelet is the guy that manages pods 
* Building a k8s cluster sequence
  * preflight
  * certs gen
  * kubeconfig 
  * kubelet-start
  * pods manifest 1 (scheduler,controllermanager,apiserver)
  * pods manifest 2 (etcd)
  * upload-config
  * upload-certs
  * taint master
  * join token gen
  * kubelet-finalize
  * add-ons: coredns, kubeproxy
* Building a k8s cluster: practice
  * ensure IP forwarding rules  
  * check if br_netfilter and overlay modules are loaded 
  * check if related sysctl parameteres are set  
  * install CRI : containerd or CRI-O
    * containerd/runc -- runc is the low level OCI tool that actually creates container; containerd is the higher level tool that lifecycles the ctrs
      1. get containerd: 
         * `wget https://github.com/containerd/containerd/releases/download/v1.6.24/containerd-1.6.24-linux-amd64.tar.gz`  
         * `tar Cxzvf /usr/local/ containerd-1.6.24-linux-amd64.tar.gz` 
         * clone as well the repo to have the containerd service: `git clone https://github.com/containerd/containerd`    
         * `cp containerd.service /etc/systemd/system/`  
         * `systemctl daemon-reload && systemctl enable --now containerd` 
      2. runc   
         * check if not already present: `runc --version` 
         * containerd can actually sit on top of other OCI: gvisor/kata-containers  
         * to be sure that it is runc by default, search for config.toml of containerd. I ended up with: `containerd config default` and search in the output **runc** --> **plugins."io.containerd.runtime.v1.linux"]*  
         * The default configuration can be generated via containerd config default > /etc/containerd/config.toml  
         * set systemd as the cgroup driver and restart containerd  
           * use systemd instead of cgroupfs because systemd is the init process of the server, otherwise, we'll end up having 2 conflicting views of the available resources; moreover we are using cgroup v2 (`grep cgroup /proc/mounts`)  
         * `wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64`  
         * `install -m 755 runc.adm64 /usr/local/sbin/runc`  
      3. Install CNI plugins  
         ```
         wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
         mkdir -pv /opt/cni/bin 
         tar Cxzvf /opt/cni/bin/ cni-plugins-linux-amd64-v1.3.0.tgz 
         ```

      4. Test the CRI stack  
         * ctr images pull docker.io/library/alpine:latest  
         * ctr images list   
         * ctr run --rm docker.io/library/alpine:latest alpine-test echo 'Hello from alpine !'  
      
      5. check for systemd as cgroup driver
         * for recent versions of runc and on a recent systems, it will normally pick systemd, especially if thats the init of the server, so no need to edit the config.toml of containerd.  
         * to check, one can just `runc --help` and check for the flag --systemd-cgroup  
         * or better:  
           * spark a ctr:  `ctr run -d docker.io/library/alpine alpine-test`  
           * `cat /proc/<pidofctr>/cgroup` --> should have system-slice in its ouput  



      
  * install 
    1. setup container runtimes  
    2. setup kubernetes tools (kubeadm, kubectl, ...)
    3. sudo kubeadm init (only master) (NB: kubeadm is always run as root)
    4. setup the client -- kubeconfig setup -- (otherwise kubectl wont find the apiserver)
    4. install the network plugin (only master)
       * when not installed, kubectl get no --> will show only controler node in NOT READY state, because kubectl get po -n kube-system will show coredns pods in pending state
    5. join the nodes to the cluster: `sudo kubeadm token create --print-join-command`


## DaemonSets

* c un deploiement mais qui va placer une instance de pod sur chaque noeud (sauf le control plane, mais meme celui ci peut acueilir une instance si une toleration est definie)  
* le use case le plus evident: c les agents, comme kube-proxy ou des pod de logs a tourner sur chak neoud par exp  
* c rare dutiliser ca pour des user workloads  
* on peut mimic facilement un daemonset:   
`kubectl create deploy myds --image=nginx --dry-run=client -o yaml > myds.yaml`  
* on aura une structure comme:  
```
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: myds
  labels:
    app: myds
spec:
  selector:
    matchLabels:
      app: myds
  template:
    metadata:
      label:
        app: myds
    spec:
      containers:
      - image: nginx
        name: nginx    
```  
* une observation interessante: questce qui se passe lorske on lance un dameonset avec comme image alpine ou busysbox ?   
  --> on a un carshloopback error des pods parceke le daemonset manager sattend a un demon et une image comme alpine exit normalement immediatement  
  
  
 ## Managing cluster stuff  

 * crictl
 * static pods
 * kubelet
 * cordon & drain


 ## CKA prep
 * quota & limitrange: dt confuse limitrange with resources  
   * quota set boundaries for the total stuff in the ns 
   * limitrange set boundaries for any pods/containers in a ns
   * set resources set boundaries for pods/containers of specific deployment 
   * straight forward examples with: `kubectl create quota -h` and `kubectl set resources -h`
 * Be careful: `kubectl get all -n limited` wont show quotas and limitranges --> `kubectl get quota,limitrange`
 * static pod: just dump the yaml file in **/etc/kubernetes/manifest**
 * remember *journal -u kubelet* and *crictl ps* when troubleshooting an issue on a given node
 * role and rolebinding much more easy with `kubectl create role|rolebinding -h`
 * cest le pod qui tolere le taint, pas linverse
   * on specifie dans le spec du pod, lexact taint qui a ete mis sur le node pour kil le tolere
   * taint et toleration marchent ensemble: `kubectl taint node node-102 type=db:NoSchedule` veut dire que:
     1. node-102 est teinté
     2. aucun pod ne peut tourner sur lui a moins quil n'est la tolerance qui match
   * ici, ne pas perdre de temps avec -h, allez a la doc pour voir la syntax dans yaml de tolerations 
 * networkpolicies can be tricky:
   * always explicitly apply a label to all entities involved
   * if dealing with traffic from namespace to another namespace, ensure namespace is specified in the metadata of the nwp
   * network policies are additives: meaning if a nw denies someth and another one allows it, the traffic will flow
   * ingress: [] means no rules <-> deny all incoming, podSelector: {} means empty <->  all pods
 * la version de k8s est gouverné par l'install de kubeadm 
 * kubeadm config images list --> montre tous les composant clés du contol plane
 * kubeadm init a beaucoup de params (en particulier --pod-network-cidr)
 * kubeadm reset 
 * apt-cache madison kubeadm (verifier toutes les versions available de k8s, a condition bien sur ke le repo existe deja)
 * `sudo apt install -y kubeadm=1.26.8-00 kubelet=1.26.8-00 kubectl=1.26.8-00` si ce nest pas specifié en une ligne, tu vas endup avec dautres versions plus recentes de kubectl ou de kubelet  
 * lerreur de conexion de kubectl a l'API server peut des fois etre du au fait que le current-context nest pas set dans le fichier kubeconfig
 * lister toutes les resources avec `kubectl api-resources`
 * pour fixer le default context, la commande cest: `kubectl --kubeconfig shine.config use-context ...`  
 * Attention au nom de l'objet user dans le kubeconfig: ca doit matcher le username --> sinon on aura unprompt pour le password 
 * souvent je fais lerreur decrire busysbox au lieu de busybox: `kubectl describe` to the rescue !!!
 * WOW ! jai fait ceci: `etcdctl --cacert /etc/kubernetes/pki/ca.crt --cert /etc/kubernetes/pki/etcd/server.crt --key /etc/kubernetes/pki/etcd/server.key --endpoints=localhost:2379 endpoint status`, et ca plantait .. en effet le certif CA est **/etc/kubernetes/pki/etcd/ca.crt** et pas **/etc/kubernetes/pki/ca.crt** (cest crictl logs <hash etcd container> qui ma sauvé)  
 * un provisioner beaucoup plus simple que nfs: **kubernetes.io/no-provisioner**
 * rapple du flow avec storageclass:
   * creer le storageclass (avec eventuellement *allowVolumeExpansion: true*)
   * creer le pv, puis le pvc en referencant le storageclass
 * syntaxe a utiliser pour les scripts dans les pods:  
   ```bash
   args:
   - /bin/sh
   - -c
   - >
     while true;
     do
       ...;
       ...;
     done 
   ```
   * bien preter attention aux ; et a lindentation 
   * metrics server -a bucher-
      `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`  
     * ensuite editer le deploy (c dans kube-system) et ajouter en argument du container: **--kubelet-insecure-tls**  
    
  
  
  
  
  
