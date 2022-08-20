#!/bin/bash

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

# Install containerd
sudo apt-get update && sudo apt-get install -y containerd

# Create default configuration file for containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Restart containerd to pick new config and check status
sudo systemctl restart containerd
echo "Containerd is $(systemctl is-active containerd)"

# Disable swap
sudo swapoff -a

# Install dependency packages
sudo apt-get update && sudo apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# Add Kubernetes to repository list
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://packages.cloud.google.com/apt/ kubernetes-xenial main
EOF

# Update package listings
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Turn off automatic updates
sudo apt-mark hold kubelet kubeadm kubectl

# Check versions
kubelet --version
kubeadm version
kubectl version
