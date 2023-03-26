#!/bin/bash

#Global Functions
infoMessage(){
  echo -e "\e[34m$1\e[0m"
}

successMessage(){
  echo -e "\e[32m$1\e[0m"
}

errorMessage(){
  echo -e "\e[31m$1\e[0m"
}



update(){
  echo "update ..."
  apt update
}

upgrade(){
  echo "upgrade ..."
  apt upgrade -y
}

installRequired(){
  echo "installing required packages ..."
  apt install -y git curl gcc g++ make apt-transport-https ca-certificates \
    gnupg lsb-release dirmngr software-properties-common \
    apt-transport-https ca-certificates software-properties-common
}

getInstallation() {
    infoMessage "do you want to install $1 (y/n)"
    read -r i
    if [ "$i" = "y" ];
    then
      install_"$1"
    fi
}

install_nginx() {
    if [ -x "$(command -v nginx)" ]; then
        errorMessage 'Error: nginx is already installed.' >&2
    else
      infoMessage "installing nginx ..."
      apt install -y nginx
      systemctl start nginx
      systemctl enable nginx
      ufw allow 'Nginx Full'
      successMessage "nginx installed successfully"
    fi
}

install_mysql() {
    if [ -x "$(command -v mysql)" ]; then
        errorMessage 'Error: mysql is already installed.' >&2
    else
      infoMessage "installing mysql ..."
      apt install -y mysql-server
      systemctl start mysql
      systemctl enable mysql
      mysql_secure_installation
      successMessage "mysql installed successfully"
    fi
}

mysql_secure_installation(){
  infoMessage "mysql_secure_installation ..."
  infoMessage "please enter mysql root password"
  read -r password
  mysql -u root -p <<EOF
  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$password';
  FLUSH PRIVILEGES;
  exit
EOF
  successMessage "mysql_secure_installation successfully"
}

install_php() {
    if [ -x "$(command -v php)" ]; then
        errorMessage 'Error: php is already installed.' >&2
    else
      infoMessage "installing php ..."
      apt install -y php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip
      systemctl start php-fpm
      systemctl enable php-fpm
      successMessage "php installed successfully"
    fi
}

install_docker() {
    if [ -x "$(command -v docker)" ]; then
        errorMessage 'Error: docker is already installed.' >&2
    else
      infoMessage "installing docker ..."
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      infoMessage "updating ..."
      apt update
      apt-cache policy docker-ce
      apt install -y docker-ce
      systemctl status docker
      usermod -aG docker ${USER}
      su - ${USER}
      id -nG
      successMessage "docker installed successfully"
    fi
}

install_docker_compose() {
    if [ -x "$(command -v docker-compose)" ]; then
        errorMessage 'Error: docker-compose is already installed.' >&2
    else
      infoMessage "installing docker-compose ..."
      curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      chmod +x /usr/local/bin/docker-compose
      ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
      docker-compose --version
      successMessage "docker-compose installed successfully"
    fi
}

install_composer() {
    if [ -x "$(command -v composer)" ]; then
        errorMessage 'Error: composer is already installed.' >&2
    else
      infoMessage "installing composer ..."
      curl -sS https://getcomposer.org/installer | php
      mv composer.phar /usr/local/bin/composer
      chmod +x /usr/local/bin/composer
      successMessage "composer installed successfully"
    fi
}


update
upgrade

installRequired

for i in nginx mysql php docker docker_compose
do
    getInstallation $i
done

#get directory project
infoMessage "Please enter directory project from /home/$USER (for example: project/foo)"
read -r directory
cd /home/"$USER"/"$directory" || exit

#git clone base project
git clone https://gitlab.com/sourceInja/core/laravel-core.git
mv laravel-core/* .
rm -rf laravel-core
rm -rf .git
install_composer
composer install

infoMessage "Please enter application name"
read -r app_name
infoMessage "Please enter application url"
read -r app_url
infoMessage "Please enter database name"
read -r db_name
infoMessage "Please enter database user name"
read -r db_user
infoMessage "Please enter database user password"
read -r db_pass
infoMessage "making .env file ..."
cat > .env <<EOF
APP_NAME=$app_name
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=$app_url

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=$db_name
DB_USERNAME=$db_user
DB_PASSWORD=$db_pass

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DRIVER=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=mailgun
MAIL_HOST=smtp.mailgun.org
MAIL_PORT=587
MAIL_USERNAME=postmaster@sandboxfc845f8eb5634f37bd20172181f6653a.mailgun.org
MAIL_PASSWORD=d1532a8b6bd68916ea8a6aef68d019f6-1b3a03f6-1f04cd5e
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=info@chainobin.com
MAIL_FROM_NAME="${APP_NAME}"
MAILGUN_DOMAIN=sandboxfc845f8eb5634f37bd20172181f6653a.mailgun.org
MAILGUN_SECRET=d1532a8b6bd68916ea8a6aef68d019f6-1b3a03f6-1f04cd5e

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_APP_CLUSTER=mt1

MIX_PUSHER_APP_KEY="${PUSHER_APP_KEY}"
MIX_PUSHER_APP_CLUSTER="${PUSHER_APP_CLUSTER}"

L5_SWAGGER_GENERATE_ALWAYS=true
L5_SWAGGER_UI_DOC_EXPANSION=list

EOF
successMessage "env file created successfully"

infoMessage "Do you want to setup nginx? (y/n)"
read -r nginx
if [ "$nginx" = "y" ]; then
    cd /etc/nginx/conf.d/ || exit
    touch "$app_name".conf
    cat > "$app_name".conf <<EOF
      server {
          listen      80;
          server_name  $app_url;
          index index.php index.html index.htm;
          client_max_body_size 1000M;

          access_log  /var/log/nginx/$app_name.access.log;
          error_log  /var/log/nginx/$app_name.error.log;
          root /home/$USER/$directory/public;
          location / {
              try_files $uri $uri/ /index.php?$query_string;
          }
          location ~ \.php$ {
              try_files $uri =404;
              fastcgi_split_path_info ^(.+\.php)(/.+)$;
              fastcgi_pass unix:/run/php/php-fpm.sock;
              fastcgi_index index.php;
              fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
              include fastcgi_params;
          }
      }
EOF
    successMessage "nginx config file created successfully"
    infoMessage "Do you want to restart nginx? (y/n)"
    read -r restart_nginx
    if [ "$restart_nginx" = "y" ]; then
        systemctl restart nginx
        successMessage "nginx restarted successfully"
    fi
fi
