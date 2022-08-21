#!/bin/bash

#create ns
kubectl create namespace dev
kubectl create ns dev2

#list ns
kubectl get ns
kubectl get namespace

#get pods across all ns
kubectl get pods --all-namespaces
