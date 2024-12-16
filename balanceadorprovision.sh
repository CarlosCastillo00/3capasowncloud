#!/bin/bash
# Por problemas de vagrant, tenía conectividad a internet, pero no me permitía descargar nada, por lo tanto he agregado esta línea al /etc/resolv.conf
sudo bash -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
# Instalar nginx
sudo apt-get update -y
sudo apt-get install -y nginx
# Configuracion de balanceador 
cat <<EOF > /etc/nginx/sites-available/default
upstream backend_servers {
    server 192.168.10.10;
    server 192.168.10.11;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://backend_servers;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

EOF
# Reiniciar nginx
sudo systemctl restart nginx