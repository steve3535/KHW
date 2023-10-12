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
  `wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm --no-check-certificate [--no-check-certificate]`  
  `dnf -y localinstall epel-release-latest-8.noarch.rpm`
