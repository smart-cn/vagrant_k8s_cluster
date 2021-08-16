CLUSTER_PREFIX = "k8s"
CPUS_NUMBER = 4
CPU_LIMIT = 90
NUMBER_OF_MASTER_NODES = 1
NUMBER_OF_WORKER_NODES = 2
NUMBER_OF_NFS_NODES = 1
MEMORY_LIMIT_MASTER = 2048
MEMORY_LIMIT_WORKER = 4096
MEMORY_LIMIT_NFS = 1024
OS_IMAGE = "ubuntu"
BRIDGE_ENABLE = false
BRIDGE_ETH = "eno1"
PRIVATE_SUBNET = "172.18.8"
IP_SHIFT = 10
UBUNTU_IMAGE = "generic/ubuntu2004"
CENTOS_IMAGE = "generic/centos7"

def set_vbox(vb, config, name)
  vb.gui = false
  vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{CPU_LIMIT}"]
  vb.customize ['modifyvm', :id, "--graphicscontroller", "vmsvga"]
  vb.customize ["modifyvm", :id, "--vram", "4"]
  vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  if (name == "master"); 
    vb.memory = MEMORY_LIMIT_MASTER + 250
    vb.cpus = CPUS_NUMBER
  end
  if (name == "worker"); 
    vb.memory = MEMORY_LIMIT_WORKER + 250
    vb.cpus = CPUS_NUMBER
  end
  if (name == "nfs"); 
    vb.memory = MEMORY_LIMIT_NFS + 250
    vb.cpus = CPUS_NUMBER
  end
end

def set_libvirt(lv, config, name)
  lv.nested = true
  lv.volume_cache = "none"
  lv.uri = "qemu+unix:///system"
  if (name == "master"); 
    lv.memory = MEMORY_LIMIT_MASTER
    lv.cpus = CPUS_NUMBER
  end
  if (name == "worker"); 
    lv.memory = MEMORY_LIMIT_WORKER
    lv.cpus = CPUS_NUMBER
  end
  if (name == "nfs"); 
    lv.memory = MEMORY_LIMIT_NFS
    lv.cpus = CPUS_NUMBER
  end
end

def set_hyperv(hv, config, name)
  if (name == "master"); 
    hv.memory = MEMORY_LIMIT_MASTER
    hv.cpus = CPUS_NUMBER
  end
  if (name == "worker"); 
    hv.memory = MEMORY_LIMIT_WORKER
    hv.cpus = CPUS_NUMBER
  end
  if (name == "nfs"); 
    hv.memory = MEMORY_LIMIT_NFS
    hv.cpus = CPUS_NUMBER
  end
end

Vagrant.configure("2") do |config|
  config.vm.provider "hyperv"
  config.vm.provider "virtualbox"
  config.vm.provider "libvirt"

  count = IP_SHIFT
  (1..(NUMBER_OF_MASTER_NODES+NUMBER_OF_WORKER_NODES+NUMBER_OF_NFS_NODES)).each do |mid|
    name = (mid <= NUMBER_OF_MASTER_NODES) ? "master" : ((mid <= (NUMBER_OF_MASTER_NODES+NUMBER_OF_WORKER_NODES)) ? "worker" : "nfs")
    id   = (mid <= NUMBER_OF_MASTER_NODES) ? mid : ((mid <= (NUMBER_OF_MASTER_NODES+NUMBER_OF_WORKER_NODES)) ? (mid-NUMBER_OF_MASTER_NODES) : (mid-(NUMBER_OF_MASTER_NODES+NUMBER_OF_WORKER_NODES)))

    config.vm.define "#{CLUSTER_PREFIX}-#{name}-#{id}" do |n|
      n.vm.hostname = "#{CLUSTER_PREFIX}-#{name}-#{id}"
      ip_addr = "#{PRIVATE_SUBNET}.#{count}"
      n.vm.network :private_network, ip: "#{ip_addr}",  auto_config: true
      if BRIDGE_ENABLE && BRIDGE_ETH.to_s != ''
        n.vm.network "public_network", bridge: BRIDGE_ETH
      end
      
      if (OS_IMAGE == "ubuntu") then n.vm.box = UBUNTU_IMAGE; end
      if (OS_IMAGE == "centos") then n.vm.box = CENTOS_IMAGE; end

      # Configure virtualbox provider
      n.vm.provider :virtualbox do |vb, override|
        vb.name = "#{n.vm.hostname}"
        set_vbox(vb, override, name)
      end

      # Configure libvirt provider
      n.vm.provider :libvirt do |lv, override|
        lv.host = "#{n.vm.hostname}"
        set_libvirt(lv, override, name)
      end

      # Configure hyperv provider
      n.vm.provider :hyperv do |hv, override|
        hv.vmname = "#{n.vm.hostname}"
        set_hyperv(hv, override, name)
      end
      
      n.vm.provision "shell", inline: <<-SHELL
        systemctl stop firewalld; systemctl disable firewalld
        sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config    
        systemctl restart sshd.service
      SHELL
      
      count += 1
    end
  end
end