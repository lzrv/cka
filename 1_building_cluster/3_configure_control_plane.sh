#!/bin/bash

# initialize the cluster
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.24.4

# Setup kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes

# install Calico Networking
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# print cluster join command
kubeadm token create --print-join-command
