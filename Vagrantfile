# -*- mode: ruby -*-
# vi: set ft=ruby :

SERVER_BOX = "gusztavvargadr/windows-server"
CLIENT_BOX = "gusztavvargadr/windows-10"

Vagrant.configure("2") do |config|
  config.vm.define "dc" do |dc|
    dc.vm.box = SERVER_BOX
    dc.vm.hostname = "dc01"
    dc.vm.network "private_network", ip: "10.0.0.10"
    dc.vm.guest = :windows
    dc.vm.provision :shell, path: "provisioning/dc1.ps1"
    # dc.vm.provision :reload
    # dc.vm.provision :shell, path: "provisioning/dc2.ps1"
  end
  config.vm.define "ps" do |ps|
    ps.vm.box = SERVER_BOX
    ps.vm.hostname = "ps01"
    ps.vm.network "private_network", ip: "10.0.0.20"
    ps.vm.guest = :windows
    ps.vm.provision :shell, path: "provisioning/domainJoin.ps1"
  end
  config.vm.define "cl" do |cl|
    cl.vm.box = CLIENT_BOX
    cl.vm.hostname = "cl01"
    cl.vm.network "private_network", ip: "10.0.0.100"
    cl.vm.guest = :windows
    cl.vm.provision :shell, path: "provisioning/domainJoin.ps1"
  end
end
