#!/usr/bin/env bash

PASSWORD='root'

# update / upgrade
sudo apt-get update
sudo apt-get -y upgrade

# install apache 2.5 and php 5.5
sudo apt-get install -y apache2
sudo apt-get install -y php5
sudo apt-get install -y php5-mcrypt
sudo apt-get install -y php5-curl

APACHEUSR=`grep -c 'APACHE_RUN_USER=www-data' /etc/apache2/envvars`
APACHEGRP=`grep -c 'APACHE_RUN_GROUP=www-data' /etc/apache2/envvars`
if [ APACHEUSR ]; then
    sed -i 's/APACHE_RUN_USER=www-data/APACHE_RUN_USER=vagrant/' /etc/apache2/envvars
fi
if [ APACHEGRP ]; then
    sed -i 's/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=vagrant/' /etc/apache2/envvars
fi
sudo chown -R vagrant:www-data /var/lock/apache2

# install mysql and give password to installer
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $PASSWORD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $PASSWORD"
sudo apt-get -y install mysql-server
sudo apt-get install php5-mysql

# enable mod_rewrite
sudo a2enmod rewrite

echo "EnableMMAP off
EnableSendfile off" > /etc/apache2/httpd.conf

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini

sudo sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf

sudo ln -s /etc/php5/mods-available/mcrypt.ini /etc/php5/apache2/conf.d/20-mcrypt.ini
sudo php5enmod mcrypt




# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y install phpmyadmin

sudo rm /var/www/html/index.html

ARQUIVOADD=$(cat <<EOF
#!/bin/bash
 
 
echo "Informe o nome do usuario (Ex.: vagrant) :"
read usuario

echo "Informe o nome do server (Ex.: vagrant.vag) :"
read server
 
path=/var/www/\$usuario/public_html

echo "criando diretorios"
sudo mkdir -p \$path

sudo chown -R vagrant:vagrant /var/www/\$usuario

sudo chmod -R 755 /var/www

echo "Criando configuração de VHost para o server"
 
sudo sh -c "echo '
<VirtualHost *:80>

        ServerName \$server
        DocumentRoot "\$path"
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
' > /etc/apache2/sites-available/\$server.conf"
 
echo "Ativando VHOST \$server"
sudo a2ensite \$server.conf
 
echo "Reiniciando apache";
sudo service apache2 restart

echo "Criando base de dados"
echo "CREATE DATABASE \$usuario" | mysql -uroot -proot
echo "GRANT ALL ON \$usuario.* TO 'root'@'localhost'" | mysql -uroot -proot
echo "flush privileges" | mysql -uroot -proot

echo "VirtualHost criado."
EOF
)

ARQUIVOADDGIT=$(cat <<EOF
#!/bin/bash
 
 
echo "Informe o nome do usuario (Ex.: vagrant) :"
read usuario

echo "Informe o nome do server (Ex.: vagrant.vag) :"
read server

echo "Informe o link do git (Ex.: https://gitlab.com/vagrant.git) :"
read git
 
path=/var/www/\$usuario/public_html
pathgit=/var/www/\$usuario/

echo "criando diretorios"
sudo mkdir -p \$path

sudo chown -R vagrant:vagrant /var/www/\$usuario

sudo chmod -R 755 /var/www

echo "Criando configuração de VHost para o server"
 
sudo sh -c "echo '
<VirtualHost *:80>

        ServerName \$server
        DocumentRoot "\$path"
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
' > /etc/apache2/sites-available/\$server.conf"
 
echo "Ativando VHOST \$server"
sudo a2ensite \$server.conf
 
echo "Reiniciando apache";
sudo service apache2 restart

echo "Clonando projeto":
git clone \$git \$path

echo "Criando base de dados"
echo "CREATE DATABASE \$usuario" | mysql -uroot -proot
echo "GRANT ALL ON \$usuario.* TO 'root'@'localhost'" | mysql -uroot -proot
echo "flush privileges" | mysql -uroot -proot

echo "VirtualHost criado."
EOF
)

ARQUIVORM=$(cat <<EOF
#!/bin/bash
 
echo "Informe o nome do server (Ex.: vagrant.vag) :"
read server
 
echo "Desativando e removendo VHOST \$server"
sudo a2dissite \$server.conf
sudo rm /etc/apache2/sites-available/\$server.conf
 
echo "Reiniciando apache";
sudo service apache2 restart
 
echo "VirtualHost removido.";
EOF
)

# restart apache
service apache2 restart

# install git
sudo apt-get -y install git

echo "${ARQUIVOADD}" > /usr/local/bin/addVhost
echo "${ARQUIVORM}" > /usr/local/bin/rmVhost
echo "${ARQUIVOADDGIT}" > /usr/local/bin/addVgit
chmod +x /usr/local/bin/addVhost
chmod +x /usr/local/bin/rmVhost
chmod +x /usr/local/bin/addVgit


echo "cd /vagrant/" > /home/vagrant/.bash_profile
echo "set nocp" > /home/vagrant/.vimrc
