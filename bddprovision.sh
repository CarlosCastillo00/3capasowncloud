#!/bin/bash
# Por problemas de vagrant, tenía conectividad a internet, pero no me permitía descargar nada, por lo tanto he agregado esta línea al /etc/resolv.conf
sudo bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
# Instalar dependencias
sudo apt-get update -y
sudo apt-get install -y mariadb-server 
# Permitir acceso remoto desde los servidores web
sed -i 's/bind-address.*/bind-address = 192.168.15.10/' /etc/mysql/mariadb.conf.d/50-server.cnf
# Reiniciar MariaDB
sudo systemctl restart mariadb
# Crear base datos OwnCloud
mysql -u root <<EOF
CREATE DATABASE owncloud;
CREATE USER 'Carloscast'@'192.168.15%' IDENTIFIED BY 'S1234?';
GRANT ALL PRIVILEGES ON db_owncloud.* TO 'Carloscast'@'192.168.15%';
FLUSH PRIVILEGES;
EOF
# Quitamos internet
sudo ip route del default