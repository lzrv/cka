#  Install an app into a cluster
#  Install Jenkins
#  https://www.jenkins.io/doc/book/installing/kubernetes/
#
#  1/ create jenkins ns
kubectl create ns jenkins

#  2/ Install helm
wget https://get.helm.sh/helm-v3.9.3-linux-amd64.tar.gz
tar xzvf helm-v3.9.3-linux-amd64.tar.gz
mkdir ~/bin
mv linux-amd64/helm ~/bin
helm version

#  3/ Configure Helm
helm repo add jenkinsci https://charts.jenkins.io
helm repo update
helm search repo jenkinsci

#  4/ Create a persistent volume
wget https://raw.githubusercontent.com/jenkins-infra/jenkins.io/master/content/doc/tutorials/kubernetes/installing-jenkins-on-kubernetes/jenkins-volume.yaml

#  5/ Create a service account
wget https://raw.githubusercontent.com/jenkins-infra/jenkins.io/master/content/doc/tutorials/kubernetes/installing-jenkins-on-kubernetes/jenkins-sa.yaml
kubectl apply -f jenkins-sa.yaml

#  6/ Install Jenkins
#  6.1 
wget https://raw.githubusercontent.com/jenkinsci/helm-charts/main/charts/jenkins/values.yaml
mv values.yaml jenkins-values.yaml
  
#  6.2 Modify jenkins-values.yaml
#  nodePort: 32000
#  storageClass: jenkins-pv
#  serviceAccount:
#    create: false
#    name: jenkins
#    annotations: {}
  
#  6.3 Install chart
chart=jenkinsci/jenkins
helm install jenkins -n jenkins -f jenkins-values.yaml $chart

#  6.4 Get your 'admin' user password by running:
jsonpath="{.data.jenkins-admin-password}"
secret=$(kubectl get secret -n jenkins jenkins -o jsonpath=$jsonpath)
echo $(echo $secret | base64 --decode)

#  6.5 Get the Jenkins URL to visit by running these commands in the same shell:
jsonpath="{.spec.ports[0].nodePort}"
NODE_PORT=$(kubectl get -n jenkins -o jsonpath=$jsonpath services jenkins)
jsonpath="{.items[0].status.addresses[0].address}"
NODE_IP=$(kubectl get nodes -n jenkins -o jsonpath=$jsonpath)
echo http://$NODE_IP:$NODE_PORT/login

#  6.6 check install
kubectl get pods -n jenkins
