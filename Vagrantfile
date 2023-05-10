# -*- mode: ruby -*-
# vi: set ft=ruby :

CLUSTER_PREFIX = "k8s"
CPUS_NUMBER = 8
CPU_LIMIT = 100
MASTER_NODES = "1"
WORKER_NODES = "2,3"
NFS_NODES = "4"
ETCD_NODES = "1"
NUMBER_OF_NODES = "4"
OS_IMAGE = "ubuntu"
MEMORY_LIMIT_MASTER = 2048
MEMORY_LIMIT_WORKER = 4096
MEMORY_LIMIT_NFS = 1536
BRIDGE_ENABLE = false
BRIDGE_ETH = "eno1"
START_IP = "172.18.8.10"
KUBESPRAY_VERSION = "release-2.21"

UBUNTU_IMAGE = "ubuntu/jammy64"
CENTOS_IMAGE = "generic/centos9s"

def compare_numbers(input_str, input_int)
  numbers = []
  unless input_str.nil? || input_str.empty?
    input_str.split(',').each do |part|
      if part.include?(':')
        start, last = part.split(':')
        numbers += (start.to_i..last.to_i).to_a
      elsif part.include?('-')
        start, last = part.split('-')
        numbers += (start.to_i..last.to_i).to_a
      else
        numbers << part.to_i
      end
    end
  end
  numbers.include?(input_int)
end

def increment_ip(start_ip, step)
  octets = start_ip.split('.').map(&:to_i)
  carry = step
  # loop through the octets in reverse order
  3.downto(0) do |i|
    octets[i] += carry
    carry = octets[i] / 255
    octets[i] %= 255
  end
  # build the new IP address string
  octets.join('.')
end

def get_hosttype(count)
  type=" "
  if compare_numbers("#{MASTER_NODES}", count)
    if type == " " 
      type += " (master"
    else
      type += ",master"
    end
  end
  if compare_numbers("#{WORKER_NODES}", count)
    if type == " "
      type += " (worker"
    else
      type += ",worker"
    end
  end
  if compare_numbers("#{NFS_NODES}", count)
    if type == " " 
      type += " (nfs"
    else
      type += ",nfs"
    end
  end
  if compare_numbers("#{ETCD_NODES}", count)
    if type == " " 
      type += " (etcd"
    else
      type += ",etcd"
    end
  end
  if type == " " 
    type = ""
  else 
    type += ")"
  end
  return type
end

def get_hostmemory(count)
  memory = 0
  if compare_numbers("#{MASTER_NODES}", count)
    memory += MEMORY_LIMIT_MASTER
  end
  if compare_numbers("#{WORKER_NODES}", count)
    memory += MEMORY_LIMIT_WORKER
  end
  if compare_numbers("#{NFS_NODES}", count)
    memory += MEMORY_LIMIT_NFS
  end
  if memory > 0 
    memory += 250
  end
  return memory
end  

def set_vbox(vb, config, count)
  vb.gui = false
  vb.customize ["modifyvm", :id, "--cpuexecutioncap", "#{CPU_LIMIT}"]
  vb.customize ['modifyvm', :id, "--graphicscontroller", "vmsvga"]
  vb.customize ["modifyvm", :id, "--vram", "4"]
  vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  vb.cpus = CPUS_NUMBER
  if get_hostmemory(count) != 0
    vb.memory = get_hostmemory(count)
  end
end

def set_libvirt(lv, config, count)
  lv.nested = true
  lv.volume_cache = "none"
  lv.uri = "qemu+unix:///system"
  lv.cpus = CPUS_NUMBER
  if get_hostmemory(count) != 0
    lv.memory = get_hostmemory(count)
  end
end

def set_hyperv(hv, config, count)
  hv.cpus = CPUS_NUMBER
  if get_hostmemory(count) != 0
    hv.memory = get_hostmemory(count)
  end
end

Vagrant.configure("2") do |config|
  config.vbguest.auto_update = false
  config.vm.provision "file", source: "~/.ssh/id_rsa.pub", destination: "~/.ssh/imported.pub"
  config.vm.provision "file", source: ".ssh/id_rsa", destination: "~/.ssh/id_rsa"
  config.vm.provision "file", source: ".ssh/id_rsa.pub", destination: "~/.ssh/id_rsa.pub"
  (1..NUMBER_OF_NODES.to_i).to_a.reverse.each do |mid|
    name = "#{CLUSTER_PREFIX}-node#{mid}"
    name_full = name + get_hosttype(mid)
    config.vm.define "#{name_full}" do |n|
      n.vm.hostname = "#{name}"
      memory = 
      ip_addr = increment_ip("#{START_IP}",mid-1)
      n.vm.network :private_network, ip: "#{ip_addr}",  auto_config: true
      if BRIDGE_ENABLE && BRIDGE_ETH.to_s != ''
        n.vm.network "public_network", bridge: BRIDGE_ETH
      end
      
      if (OS_IMAGE == "ubuntu") 
        n.vm.box = UBUNTU_IMAGE
      elsif (OS_IMAGE == "centos")
        n.vm.box = CENTOS_IMAGE
      end

      # Configure virtualbox provider
      n.vm.provider :virtualbox do |vb, override|
        vb.name = "#{n.vm.hostname}"
        set_vbox(vb, override, mid)
      end

      # Configure libvirt provider
      n.vm.provider :libvirt do |lv, override|
        lv.host = "#{n.vm.hostname}"
        set_libvirt(lv, override, mid)
      end

      # Configure hyperv provider
      n.vm.provider :hyperv do |hv, override|
        hv.vmname = "#{n.vm.hostname}"
        set_hyperv(hv, override, mid)
      end
      
      n.vm.provision "shell", inline: <<-SHELL
        chmod 400 /home/vagrant/.ssh/id_rsa
        cat /home/vagrant/.ssh/imported.pub >> /home/vagrant/.ssh/authorized_keys
        cat /home/vagrant/.ssh/id_rsa.pub >> /home/vagrant/.ssh/authorized_keys
      SHELL

      if mid == 1
        n.vm.network "forwarded_port", guest: 22, host: 2622, protocol: "tcp"      
        n.vm.network "forwarded_port", guest: 80, host: 80, protocol: "tcp"
        n.vm.network "forwarded_port", guest: 80, host: 80, protocol: "udp"
        n.vm.network "forwarded_port", guest: 443, host: 443, protocol: "tcp"
        n.vm.network "forwarded_port", guest: 443, host: 443, protocol: "udp"
        n.vm.network "forwarded_port", guest: 6443, host: 26443, protocol: "tcp"
        n.vm.network "forwarded_port", guest: 6443, host: 26443, protocol: "udp"
        n.vm.provision "shell", preserve_order: true, inline: <<-SHELL
          echo "Installing python3"
          (apt update; apt install python3 -y) || (yum install python3 -y) || (echo "Unsupported OS, can not install required packages, exiting" && exit 255)
          echo "Generating inventory file"
          wget https://raw.githubusercontent.com/smart-cn/inventory_generator/main/inventory_generator.py
          sudo -u vagrant python3 inventory_generator.py start_ip="#{START_IP}" total="#{NUMBER_OF_NODES}" masters="#{MASTER_NODES}" etcd="#{ETCD_NODES}" workers="#{WORKER_NODES}" nfs="#{NFS_NODES}" file="/home/vagrant/generated-hosts.ini"
          wget https://raw.githubusercontent.com/smart-cn/vagrant_k8s_cluster/master/scripts/all-in-one-provisioner.sh
          sudo -u vagrant bash all-in-one-provisioner.sh
        SHELL
      end
    end
  end
end
