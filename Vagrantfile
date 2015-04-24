# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'json'

Vagrant.require_version '>= 1.6.0'
VAGRANTFILE_API_VERSION = '2'
CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), 'config/user-data')

# # Defaults for config options defined in CONFIG
$env = JSON.parse(File.read(ENV['WORKSPACE']+'/env.json'))
$num_instances = $env['instances'] ? $env['instances'] : 1
$update_channel = $env['coreos-update-channel'] ? $env['coreos-update-channel'] : 'stable'
$enable_serial_logging = false
$vb_gui = false

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  
  config.vm.box = 'coreos-%s' % $update_channel
  box_version = 'current'
  if $env['coreos-version'] then
    config.vm.box_version = $env['coreos-version']
    box_version = $env['coreos-version']
  end

  config.vm.box_url = "http://#{$update_channel}.release.core-os.net/amd64-usr/#{box_version}/coreos_production_vagrant.json"

  config.vm.provider :vmware_fusion do |v, override|
    override.vm.box_url = "http://#{$update_channel}.release.core-os.net/amd64-usr/#{box_version}/coreos_production_vagrant_vmware_fusion.json"
  end

  config.vm.provider :virtualbox do |v|
    # On VirtualBox, we don't have guest additions or a functional vboxsf in CoreOS, so tell Vagrant that so it can be smarter.
    v.check_guest_additions = false
    v.functional_vboxsf     = false
  end

  if Vagrant.has_plugin?('vagrant-vbguest') then
    config.vbguest.auto_update = false
  end
  
  (1..$num_instances).each do |i|
    vm_name = 'coreos-%02d' % i
    mac_addr = false
    if $env['start-mac-addr']
      mac_addr = $env['start-mac-addr'].split(':')[0..4].join(':') << ':' << ($env['start-mac-addr'].split(':')[-1].to_i + i - 1).to_s
    end
    
    config.vm.define vm_name do |coreos|
    
      coreos.trigger.after :up do
        run "touch ./.system/coreos-%02d-running" % i
        run "./coreos -f fetch_ip coreos-%02d" % i
      end

      coreos.trigger.after :destroy do
        run "rm ./.system/coreos-%02d-running" % i
        run "rm ./.system/coreos-%02d-disk-size" % i
      end

      coreos.trigger.after :halt do
        run "rm ./.system/coreos-%02d-running" % i
      end

      coreos.trigger.after :reload do
        run "touch ./.system/coreos-%02d-running" % i
        run "./coreos -f fetch_ip"
      end

      coreos.vm.hostname = $env['hostname']+'-'+vm_name
      
      if $env['network'] == 'private'
        coreos.vm.network :private_network, ip: "172.16.1.1%02d" % i
      elsif $env['network-interface']
        coreos.vm.network :public_network, bridge: $env['network-interface']
      else
        coreos.vm.network :public_network
      end

      if mac_addr
        coreos.vm.provider :vmware_fusion do |v|
          v.vmx['ethernet0.present'] = 'TRUE'
          v.vmx['ethernet0.connectionType'] = 'nat'
          v.vmx['ethernet1.generatedAddress'] = nil
          v.vmx['ethernet1.present'] = 'TRUE'
          v.vmx['ethernet1.connectionType'] = 'bridged'
          v.vmx['ethernet1.addressType'] = 'static'
          v.vmx['ethernet1.address'] = mac_addr
        end
      end

      coreos.vm.provider :vmware_fusion do |v|
        v.gui = $vb_gui
        v.vmx['memsize'] = $env['memory']
        v.vmx['numvcpus'] = $env['cpus']
      end

      coreos.vm.provider :virtualbox do |v|
        v.gui = $vb_gui
        v.memory = $env['memory']
        v.cpus = $env['cpus']
      end

      if $enable_serial_logging
        logdir = File.join(File.dirname(__FILE__), 'log')
        FileUtils.mkdir_p(logdir)

        serialFile = File.join(logdir, '%s-serial.txt' % vm_name)
        FileUtils.touch(serialFile)

        coreos.vm.provider :vmware_fusion do |v|
          v.vmx['serial0.present'] = 'TRUE'
          v.vmx['serial0.fileType'] = 'file'
          v.vmx['serial0.fileName'] = serialFile
          v.vmx['serial0.tryNoRxLoss'] = 'FALSE'
        end

        coreos.vm.provider :virtualbox do |v|
          v.customize ['modifyvm', :id, '--uart1', '0x3F8', '4']
          v.customize ['modifyvm', :id, '--uartmode1', serialFile]
        end
      end

      if File.exist?(CLOUD_CONFIG_PATH)
        config.vm.provision :file, :source => CLOUD_CONFIG_PATH, :destination => '/tmp/vagrantfile-user-data'
        config.vm.provision :shell, :inline => 'mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/', :privileged => true
      end

      coreos.vm.provision :shell, inline: 'timedatectl set-timezone "'+$env['timezone']+'"'

      if i == 1
        coreos.vm.synced_folder '.', '/workspace', id: 'core', type: 'nfs', :mount_options => ['actimeo=2,nolock,vers=3,udp']
        coreos.vm.provision :shell, inline: '
          if [ ! -L /opt/bin ];then
            mkdir /opt && ln --symbolic --force /workspace/bin-coreos /opt/bin
          fi
          chmod +x /workspace/bin-coreos/*
          get ubuntu:trusty
          get phusion/baseimage:0.9.16
          version="$(cat /workspace/.system/workspace-version.txt)"
          get crobays/workspace:$version
          getent group docker | cut -d: -f3 > /workspace/.system/docker-group-id
          docker version > /workspace/workspace-image/docker/docker-version
        '
      end
    end
  end
end
