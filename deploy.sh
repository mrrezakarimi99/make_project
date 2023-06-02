#!/bin/bash

#Global Functions

infoMessage() {
  echo -e "\e[34m$1\e[0m"
}

successMessage() {
  echo -e "\e[32m$1\e[0m"
}

errorMessage() {
  echo -e "\e[31m$1\e[0m"
}

#end Global Functions
#Main Functions

update() {
  echo "update ..."
  apt update
}

upgrade() {
  echo "upgrade ..."
  apt upgrade -y
}

installRequired() {
  echo "installing required packages ..."
  apt install -y git curl gcc g++ make apt-transport-https ca-certificates \
    gnupg lsb-release dirmngr software-properties-common \
    apt-transport-https ca-certificates software-properties-common
}

getInstallation() {
  infoMessage "do you want to install $1 (y/n)"
  read -r i
  if [ "$i" = "y" ]; then
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

mysql_secure_installation() {
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

createDataBase() {
  infoMessage "please enter mysql root password"
  read -r password
  mysql -u root -p"$password" <<EOF
  CREATE DATABASE $1;
  CREATE USER '$2'@'localhost' IDENTIFIED BY '$3';
  GRANT ALL PRIVILEGES ON $1.* TO '$2'@'localhost';
  FLUSH PRIVILEGES;
  exit
EOF
  successMessage "database created successfully"
}

#end Main Functions

infoMessage "Welcome to deploy script"
infoMessage "This script will install nginx, mysql, php, docker and docker-compose"
infoMessage "This script make with love by sourceInja team (https://sourceinja.ir)"
infoMessage "======================================================================="
infoMessage "        _____ ____  __  ______  _________________   __    _____        "
infoMessage "       / ___// __ \/ / / / __ \/ ____/ ____/  _/ | / /   / /   |       "
infoMessage "       \__ \/ / / / / / / /_/ / /   / __/  / //  |/ /_  / / /| |       "
infoMessage "      ___/ / /_/ / /_/ / _, _/ /___/ /____/ // /|  / /_/ / ___ |       "
infoMessage "     /____/\____/\____/_/ |_|\____/_____/___/_/ |_/\____/_/  |_|       "
infoMessage "======================================================================="
infoMessage "Do you want to update and upgrade (y/n)"
read -r i
if [ "$i" = "y" ]; then
  update
  upgrade
fi

infoMessage "Do you want to install required packages (y/n)"
read -r i
if [ "$i" = "y" ]; then
  installRequired
fi

infoMessage "Do you want to install nginx, mysql, php, docker and docker-compose (y/n)"
read -r i
if [ "$i" = "y" ]; then
  for i in nginx mysql php docker docker_compose; do
    getInstallation $i
  done
fi

#get directory project
infoMessage "Please enter directory project from /home/$USER (for example: project/foo)"
read -r -e -p "Please enter the path to the directory you want to use: " -i "/home/$USER"
if [ ! -d "$REPLY" ]; then
  infoMessage "Creating directory $REPLY"
  mkdir -p "$REPLY"
fi
cd "$REPLY" || exit

#git clone base project
git clone https://gitlab.com/sourceInja/core/laravel-core.git
#move all file to root directory with .env file
mv laravel-core/* .
mv laravel-core/.editorconfig .
mv laravel-core/.env.example .
mv laravel-core/.gitignore .
mv laravel-core/.gitattributes .
mv laravel-core/.styleci.yml .
rm -rf laravel-core
rm -rf .git
chown -R $USER:$USER .
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
#create database
createDataBase $db_name $db_user $db_pass
infoMessage "making .env file ..."
cp .env.example .env
sed -i "s/__APP_NAME__/$app_name/g" .env
sed -i "s/__APP_URL__/$app_url/g" .env
sed -i "s/__DB_DATABASE__/$db_name/g" .env
sed -i "s/__DB_USERNAME__/$db_user/g" .env
sed -i "s/__DB_PASSWORD__/$db_pass/g" .env
successMessage "env file created successfully"

infoMessage "Do you want to setup nginx? (y/n)"
read -r nginx
if [ "$nginx" = "y" ]; then
  mv nginx.conf.example "$app_name".conf
  sed -i "s/__DOMAIN__/$app_name/g" "$app_name".conf
  finalPath="/home/$USER/$directory/public"
  sed -i "s/__PATH__/$finalPath/g" "$app_name".conf
  cp "$app_name".conf /etc/nginx/sites-available
  ln -s /etc/nginx/sites-available/"$app_name".conf /etc/nginx/sites-enabled/
  rm "$app_name".conf
  successMessage "nginx config file created successfully"
  infoMessage "Do you want to restart nginx? (y/n)"
  read -r restart_nginx
  if [ "$restart_nginx" = "y" ]; then
    systemctl restart nginx
    successMessage "nginx restarted successfully"
  fi
fi