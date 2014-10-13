# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'json'

Vagrant.require_version '>= 1.6.0'
VAGRANTFILE_API_VERSION = '2'
CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), 'config/user-data')

# # Defaults for config options defined in CONFIG
$num_instances = 1
$update_channel = "beta"
$enable_serial_logging = false
$vb_gui = false
$vb_memory = 512
$vb_cpus = 1

# Attempt to apply the deprecated environment variable NUM_INSTANCES to
# $num_instances while allowing config.rb to override it
if ENV["NUM_INSTANCES"] && ENV["NUM_INSTANCES"].to_i > 0
  $num_instances = ENV["NUM_INSTANCES"].to_i
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "coreos-%s" % $update_channel
  config.vm.box_version = ">= 308.0.1"
  config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % $update_channel

  config.vm.provider :vmware_fusion do |v, override|
    override.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant_vmware_fusion.json" % $update_channel
  end

  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf
    # in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
  end

  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  env = JSON.parse(File.read('env.json'))
  
  (1..$num_instances).each do |i|
    vm_name = "coreos-%02d" % i
    mac_addr = false
    if env['start-mac-addr']
      mac_addr = env['start-mac-addr'].split(':')[0..4].join(':') << ':' << (env['start-mac-addr'].split(':')[-1].to_i + i - 1).to_s
    end
    
    config.vm.define vm_name do |coreos|

      coreos.vm.hostname = env['hostname']+'-'+vm_name

      if env['interface']
        coreos.vm.network :public_network, :bridge => env['interface']
      else
        coreos.vm.network :public_network
      end

      if mac_addr
        coreos.vm.provider :vmware_fusion do |v|
          v.vmx["ethernet0.present"] = "TRUE"
          v.vmx["ethernet0.connectionType"] = "nat"
          v.vmx["ethernet1.generatedAddress"] = nil
          v.vmx["ethernet1.present"] = "TRUE"
          v.vmx["ethernet1.connectionType"] = "bridged"
          v.vmx["ethernet1.addressType"] = "static"
          v.vmx["ethernet1.address"] = mac_addr
        end
      end

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), "log")
        FileUtils.mkdir_p(logdir)

        serialFile = File.join(logdir, "%s-serial.txt" % vm_name)
        FileUtils.touch(serialFile)

        coreos.vm.provider :vmware_fusion do |v|
          v.vmx["serial0.present"] = "TRUE"
          v.vmx["serial0.fileType"] = "file"
          v.vmx["serial0.fileName"] = serialFile
          v.vmx["serial0.tryNoRxLoss"] = "FALSE"
        end

        coreos.vm.provider :virtualbox do |v|
          v.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
          v.customize ["modifyvm", :id, "--uartmode1", serialFile]
        end
      end

      coreos.vm.provider :vmware_fusion do |v|
        v.gui = $vb_gui
        v.vmx["memsize"] = $vb_memory
        v.vmx["numvcpus"] = $vb_cpus
      end

      coreos.vm.provider :virtualbox do |v|
        v.gui = $vb_gui
        v.memory = $vb_memory
        v.cpus = $vb_cpus
      end

      coreos.vm.provision :shell, inline: "timedatectl set-timezone \""+env["timezone"]+"\""

      # Uncomment below to enable NFS for sharing the host machine into the coreos-vagrant VM.
      #config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']

      if File.exist?(CLOUD_CONFIG_PATH)
        config.vm.provision :file, :source => CLOUD_CONFIG_PATH, :destination => '/tmp/vagrantfile-user-data'
        config.vm.provision :shell, :inline => 'mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/', :privileged => true
      end

      if i == 1
        coreos.vm.synced_folder ".", "/workspace", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']
        coreos.vm.provision :shell, inline: "
          if [ ! -L /opt/bin ];then
            mkdir -p /opt
            ln -sf /workspace/bin-coreos /opt/bin
          fi
          chmod +x /workspace/bin-coreos/*

          for image in ubuntu:trusty;do
            get $image
          done
          
          getent group docker | cut -d: -f3 > /workspace/.system/docker-group-id
        "
      end
    end
  end
end
