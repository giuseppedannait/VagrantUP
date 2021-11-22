#!/usr/bin/env bash

# Use single quotes instead of double quotes to make it work with special-character passwords
HOSTNAME='dev.ascommultiservice.local'
IP_VM='10.0.2.15'
IP_HS='192.168.111.222'
ROOTUSER='root'
USER='vagrant'
DBHOST='localhost'
DBNAME='amsdev'
DBUSER='amsdev'
DBPASSWD='amsdev'
HOME='/home/vagrant'
PHP_VER='7.3'

# create project folder
# sudo mkdir "/var/www"

# update / upgrade
sudo apt-get update
sudo apt-get upgrade -y
export DEBIAN_FRONTEND=noninteractive

# install LAMP common tool
sudo apt-get install -y vim curl python-software-properties zip git vfu htop npm

# Set Host File
sudo sh -c "echo '$IP_VM $HOSTNAME' >> /etc/hosts"

# install apache 2.5 and php 7.2
sudo apt-get install -y apache2
sudo add-apt-repository ppa:ondrej/php
sudo apt-get update
sudo apt-get install -y php$PHP_VER
sudo a2enmod php$PHP_VER 
sudo service apache2 restart

# install mysql and give password to installer
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password password $DBPASSWD"
sudo debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $DBPASSWD"
sudo apt-get -y install mysql-server mysql-client mysql-common
sudo apt-get install php$PHP_VER-mysql

sudo service mysql restart

#install common libraries
sudo apt-get install -y php$PHP_VER-mbstring php$PHP_VER-curl php$PHP_VER-cli php$PHP_VER-gd php$PHP_VER-intl php$PHP_VER-xsl php$PHP_VER-zip php$PHP_VER-xdebug php$PHP_VER-zip php$PHP_VER-xml php-pear build-essential		

# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
sudo apt-get install -y php-mcrypt
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get install -y phpmyadmin

# Mysql User's amsdev creation
echo -e "\n--- Setting up our MySQL user and db ---\n"
mysql -uroot -p$DBPASSWD -e "CREATE USER '$DBUSER'@'localhost' IDENTIFIED BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER'@'localhost'"
mysql -uroot -p$DBPASSWD -e "CREATE USER '$DBUSER'@'%' IDENTIFIED BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER'@'%'"
mysql -uroot -p$DBPASSWD -e "CREATE USER '$ROOTUSER'@'%' IDENTIFIED BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "GRANT ALL PRIVILEGES ON * . * TO '$ROOTUSER'@'%'"
mysql -uroot -p$DBPASSWD -e "ALTER USER '$DBUSER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "ALTER USER '$DBUSER'@'%' IDENTIFIED WITH mysql_native_password BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "ALTER USER '$ROOTUSER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "ALTER USER '$ROOTUSER'@'%' IDENTIFIED WITH mysql_native_password BY '$DBPASSWD'"
mysql -uroot -p$DBPASSWD -e "CREATE DATABASE '$DBNAME's"

# Set Mysql OPTIONS
sudo sed -i "s/127.0.0.1/0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf
sudo sh -c "echo 'sql-mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' >> /etc/mysql/mysql.conf.d/mysqld.cnf"
sudo service mysql restart

# Set PHP OPTIONS
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/$PHP_VER/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/$PHP_VER/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 32M/" /etc/php/$PHP_VER/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 32M/" /etc/php/$PHP_VER/apache2/php.ini
sudo sed -i "s/disable_functions = .*/disable_functions = /" /etc/php/$PHP_VER/apache2/php.ini

# enable mod_rewrite
sudo a2enmod rewrite

# setup hosts file
VHOST=$(cat <<EOF
<VirtualHost *:80>
    ServerName $HOSTNAME
    DocumentRoot "/var/www"
    DirectoryIndex index.php index.htm index.html
    <Directory "/var/www">
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/$USER_error.log
    LogLevel debug
    CustomLog ${APACHE_LOG_DIR}/$USER_access.log combined

</VirtualHost>
EOF
)
echo "${VHOST}" > /etc/apache2/sites-available/000-default.conf

# install and configure xdebug
sudo mkdir -p /var/log/xdebug
sudo chown www-data:www-data /var/log/xdebug

XDEBUG=$(cat <<EOF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Added to enable Xdebug 2 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;zend_extension="'$(find / -name 'xdebug.so' 2> /dev/null)'"
;xdebug.default_enable = 1
;xdebug.idekey = ""
;xdebug.remote_autostart = 1
;xdebug.remote_port = 9001
;xdebug.remote_handler=dbgp
;xdebug.remote_log="/var/log/xdebug/xdebug.log
;xdebug.remote_host=10.0.2.2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Added to enable Xdebug 3 ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
xdebug.mode=debug
xdebug.client_host=$IP_HS
xdebug.client_port="9003"
EOF
)
sudo sh -c "echo '${XDEBUG}' > /etc/php/$PHP_VER/apache2/xdebug.ini"

# install Composer
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
export PATH=~/.config/composer/vendor/bin:$PATH

# Enable Swap
SWAPON=$(cat <<EOF
#!/bin/bash
sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=2048
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1
EOF
)
echo "${SWAPON}" > $HOME/swapon.sh

chmod +x $HOME/swapon.sh

sudo $HOME/swapon.sh

# restart service
sudo service apache2 restart
sudo service mysql restart
