#!/bin/bash
# Por problemas de vagrant, tenía conectividad a internet, pero no me permitía descargar nada, por lo tanto he agregado esta línea al /etc/resolv.conf
sudo bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
# Actualizar repositorios e instalar dependencias
sudo apt-get update -y
sudo apt-get install -y nginx nfs-common php7.4 php7.4-fpm php7.4-mysql php7.4-gd php7.4-xml php7.4-mbstring php7.4-curl php7.4-zip php7.4-intl php7.4-ldap mariadb-client
# Crear directorio para carpeta compartida
sudo mkdir -p /var/www/html
# Montar la carpeta NFS
sudo mount -t nfs 192.168.10.12:/var/www/html /var/www/html
# Añadir entrada al /etc/fstab para montaje persistente
echo "192.168.10.12:/var/www/html /var/www/html nfs defaults 0 0" >> /etc/fstab
# Configuración de Nginx para servir OwnCloud
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80;

    root /var/www/html/owncloud;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 192.168.10.12:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) {
        deny all;
    }
}
EOF
# Verificar Nginx
nginx -t
# Aplicar los cambios
sudo systemctl restart nginx
# Reiniciar PHP
sudo systemctl restart php7.4-fpm
# Quitamos internet
sudo ip route del default