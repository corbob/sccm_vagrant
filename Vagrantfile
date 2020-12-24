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
  config.vm.provider :hyperv do |hv,over|
    hv.cpus = CPUS
    hv.memory = MEMS
    # Uncomment the following lines and fill in your details to automatically map your synced folder, and to autoselect the Hyper-V vSwitch
    # over.vm.network :public_network, bridge: "External"
    # over.vm.synced_folder ".", "/vagrant", type: "smb", smb_password: "password", smb_username: "username"
  end
  config.vm.provision :shell, :path => "provisioning/provision.ps1"
end
