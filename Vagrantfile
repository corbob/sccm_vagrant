# -*- mode: ruby -*-
# vi: set ft=ruby :

SERVER_BOX = "gusztavvargadr/windows-server"
CPUS = 4
MEMS = 8192

Vagrant.configure("2") do |config|
  config.vm.box = SERVER_BOX
  config.vm.hostname = "dc01"
  config.vm.guest = :windows
  # This is stupid... We shouldn't have to repeat outselves...
  config.vm.provider :virtualbox do |hv|
    hv.cpus = CPUS
    hv.memory = MEMS
  end
  config.vm.provider :hyperv do |hv|
    hv.cpus = CPUS
    hv.memory = MEMS
  end
  config.vm.provision :shell, :path => "provisioning/provision.ps1"
end
