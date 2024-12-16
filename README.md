# Proyecto CMS en Alta Disponibilidad

## Índice

1. [Introducción](#introducción)
2. [Infraestructura](#infraestructura)
3. [Requisitos Previos](#requisitos-previos)
4. [Pasos de Configuración](#pasos-de-configuración)
   - [Configuración del Balanceador de Carga](#1-configuración-del-balanceador-de-carga)
   - [Configuración de los Servidores Web](#2-configuración-de-los-servidores-web)
   - [Configuración del Servidor NFS y PHP-FPM](#3-configuración-del-servidor-nfs-y-php-fpm)
   - [Configuración de la Base de Datos MariaDB](#4-configuración-de-la-base-de-datos-mariadb)
5. [Pruebas de Funcionamiento](#pruebas-de-funcionamiento)
6. [Conclusión](#conclusión)

## Introducción

En este proyecto se despliega un CMS (OwnCloud) sobre una infraestructura en alta disponibilidad utilizando una pila LEMP. La infraestructura está diseñada en tres capas:

- **Capa 1:** Balanceador de carga Nginx expuesto a red pública.
- **Capa 2:** Servidores backend con Nginx que utilizan una carpeta compartida por NFS y el motor PHP-FPM.
- **Capa 3:** Base de datos MariaDB no expuesta a red pública.

Toda la infraestructura se despliega en local utilizando Vagrant y VirtualBox, y se aprovisiona mediante scripts automatizados.

## Infraestructura

### Estructura

| Máquina                | IP Privada       | Rol                        |
|------------------------|------------------|----------------------------|
| `BalanceadorCarloscast` | `192.168.10.5`   | Balanceador de carga Nginx |
| `Web1Carloscast`       | `192.168.10.10`  | Servidor web Nginx         |
| `Web2Carloscast`       | `192.168.10.11`  | Servidor web Nginx         |
| `NFSCarloscast`        | `192.168.10.12`  | Servidor NFS y PHP-FPM     |
| `SGBDCarloscast`       | `192.168.15.10`  | Base de datos MariaDB      |

### Direccionamiento de Red

- **Red Privada 1:** Comunicación entre el balanceador y los servidores web.
- **Red Privada 2:** Comunicación entre servidores web, NFS y la base de datos.

### Software Utilizado

- Sistema Operativo: Debian Bullseye
- Balanceador: Nginx
- Servidor Web: Nginx
- Servidor NFS: nfs-kernel-server
- PHP: PHP 7.4
- Base de Datos: MariaDB
- CMS: OwnCloud

## Requisitos Previos

- Tener instalados **Vagrant** y **VirtualBox** en la máquina anfitriona.
- Acceso a internet para descargar dependencias.
- ISO Debian.
- Archivos de provisionamiento disponibles en el repositorio.
- El orden de aprovisionamiento debe ser el orden del vagrant file, de otra forma ocasionará fallos.
  
## Pasos de Configuración

### 1. Configuración del Balanceador de Carga

#### Script: `balanceadorprovision.sh`

1. Instalar Nginx:
   ```bash
   sudo apt-get update -y
   sudo apt-get install -y nginx
   ```
2. Configurar Nginx como balanceador de carga:
   ```bash
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
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       }
   }
   EOF
   ```
3. Reiniciar Nginx:
   ```bash
   sudo systemctl restart nginx
   ```

### 2. Configuración de los Servidores Web

#### Script: `websprovision.sh`

1. Instalar Nginx, NFS y PHP:
   ```bash
   sudo apt-get update -y
   sudo apt-get install -y nginx nfs-common php7.4 php7.4-fpm
   ```
2. Montar la carpeta compartida por NFS:
   ```bash
   sudo mkdir -p /var/www/html
   sudo mount -t nfs 192.168.10.12:/var/www/html /var/www/html
   echo "192.168.10.12:/var/www/html /var/www/html nfs defaults 0 0" >> /etc/fstab
   ```
3. Configurar Nginx para servir OwnCloud:
   ```bash
   cat <<EOF > /etc/nginx/sites-available/default
   server {
       listen 80;

       root /var/www/html/owncloud;
       index index.php index.html index.htm;

       location / {
           try_files $uri $uri/ /index.php?$query_string;
       }

       location ~ \.php$ {
           include snippets/fastcgi-php.conf;
           fastcgi_pass 192.168.10.12:9000;
           fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
           include fastcgi_params;
       }

       location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) {
           deny all;
       }
   }
   EOF
   ```
4. Reiniciar Nginx:
   ```bash
   sudo systemctl restart nginx
   ```

### 3. Configuración del Servidor NFS y PHP-FPM

#### Script: `nfsprovision.sh`

1. Instalar NFS y PHP:
   ```bash
   sudo apt-get update -y
   sudo apt-get install -y nfs-kernel-server php7.4 php7.4-fpm
   ```
2. Configurar la carpeta compartida por NFS:
   ```bash
   sudo mkdir -p /var/www/html
   sudo chown -R www-data:www-data /var/www/html
   echo "/var/www/html 192.168.10.10(rw,sync,no_subtree_check)" >> /etc/exports
   echo "/var/www/html 192.168.10.11(rw,sync,no_subtree_check)" >> /etc/exports
   sudo exportfs -a
   sudo systemctl restart nfs-kernel-server
   ```
3. Configurar PHP-FPM para escuchar conexiones remotas:
   ```bash
   sed -i 's/^listen = .*/listen = 192.168.10.12:9000/' /etc/php/7.4/fpm/pool.d/www.conf
   sudo systemctl restart php7.4-fpm
   ```

### 4. Configuración de la Base de Datos MariaDB

#### Script: `bddprovision.sh`

1. Instalar MariaDB:
   ```bash
   sudo apt-get update -y
   sudo apt-get install -y mariadb-server
   ```
2. Configurar acceso remoto:
   ```bash
   sed -i 's/bind-address.*/bind-address = 192.168.15.10/' /etc/mysql/mariadb.conf.d/50-server.cnf
   sudo systemctl restart mariadb
   ```
3. Crear base de datos y usuario:
   ```bash
   mysql -u root <<EOF
   CREATE DATABASE db_owncloud;
   CREATE USER 'Carloscast'@'192.168.15%' IDENTIFIED BY 'S1234?';
   GRANT ALL PRIVILEGES ON db_owncloud.* TO 'Carloscast'@'192.168.15%';
   FLUSH PRIVILEGES;
   EOF
   ```

## Pruebas de Funcionamiento
*No me funcionaba con los puertos mapeados, por lo tanto he utilizado la ip publica.

1.Visualizamos la IP del Balanceador:

![image](https://github.com/user-attachments/assets/8430fa8e-7bfc-49d7-8441-86cb2591e267)

2.Con esa IP, nos dirigimos a google y la ponemos junto a /owncloud y ponemos las credenciales de nuestro usuario:

![image](https://github.com/user-attachments/assets/fade760e-243f-4700-a07e-cff745398e42)

3.Ya estaríamos dentro:

![image](https://github.com/user-attachments/assets/e94dc93b-7cb2-49d5-b349-87564e9d4fa1)

 ## Pruebas para el videoclip
 
1. Verificar el estado de las máquinas:
   ```bash
   vagrant status
   ```
2. Realizar ping entre todas las máquinas.
3. Comprobar los sistemas de archivos montados:
   ```bash
   df -h
   ```
4. Acceder a la base de datos MariaDB desde los servidores web.
5. Acceder al CMS OwnCloud desde el navegador en la máquina anfitriona.
6. Consultar los logs de Nginx:
   ```bash
   sudo cat /var/log/nginx/access.log | tail -n 5
   ```

## Conclusión

Se ha desplegado una infraestructura en alta disponibilidad para un CMS utilizando Vagrant y VirtualBox. La configuración está completamente automatizada y permite escalar según las necesidades del sistema.
