# -*- mode: ruby -*-
# vi: set ft=ruby :

SERVER_BOX = "gusztavvargadr/windows-server"
CLIENT_BOX = "gusztavvargadr/windows-10"

Vagrant.configure("2") do |config|
  config.vm.define "dc" do |v|
    v.vm.box = SERVER_BOX
    v.vm.hostname = "dc01"
    v.vm.network "private_network", ip: "10.0.0.10"
    v.vm.guest = :windows
    v.vm.provider :virtualbox do |hv|
      hv.cpus = 2
      hv.memory = 8192
    end
    v.vm.provision :shell, :path => "provisioning/provision.ps1"
  end
  # config.vm.define "ps" do |v|
  #   v.vm.box = SERVER_BOX
  #   v.vm.hostname = "ps01"
  #   v.vm.network "private_network", ip: "10.0.0.20"
  #   v.vm.guest = :windows
  # end
  # config.vm.define "cl" do |v|
  #   v.vm.box = CLIENT_BOX
  #   v.vm.hostname = "cl01"
  #   v.vm.network "private_network", ip: "10.0.0.30"
  #   v.vm.guest = :windows
  # end
end
