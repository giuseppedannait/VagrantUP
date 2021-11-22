# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "ubuntu/xenial64"
  config.vm.network "private_network", ip: "192.168.111.222"
  config.vm.synced_folder "./", "/var/www", id: "vagrant-root", owner: "www-data", group: "www-data", mount_options: ["dmode=777", "fmode=777"]
  config.vm.provision :shell, path: "bootstrap.sh"

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "768"]
    vb.customize ["modifyvm", :id, "--name", "dev.ascommultiservice.local"]
    end
end
