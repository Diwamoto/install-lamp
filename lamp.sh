# lamp installスクリプト
# debian || ubuntu 環境を想定しています

echo ' __________________________'
echo '|    __                    |'
echo '|   / /___ _____ ___  ____ |'
echo '|  / / __ `/ __ `__ \/ __ \|'
echo '| / / /_/ / / / / / / /_/ /|'
echo '|/_/\__,_/_/ /_/ /_/ .___/ |'
echo '|                 /_/      |'
echo ' --------------------------'
echo 'lamp環境を構築します。'
echo '環境変数を確認しています...'
sleep 3
PHP_VERSION='7.3'
SSH_PORT='10022'
DOMAIN=''
WWW_ROOT=''
MYSQL_ROOT_PASSWORD='root'
MYSQL_USER_NAME='user'
MYSQL_USER_PASSWORD='password'
PMA_INSTALL_FLG=''
PMA_VERSION='4.9.5'
SSL_INSTALL_FLG=''
SSL_ROOT_EMAIL=''
if [ -z "$PHP_VERSION" ]; then
	echo "[\033[31mERROR\033[m] PHPのバージョンが設定されていません。終了します..."
	exit 1
else
	echo "PHP_VERSION...$PHP_VERSION...ok!"
fi
if [ -z "$SSH_PORT" ]; then
	echo "[\033[31mERROR\033[m] sshのポート番号が設定されていません。終了します..."
	exit 1
else
	echo "SSH_PORT...$SSH_PORT...ok!"
fi
if [ -z "$DOMAIN" ]; then
	echo "[\033[33mWARNING\033[m] ドメインが設定されていません。後ほど個別で/etc/apache2/sites-available/vhost.confを確認してください"
	exit 1
else
	echo "DOMAIN...$DOMAIN...ok!"
fi
if [ -z "$WWW_ROOT" ]; then
	echo "[\033[31mERROR\033[m] ドキュメントルートが設定されていません。"
	exit 1
else
	echo "WWW_ROOT...$WWW_ROOT...ok!"
fi

sudo apt-get update
sudo apt-get upgrade -y

# 必要パッケージのインストール
echo "apacheをインストールします..."
sudo apt-get install -y apache2 mysql-server mysql-client git vim software-properties-common curl wget gnupg2 ca-certificates lsb-release apt-transport-https
sudo chmod -R 777 /var/www/html
sudo chown -R root:www-data /var/www/html
echo "ok."

# apache2のモジュール有効化
echo "モジュールを有効化します..."
sleep 3
sudo a2enmod rewrite vhost_alias ssl
echo "ok."

# mysqlの設定
echo "mysqlをインストールします..."
sleep 3
sudo mysql_secure_installation
sudo systemctl restart mysql
echo "ok."

echo "mysqlのユーザを作成中"
sleep 3
# rootにsudoなしでログインできるようにする
sudo mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"
# userアカウントを生成する
sudo mysql -uroot -e "grant all privileges on *.* to '$MYSQL_USER_NAME'@'%' identified by '$MYSQL_USER_PASSWORD' with grant option;"
sudo mysql -uroot -e "FLUSH PRIVILEGES;"
sudo mysql -uroot -e "SET GLOBAL sql_mode = '';"
echo "ok."


# phpのインストール
echo "phpをインストールします..."
sleep 3
wget https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php7.list
sudo apt-key add apt.gpg
sudo apt-get update
sudo apt install -y php$PHP_VERSION php$PHP_VERSION-cli php$PHP_VERSION-common \
libapache2-mod-php$PHP_VERSION php$PHP_VERSION-mysql php$PHP_VERSION-gd php$PHP_VERSION-zip php$PHP_VERSION-mbstring \
php$PHP_VERSION-intl
echo "ok."

# vhost.confの設定
echo "apacheの詳細設定を行います..."
sleep 3
sudo touch /etc/apache2/sites-available/vhost.conf
sudo chmod 777 /etc/apache2/sites-available/vhost.conf
sudo echo -e "NameVirtualHost *:80\n\n" > /etc/apache2/sites-available/vhost.conf
sudo echo -e "<VirtualHost *:80>" >> /etc/apache2/sites-available/vhost.conf
sudo echo -e "	ServerAlias $DOMAIN" >> /etc/apache2/sites-available/vhost.conf
sudo echo -e "	DocumentRoot "$WWW_ROOT"" >> /etc/apache2/sites-available/vhost.conf
sudo echo -e "	<Directory "/var/www/html">" >> /etc/apache2/sites-available/vhost.conf
sudo echo -e "		AllowOverride All" >> /etc/apache2/sites-available/vhost.conf
sudo echo -e "	</Directory>" >> /etc/apache2/sites-available/vhost.conf
sudo echo -e "</VirtualHost>" >> /etc/apache2/sites-available/vhost.conf
sudo a2ensite vhost

# apache2.confの設定
sudo chmod 777 /etc/apache2/apache2.conf
sudo echo -e "<IfModule dir_module>" >> /etc/apache2/apache2.conf
sudo echo -e "	DirectoryIndex index.php index.html" >> /etc/apache2/apache2.conf
sudo echo -e "</IfModule>" >> /etc/apache2/apache2.conf
sudo systemctl restart apache2
echo "ok."

# port番号の変更、別途サーバーのファイアウォール設定が必要
echo "sshのポート番号を$SSH_PORTに変更します..."
sleep 3
sudo sed -i -e "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
sudo systemctl restart sshd
echo "ok."

# phpmyadminをインストールするかどうか
echo "phpmyadminをインストールしますか? [Y/n]"
while [ -z "$PMA_INSTALL_FLG" ]
do
	read input
	if [ -z $input ] ; then
		echo "yes または no を入力して下さい."
	elif [ $input = 'yes' ] || [ $input = 'YES' ] || [ $input = 'y' ] || [ $input = 'Y' ]; then
		# install
		PMA_INSTALL_FLG="true"
		sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD mysql -e "update user set plugin='' where user='root'; "
		sudo mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "flush privileges;"
		sudo wget -P /var/www/html https://files.phpmyadmin.net/phpMyAdmin/$PMA_VERSION/phpMyAdmin-$PMA_VERSION-all-languages.tar.gz -O /var/www/html/phpmyadmin.tar.gz
		cd /var/www/html
		tar xzf /var/www/html/phpmyadmin.tar.gz
		sudo mv /var/www/html/phpMyAdmin-$PMA_VERSION-all-languages /var/www/html/phpmyadmin
		cp /var/www/html/phpmyadmin/config.sample.inc.php /var/www/html/phpmyadmin/config.inc.php
		sudo chmod 640 /var/www/html/phpmyadmin/config.inc.php
		sudo chown root:www-data /var/www/html/phpmyadmin/config.inc.php
		## sudo sed -e "/\$cfg['blowfish_secret'].=.''; \/\*.YOU.MUST.FILL.IN.THIS.FOR.COOKIE.AUTH! \*\//\$cfg['blowfish_secret'] = 'lampwithubuntu'/" phpmyadmin/config.inc.php
		sudo touch /etc/apache2/sites-available/pma.conf
		sudo chmod 777 /etc/apache2/sites-available/pma.conf
		sudo echo -e "<VirtualHost *:80>" > /etc/apache2/sites-available/pma.conf
		sudo echo -e "	ServerAlias pma.$DOMAIN" >> /etc/apache2/sites-available/pma.conf
		sudo echo -e "	DocumentRoot "/var/www/html/phpmyadmin"" >> /etc/apache2/sites-available/pma.conf
		sudo echo -e "	<Directory "/var/www/html">" >> /etc/apache2/sites-available/pma.conf
		sudo echo -e "		AllowOverride All" >> /etc/apache2/sites-available/pma.conf
		sudo echo -e "	</Directory>" >> /etc/apache2/sites-available/pma.conf
		sudo echo -e "</VirtualHost>" >> /etc/apache2/sites-available/pma.conf
		sudo a2ensite pma
		rm -f phpmyadmin.tar.gz
		sudo systemctl restart apache2
	elif [ $input = 'no' ] || [ $input = 'NO' ] || [ $input = 'n' ] || [ $input = 'N' ]; then
		PMA_INSTALL_FLG="false"
	else
		echo "yes または no を入力して下さい."
	fi
done

# sslの設定をするかどうか（Let's Encrypt）
echo "sslを設定しますか? [Y/n]"
while [ -z "$SSL_INSTALL_FLG" ]
do
	read input
	if [ -z $input ] ; then
		echo "yes または no を入力して下さい."
	elif [ $input = 'yes' ] || [ $input = 'YES' ] || [ $input = 'y' ] || [ $input = 'Y' ]; then
		# certbotのinstall
		sudo echo -e "deb http://mirrors.digitalocean.com/debian buster-backports main" >> /etc/apt/sources.list
		sudo echo -e "deb-src http://mirrors.digitalocean.com/debian buster-backports main" >> /etc/apt/sources.list
		sudo apt update
		sudo apt install -y python-certbot-apache -t buster-backports
		sudo certbot --apache -d $DOMAIN
		sudo sed -i -e "s/DocumentRoot \/var\/www\/html\//                DocumentRoot $WWW_ROOT/g" /etc/apache2/sites-available/default-ssl.conf
		sudo sed -i '5a                 <Directory "/var/www/html">' /etc/apache2/sites-available/default-ssl.conf
		sudo sed -i '6a                                 AllowOverride All' /etc/apache2/sites-available/default-ssl.conf
		sudo sed -i '7a                 </Directory>' /etc/apache2/sites-available/default-ssl.conf
		sudo systemctl restart apache2
		SSL_INSTALL_FLG="true"
	elif [ $input = 'no' ] || [ $input = 'NO' ] || [ $input = 'n' ] || [ $input = 'N' ]; then
		SSL_INSTALL_FLG="false"
	else
		echo "yes または no を入力して下さい."
	fi
done
echo "インストールが完了しました。"
