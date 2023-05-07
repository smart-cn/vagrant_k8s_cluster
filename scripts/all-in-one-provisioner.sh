#!/bin/bash

echo "Checking current username"
if [ `whoami` != 'vagrant' ]
  then
    read -p 'Enter the login please: ' login
    read -p 'Enter the root password please: ' -s password
    echo
  else
    login='vagrant'
    password='vagrant'
fi
export ANSIBLE_HOST_KEY_CHECKING=false
export PATH=$PATH:$HOME/.local/bin/
echo "Installing required additional packages"
(echo $password | sudo -S apt update && echo $password | sudo -S apt install -y python3-pip) || (echo $password | sudo -S yum install -y python3-pip) || (echo "Unsupported OS, can\`t install required packages, exiting" && exit 255)
echo "Cloning Kubespray"
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout release-2.21
echo "Installing required for Kubespray python packages"
echo $password | sudo -S pip3 install -r requirements.txt
echo "Cloning my Dev. inventory"
git clone https://github.com/smart-cn/kubespray_inventory.git inventory/mycluster
echo "Moving generated hists.ini file to the inventory"
mv -f $HOME/generated-hosts.ini inventory/mycluster/cluster-inventory.ini || echo "Generated inventory not found. Skip adding."
echo "Setuping required additional software"
ansible-playbook inventory/mycluster/init-provisioning.yaml -i inventory/mycluster/cluster-inventory.ini -u vagrant --private-key $HOME/.ssh/id_rsa
echo "Deploying cluster using Kubespray and my Dev. inventory"
ansible-playbook -i cluster-inventory.ini -u vagrant -b -v --private-key=$HOME/.ssh/id_rsa cluster.yml -e "ansible_become_password=$password"
mkdir -p $HOME/.kube/
echo "Copying kubeconfig to homedir"
echo $password | sudo -S cp /root/.kube/config $HOME/.kube/
echo $password | sudo -S chown vagrant:vagrant $HOME/.kube/config
echo "Deploying to the Kubernetes cluster some additional software"
kubectl apply -f inventory/mycluster/nfs-storage-deployments-with-toleration.yaml
kubectl create ns metallb
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -n metallb -f inventory/mycluster/lb-values-virtualbox.yaml
kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e "s/strictARP: false/strictARP: true/" | kubectl apply -f - -n kube-system
kubectl apply -f inventory/mycluster/dashboard_admin_account.yaml
kubectl apply -f inventory/mycluster/dashboard_ingress.yaml
kubectl apply -f inventory/mycluster/hello_world.yaml
echo $password | sudo -S wget -qO- https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar zxvf -  -C /tmp/;echo $password | sudo -S mv /tmp/k9s /usr/local/bin
echo "Your Kubernetes cluster is sucesfully deployed and ready to use!"
