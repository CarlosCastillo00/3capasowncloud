#!/bin/bash
# Por problemas de vagrant, tenía conectividad a internet, pero no me permitía descargar nada, por lo tanto he agregado esta línea al /etc/resolv.conf
sudo bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
# Actualizar repositorios e instalar dependencias
sudo apt-get update -y
sudo apt-get install -y nfs-kernel-server php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap unzip
# Crear carpeta compartida configurar permisos
sudo mkdir -p /var/www/html
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html
# Configurar NFS y compartir la carpeta
echo "/var/www/html 192.168.10.11(rw,sync,no_subtree_check)" >> /etc/exports
echo "/var/www/html 192.168.10.10(rw,sync,no_subtree_check)" >> /etc/exports
# Aplicar cambios
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
# Descargar y configurar OwnCloud
cd /tmp
wget https://download.owncloud.com/server/stable/owncloud-10.9.1.zip
unzip owncloud-10.9.1.zip
mv owncloud /var/www/html/
# Permisos de OwnCloud
sudo chown -R www-data:www-data /var/www/html/owncloud
sudo chmod -R 755 /var/www/html/owncloud
# Crear archivo de configuración OwnCloud
cat <<EOF > /var/www/html/owncloud/config/autoconfig.php
<?php
\$AUTOCONFIG = array(
  "dbtype" => "mysql",
  "dbname" => "db_owncloud",
  "dbuser" => "Carloscast",
  "dbpassword" => "S1234?",
  "dbhost" => "192.168.15.10",
  "directory" => "/var/www/html/owncloud/data",
  "adminlogin" => "Carlos",
  "adminpass" => "S1234?"
);
EOF
# Modificar el archivo config.php 
echo "Añadiendo dominios de confianza a la configuración de OwnCloud..."
php -r "
  \$configFile = '/var/www/html/owncloud/config/config.php';
  if (file_exists(\$configFile)) {
    \$config = include(\$configFile);
    \$config['trusted_domains'] = array(
      'localhost',
      'localhost:8080',
      '192.168.10.10',
      '192.168.10.11',
      '192.168.10.12',
    );
    file_put_contents(\$configFile, '<?php return ' . var_export(\$config, true) . ';');
  } else {
    echo 'No se pudo encontrar el archivo config.php';
  }
"
# Configuración para escuchar en la IP del servidor NFS
sed -i 's/^listen = .*/listen = 192.168.10.12:9000/' /etc/php/7.4/fpm/pool.d/www.conf
# Reiniciar PHP
sudo systemctl restart php7.4-fpm
# Quitamos internet
sudo ip route del default
