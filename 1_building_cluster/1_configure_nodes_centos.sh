#!/bin/bash
# These steps have to be performed on contol plane and worker nodes

#disable firewall
sudo systemctl stop firewalld.service
sudo systemctl disable firewalld.service

# disable SELinux
sudo setenforce 0
sed -i 's/^ *SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# Adjust kernel parameters and modules

# Create configuration file for containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Load modules
sudo modprobe overlay
sudo modprobe br_netfilter

# Set system configurations for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# ENABLE IPVS

# If ipvs is not enabled, iptables will be used for packet forwarding, but the
# efficiency is low, so it is recommended to enable ipvs and use

cat <<EOF | sudo tee /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

# load ipvs module
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash \
/etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e \
nf_conntrack_ipv4

# Installed the ipset package
yum install ipset -y
 
# Install the management tool ipvsadm
yum install ipvsadm -y

# Apply new settings
sudo sysctl --system

# Install containerd(via docker installation)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
# containerd.io 1.6.7(Release 3.1.el7) installed
# docker version 20.10.17

# Generate default containerd configuration and save to the newly created
# default file 
sudo containerd config default | sudo tee /etc/containerd/config.toml

# restart containerd to pick up new config, check status
sudo systemctl restart containerd
sudo systemctl status containerd

# disable swap
sudo swapoff -a

# add k8s repo
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
#repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# install kubelet, kubeadm, and kubectl
sudo yum update -y && sudo yum install -y kubelet-1.24.0 kubeadm-1.24.0 kubectl-1.24.0

# lock versions to prevent automatic updates
sudo yum install -y yum-versionlock

# initialize k8s
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.24.0
