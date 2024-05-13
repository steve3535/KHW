## RHEL -tested on Oopta (rhel 8.8)
* ensure a fixed IP address is used and add the hostname along with its ip addr in /etc/hosts (unless DNS reoslution is in place)
* add CA of the organization to the server: `cp /tmp/lalux.pem /etc/pki/tls/ca-certs/sources/anchors && update-ca-trust`
* disable swap
* disable firewalld
* enable forwarding and load required kernel modules  
  start with modules loading because of of the sysctl rules depend on br_netfilter module (*bridge*)  
  ```bash
  [steve@k8s-master ~]$ sudo cat /etc/modules-load.d/k8s.conf
  overlay
  br_netfilter
  [steve@k8s-master ~]$  

  Add these lines to /etc/sysctl.d/99-xxx.conf:  
  net.bridge.bridge-nf-call-iptables  = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  net.ipv4.ip_forward                 = 1
  ```
  remember to set it in /etc/sysctl.d/99-xxx.conf  
* setup proxy at the OS level  
  ```bash
  [steve@k8s-master ~]$ cat /etc/environment
  HTTPS_PROXY=http://172.22.108.7:80
  HTTP_PROXY=http://172.22.108.7:80
  NO_PROXY=10.0.0.0/8,192.168.0.0/16,127.0.0.1,172.16.0.0/16,172.22.108.0/24,172.17.0.0/16,172.22.56.0/24,200.1.1.0/24
  https_proxy=http://172.22.108.7:80
  http_proxy=http://172.22.108.7:80
  no_proxy=10.0.0.0/8,192.168.0.0/16,127.0.0.1,172.16.0.0/16,172.22.108.0/24,172.17.0.0/16,172.22.56.0/24,200.1.1.0/24
  [steve@k8s-master ~]$
  ```
* rhsm (eventually)  
    set proxy_hostname and proxy_port in /etc/rhsm/rhsm.conf
* yum (eventually)  
    put proxy=http://proxy_ip:proxy_port in repos that need it  
* subscribe the host (or mount the ISO of rhel in order to have a repo from which u can install conntrac and iproute-tc) 
* subscribe to EPEL  
  `wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm [--no-check-certificate]`  
  `dnf -y localinstall epel-release-latest-8.noarch.rpm`  
* install packages **iproute-tc** 
  
* Download and install a container runtime (containerd)  
  `wget https://github.com/containerd/containerd/releases/download/v1.7.7/containerd-1.7.7-linux-amd64.tar.gz`  
  `sudo -E wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /etc/systemd/system/containerd.service`  
  `systemctl daemon-reload && systemctl enable --now containerd`  
* Download and install low level container engine (runc)  
  * `wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64`  
  * `sudo install -m 755 runc.amd64 /usr/local/sbin/runc`
* generate containerd config file and set cgroup driver to systemd:  
  `mkdir -pv /etc/containerd/ && /usr/local/bin/containerd config default >/etc/containerd/config.toml`  
  `sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml`
* Set proxy for containerd:  
  ```bash
  [root@k8s-master ~]# cat /etc/systemd/system/containerd.service
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
  [Install]
  WantedBy=multi-user.target

  ```
  `systemctl daemon-reload`  
  `systemctl restart containerd`  
* Setup minimum CNI plugins    
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
* iNSTALL CALICO FOR E.G.
  `kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml`
  
    
