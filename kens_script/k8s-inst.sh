#!/bin/bash
#---------------------------------------------
#  Install K8s for Lab
#---------------------------------------------

#---------------------------------------------
#  Do some initial environment prep
#---------------------------------------------

function initprep {
echo 'Disable Firewalld and Selinux'
echo ' '
export IPADDR=`ip address show dev ens192|grep -o -e 'inet [^ ]*'|cut -f2 -d" "|cut -f1 -d"/"`
export NFSDIR=/export/nfs
export HUBVER=2021.10.6
sudo systemctl disable firewalld; sudo systemctl stop firewalld
sudo setenforce 0
echo "set network and swap options"
sudo sysctl net.ipv4.conf.all.forwarding=1
sudo sysctl net.bridge.bridge-nf-call-iptables=1
sudo swapoff -a

echo "make options persistant"
sudo cp /etc/fstab /etc/fstab.`date +%d%m%y%H%M%S`
sudo sed -i '/ swap /s/^/#/' /etc/fstab

sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

#sudo cp /etc/modules-load.d/containerd.conf /etc/modules-load.d/containerd.conf.`date +%d%m%y%H%M%S`
#sudo cat << EOF > /etc/modules-load.d/containerd.conf
#overlay
#br_netfilter
#EOF

#sudo cp /etc/sysctl.conf /etc/sysctl.conf.`date +%d%m%y%H%M%S`
#sudo cat << EOF > /etc/sysctl.conf
#net.ipv4.ip_forward = 1
#net.bridge.bridge-nf-call-iptables = 1
#EOF

echo "activate options dynamically"
sudo modprobe overlay
sudo modprobe br_netfilter
sudo sysctl -p

echo "iptables used in cluster network"
sudo iptables -P FORWARD ACCEPT
sudo iptables --flush
sudo iptables -tnat --flush

#sudo yum install -y yum-utils wget git zip unzip 
}

#---------------------------------------------
#  Define Storage 
#---------------------------------------------

#function storeprep {
#
#}

#---------------------------------------------
#  Install Docker
#---------------------------------------------

function dockerinst {
echo 'This will install docker'
read -p 'Do you want to continue (y/n)?  ' cont
if [ $cont = y ]; then

sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null 2>&1
sudo yum install -y docker-ce-19.03.14-3.el7 docker-ce-cli-19.03.14-3.el7 > /dev/null 2>&1
sudo cp /usr/lib/systemd/system/docker.service /usr/lib/systemd/system/docker.service.`date +%d%m%y%H%M%S`
sudo sed -i 's#ExecStart=/usr/bin/dockerd#ExecStart=/usr/bin/dockerd --exec-opt native.cgroupdriver=systemd#g' /usr/lib/systemd/system/docker.service

# set docker options
#sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.`date +%d%m%y%H%M%S`
#sudo mkdir /etc/docker
#sudo cat <<EOF > /etc/docker/daemon.json
# {
#  "data-root": "/export",
#  "storage-driver": "overlay"
#}
#EOF

sudo systemctl start docker; sudo systemctl enable docker

else 
  return 0
fi  
}

#---------------------------------------------
#  Install Kubernetes
#---------------------------------------------

function k8sinst {
echo "installing kubernnetes"
sudo bash -c 'cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
EOF'

sudo yum install -y kubeadm-1.20.15-0 kubelet-1.20.15-0 kubectl-1.20.15-0
sudo systemctl enable kubelet

echo "initializing kubernetes"
sudo cp /etc/sysconfig/kubelet /etc/sysconfig/kubelet.`date +%d%m%y%H%M%S`
sudo sed -i 's#KUBELET_EXTRA_ARGS=#KUBELET_EXTRA_ARGS=\"--runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice\"#g' /etc/sysconfig/kubelet
sudo kubeadm config images pull
sudo kubeadm init --apiserver-advertise-address=$IPADDR --pod-network-cidr=10.244.0.0/16

echo 'Did Kubernetes initialize?'
read -p 'Do you want to continue (y/n)?  ' cont
if [ $cont = y ]; then

mkdir -p $HOME/.kube
sudo \cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

#-- remove taint to allow cluster master to run containers
kubectl taint nodes --all node-role.kubernetes.io/master-

else
  return 0
fi

}

#---------------------------------------------
#  Dynamic Provisioner
#---------------------------------------------

# removal steps for Longhorn
# https://longhorn.io/docs/1.0.0/deploy/uninstall/

function longhorn {
sudo mkdir -p /export/longview
sudo chmod 777 /export/longview
sudo yum install -y iscsi-initiator-utils
wget https://raw.githubusercontent.com/longhorn/longhorn/v1.2.4/deploy/longhorn.yaml
sed -i 's/default-data-path:/default-data-path: \/data\/longhorn/' longhorn.yaml
sed -i 's/numberOfReplicas: "3"/numberOfReplicas: "1"/' longhorn.yaml

kubectl create -f longhorn.yaml

kubectl patch storageclass standard -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass longview -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
}

function provisioner {
echo "installing nfs-provisioner"
sudo mkdir -p $NFSDIR
sudo yum install -y nfs-utils
kubectl create -f nfs-provisioner.yaml

#sed -i s/master/`hostname`/ 1-pv.yaml
#sed -i 's/export/export\/nfs/' 1-pv.yaml

#kubectl apply -f 1-pv.yaml
#kubectl apply -f 2-pvc.yaml
#kubectl apply -f 3-rbac.yaml
#kubectl apply -f 4-class.yaml
#kubectl apply -f 5-deploy.yaml
}

#---------------------------------------------
#  synopsysctl
#---------------------------------------------

function synopctl {
echo "installing Black Duck with synopsysctl"
wget https://github.com/blackducksoftware/synopsysctl/releases/download/v3.0.1/synopsysctl-linux-amd64-3.0.1.tar.gz  
sudo tar zxf synopsysctl-linux-amd64-3.0.1.tar.gz -C /usr/local/bin 

synopsysctl create blackduck native hub --namespace hub --version 2022.2.1 --expose-ui NODEPORT --admin-password blackduck --user-password blackduck --persistent-storage=true --seal-key blackduckblackduckblackduckblack > blackduck.yaml
kubectl create namespace hub
kubectl create -f blackduck.yaml

}

#---------------------------------------------
#  Helm
#---------------------------------------------

function helmctl {
echo "installing Black Duck with helm"
wget https://get.helm.sh/helm-v3.9.2-linux-amd64.tar.gz
sudo tar zxf helm-v3.9.2-linux-amd64.tar.gz 
sudo \cp linux-amd64/helm /usr/local/bin
sudo \rm -r linux-amd64

helm repo add stable https://charts.helm.sh/stable
helm repo add synopsys https://sig-repo.synopsys.com/artifactory/sig-cloudnative
kubectl create namespace hub
sudo sed -i 's/isExternal: true/isExternal: false/' /opt/blackduck/hub-$HUBVER/kubernetes/blackduck/values.yaml
helm install hub synopsys/blackduck --namespace hub -f /opt/blackduck/hub-$HUBVER/kubernetes/blackduck/small.yaml -f /opt/blackduck/hub-$HUBVER/kubernetes/blackduck/values.yaml
}

#---------------------------------------------
#  Ingress Controller
#---------------------------------------------

function ingress {
echo "installing nginx-ingress controller"
#curl https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.2/deploy/static/provider/baremetal/deploy.yaml -o deploy.yaml
#sed -i '/serviceAccountName: ingress-nginx-admission/a\      hostNetwork: true' deploy.yaml

cat << EOF > ingressclass.yaml
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  labels:
    app.kubernetes.io/component: controller 
  name: nginx
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
EOF

cat << EOF > ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blackduck-ingress
  namespace: hub
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/proxy-body-size: 1024m
    nginx.ingress.kubernetes.io/proxy-buffer-size: 8k
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hub-blackduck-webserver
            port:
              number: 443
  ingressClassName: nginx
EOF

kubectl create -f ingressclass.yaml
kubectl create -f deploy.yaml

echo " "
echo "waiting for ready"
sleep 30
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

echo "waiting for endpoint ready"
kubectl wait --namespace hub \
  --for=condition=ready pod \
  --selector=component=webserver \
  --timeout=600s

kubectl create -f ingress.yaml
}

#---------------------------------------------
#  Install Selection
#---------------------------------------------

case $1  in
    synopsysctl)
        initprep
        dockerinst
    	k8sinst
	provisioner
	synopctl
        ingress
	;;

    helm)
        initprep
        dockerinst
        k8sinst
        provisioner
        helmctl
        ingress
        ;;
    destroy)
        sudo kubeadm reset -f
        sudo yum remove -y `yum list installed | cut -d " " -f 1  | grep kube`
        sudo iptables -P FORWARD ACCEPT
        sudo iptables --flush
        sudo iptables -tnat --flush
        ;;
    *)
	echo "useage: bdinst.sh option"
	echo "option must be synopsysctl or helm"
	;;
esac
