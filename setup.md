## Prereqs  
* setup DNS, authoritative for the k8s zone - use bind named for e.g.
  * Otherwise, use fixed IP addresses and populate each node's /etc/hosts 
* OS tested: rhel 8.x, rocky 9.x 
* *Restricted environments*:
  * Install the CA of your org in each of the nodes:  
    `scp lalux.pem /etc/pki/tls/ca-certs/sources/anchors && update-ca-trust`
    
## RHEL (as root unless otherwise specified)
* disable swap
  1. `swapoff -a`
  2. comment the swap line in /etc/fstab  
* disable firewalld  
  `systemctl disable --now firewalld`  
* load required kernel modules and enable forwarding    
  >start with modules loading because of sysctl rules depend on br_netfilter module (*bridge*)  
  ```bash
  cat EOF <</etc/modules-load.d/k8s.conf
  overlay
  br_netfilter
  EOF
  ```   
  reboot and check effectiveness with:  
  `lsmod | grep -E 'netfilter|overlay'`  

  Add these lines to /etc/sysctl.d/99-xxx.conf:
  >net.bridge.bridge-nf-call-iptables  = 1  
  net.bridge.bridge-nf-call-ip6tables = 1  
  net.ipv4.ip_forward                 = 1  
  
  * *Restricted environments:* setup proxy at the OS level  
  ```bash
  cat EOF <</etc/environment
  HTTPS_PROXY=http://172.22.108.7:80
  HTTP_PROXY=http://172.22.108.7:80
  NO_PROXY=10.0.0.0/8,192.168.0.0/16,127.0.0.1,172.16.0.0/16,172.22.108.0/24,172.17.0.0/16,172.22.56.0/24,200.1.1.0/24
  https_proxy=http://172.22.108.7:80
  http_proxy=http://172.22.108.7:80
  no_proxy=10.0.0.0/8,192.168.0.0/16,127.0.0.1,172.16.0.0/16,172.22.108.0/24,172.17.0.0/16,172.22.56.0/24,200.1.1.0/24
  EOF
  ```
  * reboot after setting up environment - i found that sourcing it does not work correctely  
    
* rhsm (eventually)  
  set proxy_hostname and proxy_port in /etc/rhsm/rhsm.conf  
* yum (eventually)  
  put proxy=http://proxy_ip:proxy_port in repos that need it     
* subscribe the host (or mount the ISO of rhel in order to have a repo from which u can install conntrac and iproute-tc) 
* subscribe to EPEL and install iproute-tc   
  ```bash
   wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm [--no-check-certificate] 
   dnf -y localinstall epel-release-latest-8.noarch.rpm
   dnf -y install iproute-tc
  ``` 
* (optional) install other useful packages: vim, bash-completion, wget, nmap-ncat, tar  
* Download and install a container runtime (containerd)  
  ```bash
     wget https://github.com/containerd/containerd/releases/download/v1.7.17/containerd-1.7.17-linux-amd64.tar.gz
     cp bin/containerd* /usr/local/bin/
     cp bin/ctr* /usr/local/bin/  
     wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /etc/systemd/system/containerd.service
     systemctl daemon-reload && systemctl enable --now containerd
  ```  
* Download and install low level container engine (runc)  
  ```bash
  wget https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64 
  sudo install -m 755 runc.amd64 /usr/local/sbin/runc
  ```
  **Notes:**
  > * runc is actually required for containerd to work.
  > * install is used instead of a simple cp, because its more appropriate for binaries (preseerve permissions, create directories if required, etc ..)  
  
* generate containerd config file and set cgroup driver to systemd:  
  ```bash
  mkdir -pv /etc/containerd/ && /usr/local/bin/containerd config default >/etc/containerd/config.toml
  sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  ```  
  * *Restricted environment*:   
     Set proxy for containerd:  
     ```bash
     cat EOF <</etc/systemd/system/containerd.service
     [Unit]
     Description=containerd container runtime
     Documentation=https://containerd.io
     After=network.target local-fs.target

     [Service]
     ExecStartPre=-/sbin/modprobe overlay
     ExecStart=/usr/local/bin/containerd
     Environment="HTTP_PROXY=http://172.22.108.7:80"
     Environment="HTTPS_PROXY=http://172.22.108.7:80"
     Environment="NO_PROXY=10.0.0.0/8,192.168.0.0/16,127.0.0.1,172.16.0.0/16,172.22.56.0/24,172.17.0.0/16,200.1.1.0/24"
     Type=notify
     ...
     ...
     [Install]
     WantedBy=multi-user.target
     ```  
  `systemctl daemon-reload && systemctl restart containerd`
  
* Setup minimum CNI plugins
  this step is capital.   
  `mkdir -pv /opt/cni/bin`  
  `wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz`  
  `tar Cxzvf /opt/cni/bin/ cni-plugins-linux-amd64-v1.3.0.tgz`  
  
* Test the CRI
  * pull some image: `sudo -E /usr/local/bin/ctr image pull docker.io/library/alpine:latest`  
  * ` wget https://github.com/containerd/nerdctl/releases/download/v1.6.1/nerdctl-1.6.1-linux-amd64.tar.gz`  
  * `tar Cxzvf /usr/local/bin/ nerdctl-1.6.1-linux-amd64.tar.gz`  
  * `nerdctl run -d --name nginx -p 80:80 nginx:alpine`  

* Download the kubernetes tools: kubeadm, kubectl and kubelet  
```bash
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
proxy=http://proxy_ip:proxy_port
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
```  
`dnf install -y kubeadm kubectl kubelet --disableexcludes=kubernetes`  
 
### KUBEADM  
* Fix the huge proxy problem that will happen upon **kubeadm init** (**OPTIONAL** -- **NO NEEDED ANYMORE**)  
  
  >systemctl set-environment https_proxy=lu726.lalux.local:80  
  >systemctl set-environment no_proxy=127.0.0.1,200.1.1.53,10.96.0.1,10.4.0.1  
  >systemctl show-environment  
  >systemctl restart container  
* enable kubelet
* make sure hostname of master is in /etc/hosts , if not resolvable by DNS  
* iNSTALL CALICO FOR E.G. -- onlz on master --
  `kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml`

### INSTALL HELM
 wget https://get.helm.sh/helm-v3.15.0-rc.2-linux-amd64.tar.gz  
 mv helm/linux-amd64/helm /usr/local/bin/
 
 
    
