## RHEL
* tested on Oopta (rhel 8.8)
* setup proxy
  0. prereqs (to avoid ssl errors due to lack of bumping or ssl options in the squid proxy)
     * add FQDN of the proxy in /etc/hosts  
     * add CA of the organization to the server: `cp /tmp/lalux.pem /etc/pki/tls/ca-certs/sources/anchors && update-ca-trust`    
  1. rhsm (eventually)
     set proxy_hostname and proxy_port in /etc/rhsm/rhsm.conf   
  3. yum (eventually)
     put proxy=http://proxy_ip:proxy_port in repos that need it  
  5. general (for wget for e.g.)  
     export https_proxy=proxy_ip:proxy_port  
* subscribe the host  
* subscribe to EPEL  
  `wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm [--no-check-certificate]`  
  `dnf -y localinstall epel-release-latest-8.noarch.rpm`
* Download and install a container runtime (containerd)
  `export https_proxy=172.22.108.7:80; wget https://github.com/containerd/containerd/releases/download/v1.7.7/containerd-1.7.7-linux-amd64.tar.gz`
  `sudo -E wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -O /etc/systemd/system/containerd.service`
  `systemctl daemon-reload && systemctl enable --now containerd`
* Download and install low level container engine (runc)
  * `wget https://github.com/opencontainers/runc/releases/download/v1.1.9/runc.amd64`
  * `sudo install -m 755 runc.amd64 /usr/local/sbin/runc`
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
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
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
* Fix the huge proxy problem that will happen upon **kubeadm init**
  
  >systemctl set-environment https_proxy=lu726.lalux.local:80  
  >systemctl set-environment no_proxy=127.0.0.1,200.1.1.53,10.96.0.1,10.4.0.1  
  >systemctl show-environment  
  >systemctl restart container  
  
* 
    
