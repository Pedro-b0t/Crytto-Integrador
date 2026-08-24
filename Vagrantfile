Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.boot_timeout = 600

  config.vm.define "app" do |app|
    app.vm.hostname = "crytto-rpg-app"
    app.vm.network "private_network", ip: "192.168.56.21"
    app.vm.network "forwarded_port", guest: 80, host: 8080, auto_correct: true
    app.vm.network "forwarded_port", guest: 3001, host: 3001, auto_correct: true

    app.vm.provider "virtualbox" do |vb|
      vb.name = "crytto-rpg-v2-app"
      vb.memory = 3072
      vb.cpus = 2
    end

    app.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3
    SHELL
  end

  config.vm.define "db" do |db|
    db.vm.hostname = "crytto-rpg-db"
    db.vm.network "private_network", ip: "192.168.56.22"
    db.vm.network "forwarded_port", guest: 5432, host: 5433, auto_correct: true

    db.vm.provider "virtualbox" do |vb|
      vb.name = "crytto-rpg-v2-db"
      vb.memory = 1536
      vb.cpus = 1
    end

    db.vm.provision "shell", inline: <<-SHELL
      apt-get update
      apt-get install -y python3
    SHELL
  end
end
