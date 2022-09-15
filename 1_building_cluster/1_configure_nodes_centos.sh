#!/bin/bash
# These steps have to be performed on contol plane and worker nodes

#---------------------------------------------
#  initial environment prep
#---------------------------------------------

function initprep {

#disable firewall and SELinux
echo 'Disable Firewalld and Selinux'
echo ' '
sudo systemctl stop firewalld.service; sudo systemctl disable firewalld.service
sudo setenforce 0
sudo sed -i 's/^ *SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

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

# Apply new settings
sudo sysctl --system

# disable swap
sudo swapoff -a
}

#---------------------------------------------
#  Install Containerd
#---------------------------------------------

function containerd_inst { 
# (optional) Have user confirm installation
# echo 'This will install Containerd and additional tools'
# read -p 'Do you want to continue (y/n)?  ' cont
# if [ $cont = y ]; then

# install additional pkgs

sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# add docker repo

sudo yum-config-manager \
--add-repo \
https://download.docker.com/linux/centos/docker-ce.repo

# Check out the latest version and install
# yum list containerd --showduplicates | sort -r
sudo yum update && sudo yum install containerd -y

}

#---------------------------------------------
# Configure Containerd 
#---------------------------------------------

function contd_config {

# Generate default containerd configuration and save to the newly created
# default file 
sudo containerd config default | sudo tee /etc/containerd/config.toml

# CONFIGURE CONTAINERD
# Modify cgroups to systemd
sudo sed -i 's#SystemdCgroup=false#SystemdCgroup=true#' /etc/containerd/config.toml

# Set snapshotter to native
sudo sed -i -e 's/snapshotter = \"overlayfs\"/snapshotter = \"native\"/g' /etc/containerd/config.toml

# reload configurations and restart the service
sudo systemctl daemon-reload
sudo systemctl restart containerd

}

#---------------------------------------------
#  (optional) Install CRICTL
#---------------------------------------------

function crictl_install {

# INSTALL CRI CLIENT CRICTL
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.23.0/crictl-v1.23.0-linux-amd64.tar.gz
tar zxvf crictl-v1.23.0-linux-amd64.tar.gz -C /usr/local/bin

cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Verify that it is available
# crictl pull nginx:alpine
# crictl images
# crictl rmi nginx:alpine

}

#---------------------------------------------
#  Install Kubernetes
#---------------------------------------------

function k8s_isnt {

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
}

function k8s_setup {

# lock versions to prevent automatic updates
# sudo yum install -y yum-versionlock

sudo systemctl enable kubelet
sudo systemctl start kubelet

# initialize k8s
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.24.0

}

function kubectl_setup {
# Setup kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Check
kubectl get nodes
}

# ENABLE IPVS

# If ipvs is not enabled, iptables will be used for packet forwarding, but the
# efficiency is low, so it is recommended to enable ipvs and use

# cat <<EOF | sudo tee /etc/sysconfig/modules/ipvs.modules
# #!/bin/bash
# modprobe -- ip_vs
# modprobe -- ip_vs_rr
# modprobe -- ip_vs_wrr
# modprobe -- ip_vs_sh
# modprobe -- nf_conntrack_ipv4
# EOF

# load ipvs module
# chmod 755 /etc/sysconfig/modules/ipvs.modules && bash \
# /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e \
# nf_conntrack_ipv4

# Installed the ipset package
# yum install ipset -y
 
# Install the management tool ipvsadm
# yum install ipvsadm -y
