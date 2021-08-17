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
echo "Installing required additional packages"
(echo $password | sudo -S apt update && echo $password | sudo -S apt install -y python3-pip git sshpass mc) || (echo $password | sudo -S yum install -y python3-pip git sshpass mc) || (echo "Unsupported OS, can\`t install required packages, exiting" && exit 255)
echo "Cloning Kubespray"
git clone https://github.com/kubernetes-sigs/kubespray.git
cd kubespray
git checkout $(git describe --tags `git rev-list --tags --max-count=1`) -q
echo "Installing required for Kubespray python packages"
echo $password | sudo -S pip3 install -r requirements.txt
export PATH=$PATH:$HOME/.local/bin/
echo "Cloning my Dev. inventory"
git clone https://github.com/smart-cn/kubespray_inventory.git inventory/mycluster
echo "Generating SSH key"
yes y | ssh-keygen -b 4096 -t rsa -N '' -f ~/.ssh/id_rsa
echo "Pushing SSH key to remote all hosts"
grep ansible_host inventory/mycluster/hosts.yaml | awk '{print $2}' | while read ip ; do echo $password | sshpass ssh-copy-id -o StrictHostKeyChecking=no -o LogLevel=QUIET -i ~/.ssh/id_rsa $login@$ip ; done
echo "Deploying cluster using Kubespray and my Dev. inventory"
ansible-playbook -i inventory/mycluster/hosts.yaml -u vagrant -b -v --private-key=~/.ssh/id_rsa cluster.yml -e "ansible_become_password=$password"
mkdir -p ~/.kube/
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
echo $password | sudo -S wget -qO- https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_x86_64.tar.gz | tar zxvf -  -C /tmp/; echo $password | sudo -S mv /tmp/k9s /usr/local/bin
echo "Your Kubernetes cluster is sucesfully deployed and ready to use!"
