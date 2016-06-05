#!/bin/bash
#######################################
# Esteban Monge
# emonge@gbm.net
# Version: 0.5
#######################################
# Modified: 10/09/15
# Update Nagios to 4.1 
# Add support to RAMDisk
# Add SSH config file
#######################################

# Definicion de variables
IP=`hostname -I`
WORKDIR=`pwd`

# Configuracion y actualizacion de repositorios
cp /etc/apt/sources.list /etc/apt/sources.list.BAK
cp sources.list /etc/apt/
apt-get update

# Instalacion de dependencias

echo "Instalando Dependencias"

apt-get -y --force-yes install sudo alien vim sysstat mysql-server links2 php5 php5-cgi php5-mysql php5-gd libgd2-xpm-dev snmp libsnmp-perl libnet-snmp-perl libsnmp-session-perl unzip rrdtool libwww-perl librrdtool-oo-perl libmysql++-dev php-gettext php-xml-parser graphviz sqlite3 php5-sqlite libssl-dev build-essential openssh-server openssl links2 libcrypt-des-perl libconfig-inifiles-perl libdigest-hmac-perl libdigest-sha-perl libconfig-yaml-perl rsync apache2 libapache2-mod-php5 mcrypt libmcrypt-dev php5-curl libssh2-php sysstat libarray-unique-perl libfile-slurp-perl liblist-moreutils-perl libnagios-plugin-perl libnumber-format-perl libreadonly-perl ntpdate snmp-mibs-downloader comerr-dev krb5-multidev libclass-methodmaker-perl libconvert-units-perl libcrypt-ssleay-perl libcurl4-openssl-dev libelf1 libidn11-dev libkrb5-dev libldap2-dev liblua5.1-0 libnet-ssleay-perl libnspr4-0d libnss3-1d librpm3 librpmbuild3 librpmio3 libssh2-1-dev libxml-parser-perl libxml-perl rpm rpm-common rpm2cpio libxml2-dev libmath-calc-units-perl libxml-perl libclass-methodmaker-perl libnet-ssleay-perl libcrypt-ssleay-perl libconvert-units-perl rpm libcurl4-openssl-dev libxml2-dev libconfuse-dev libev-dev thruk

pear install HTML_Template_IT

echo "Refrescando librerias"

ldconfig

# Se habilitan modulos en apache

echo "Habilitando modulos en Apache"

a2enmod auth_digest ssl rewrite cgi
a2ensite default-ssl

sed -i -- "s/;date.timezone =/date.timezone = America\/Costa_Rica/g" /etc/php5/apache2/php.ini

#echo "Configurando Apache"
#cp /etc/php5/conf.d/suhosin.ini /etc/php5/conf.d/suhosin.ini.BAK
#cp suhosin.ini /etc/php5/conf.d/
#cp /etc/php5/apache2/php.ini /etc/php5/apache2/php.ini.BAK
#cp php.ini /etc/php5/apache2/

# Se agrega el usuario para Nagios

echo "Se agrega nuevo usuario Nagios"

useradd  -p $(perl -e'print crypt("manager", "aa")') -m -s /bin/bash nagios
/usr/sbin/groupadd nagcmd
/usr/sbin/usermod -a -G nagcmd nagios
/usr/sbin/usermod -a -G nagcmd www-data

# Crear archivo de configuration para VMWare
touch /etc/*-release
echo "ubuntu" >> /etc/*-release

# Comienza la configuracion, compilacion e instalacion de Nagios Core

echo "Compilando Nagios Core"

tar zxvf nagios-4.1.1.tar.gz
cd nagios-4.1.1 
./configure --with-command-group=nagcmd
cp sample-config/httpd.conf /etc/apache2/conf-available/nagios.conf
make all
make install
make install-init
make install-config
make install-commandmode

echo "Se realizan algunas configuraciones para Nagios"

# Se instala el archivo de configuracion de Apache para Nagios Core
cd ../

sed -i -- "s/AuthType Basic/AuthType Digest/g" /etc/apache2/conf-available/nagios.conf
sed -i -- "s/Nagios Access/Control IT/g" /etc/apache2/conf-available/nagios.conf

a2enconf nagios

#cp /etc/apache2/conf.d/nagios.conf /etc/apache2/conf.d/nagios.conf.BAK
#cp nagios.conf /etc/apache2/conf.d/
#cp /etc/init.d/nagios /etc/init.d/nagios.BAK
#cp nagios.init.d /etc/init.d/nagios
cp ocsp-ng /etc/init.d/ocsp-ng
cp ocsp_sweeper.pl /usr/local/nagios/bin
cp send_nsca-ng.cfg /usr/local/etc/send_nsca.cfg
cd /etc/init.d/
update-rc.d nagios defaults
update-rc.d nagios enable
update-rc.d ocsp-ng defaults
update-rc.d ocsp-ng enable

# Instalacion script sincronizacion hora


cd $WORKDIR

#cp synchronize.sh /opt/synchronize.sh
#chmod +x /opt/synchronize.sh
cp restart_ocsp.sh /opt/restart_ocsp.sh
chmod +x /opt/restart_ocsp.sh

#echo "# Syncronizes the time" >> /etc/crontab
#echo "*/15 *  * * *   root    /opt/synchronize.sh" >> /etc/crontab
#echo "" >> /etc/crontab
echo "# Restart OCSP Sweeper" >> /etc/crontab
echo "00 00 * * * /opt/restart_ocsp.sh" >> /etc/crontab
echo "" >> /etc/crontab

# Se agrega el usuario nagiosadmin mediante htdigest

(echo -n "nagiosadmin:Control IT:" && echo -n "nagiosadmin:Control IT:manager" | md5sum - | cut -d' ' -f1) >> /usr/local/nagios/etc/htpasswd.users

#Comienza la configuracion, compilacion e instalacion de Nagios Plugins

echo "Compilando Nagios Plugins"
tar zxvf nagios-plugins-2.1.1.tar.gz
cd nagios-plugins-2.1.1
./configure --with-nagios-user=nagios --with-nagios-group=nagios --enable-perl-modules=yes --enable-extra-opts=yes
make
make install

cd ../

tar zxvf nrpe-2.15.tar.gz
cd nrpe-2.15
./configure --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
make all
make install-plugin

cd ../

#Instalando plugins extra
cp extraplugins.tar.gz /usr/local/nagios/libexec/
cd /usr/local/nagios/libexec/
tar -zxvf extraplugins.tar.gz
mv extraplugins/* ./

cd $WORKDIR

#Instalando eventhandler adicionales
mkdir /usr/local/nagios/libexec/eventhandlers
cp submit_check_result /usr/local/nagios/libexec/eventhandlers
cp submit_host_result /usr/local/nagios/libexec/eventhandlers
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers

# Comienza la configuracion, compilacion e instalacion de NSCA

echo "Compilando Nagios Service Check Acceptor NSCA"

tar zxvf nsca-2.9.1.tar.gz
cd nsca-2.9.1
./configure
make all
cp src/nsca /usr/local/nagios/bin/
cp src/send_nsca /usr/local/nagios/bin/
cp sample-config/send_nsca.cfg /usr/local/nagios/etc/
cp /usr/local/nagios/etc/nsca.cfg /usr/local/nagios/etc/nsca.cfg.$(date '+%s')

cd ../

cat nsca.cfg | sed "s/#server_address=192.168.1.1/server_address=$IP/g" > /usr/local/nagios/etc/nsca.cfg
cp nsca /etc/init.d/
cd /etc/init.d/
update-rc.d nsca defaults
update-rc.d nsca enable

cd $WORKDIR
cp send_nsca.cfg /usr/local/nagios/etc/


tar zxvf nsca-ng-1.4.tar.gz
cd nsca-ng-1.4
./configure --enable-server
make
make install
cp contrib/nsca-ng.init /etc/init.d/nsca-ng
cd /etc/init.d
update-rc.d nsca-ng defaults
update-rc.d nsca-ng enable

cd $WORKDIR

# Comienza la configuracion, compilacion e instalacion de LiveStatus

echo "Compilando MK LiveStatus"

tar -zxvf mk-livestatus-1.2.6p10.tar.gz 
cd mk-livestatus-1.2.6p10
./configure --with-nagios4
make
make install

cd ../

# Comienza la configuracion, compilacion e instalacion de PNP4Nagios

echo "Compilando PNP4Nagios"

tar -zxvf pnp4nagios-0.6.25.tar.gz
cd pnp4nagios-0.6.25
./configure  --with-httpd-conf=/etc/apache2/conf-available
make all
make fullinstall

cd ../

sed -i -- "s/AuthType Basic/AuthType Digest/g" /etc/apache2/conf-available/pnp4nagios.conf
sed -i -- "s/Nagios Access/Control IT/g" /etc/apache2/conf-available/pnp4nagios.conf
rm /usr/local/pnp4nagios/share/install.php

cd /etc/init.d/
update-rc.d npcd defaults
update-rc.d npcd enable

cd $WORKDIR

# Comienza la instalacion de Nagvis

echo "Instalando Nagvis"

tar -zxvf nagvis-1.8.5.tar.gz
cd nagvis-1.8.5
./install.sh -n /usr/local/nagios -p /usr/local/nagvis -i mklivestatus -l unix:/usr/local/nagios/var/rw/live -q
cd ../
#cp nagvis.conf /etc/apache2/conf.d

service apache2 restart

# Comienza la instalacion de NagiosQL

tar -zxvf nagiosql_320sp2.tar.gz

cp -R nagiosql32/ /var/www/html/nagiosql
cp verify.php /var/www/html/nagiosql/admin

chown www-data:www-data /var/www/html/nagiosql/config
mkdir /etc/nagiosql
mkdir /etc/nagiosql/hosts
mkdir /etc/nagiosql/services
mkdir /etc/nagiosql/backup
mkdir /etc/nagiosql/backup/hosts
mkdir /etc/nagiosql/backup/services
cd /etc/nagiosql
touch contacttemplates.cfg contactgroups.cfg contacts.cfg timeperiods.cfg commands.cfg contacttemplates.cfg contactgroups.cfg contacts.cfg timeperiods.cfg commands.cfg hostgroups.cfg servicegroups.cfg hosttemplates.cfg servicetemplates.cfg servicedependencies.cfg hostdependencies.cfg serviceescalations.cfg hostdependencies.cfg hostescalations.cfg hostextinfo.cfg serviceextinfo.cfg
cd /usr/local/nagios
chgrp www-data etc/
chgrp www-data etc/nagios.cfg
chgrp www-data etc/cgi.cfg
chgrp www-data etc/resource.cfg
chmod 775 etc/
chmod 664 etc/nagios.cfg
chmod 664 etc/cgi.cfg
chmod 664 etc/resource.cfg
mkdir etc/import
chgrp www-data etc/import
chmod 775 etc/import
cd /etc/
chmod 6755 nagiosql/
chown www-data.nagios nagiosql/
cd nagiosql
chmod 6755 hosts
chmod 6755 services
chown www-data.nagios hosts
chown www-data.nagios services
chmod 6755 backup/
chmod 6755 backup/hosts
chmod 6755 backup/services
chown www-data.nagios backup/
chown www-data.nagios backup/hosts
chown www-data.nagios backup/services
chmod 644 *.cfg
chown www-data.nagios *.cfg
cd /usr/local/nagios/bin
chown nagios.www-data nagios
chmod 750 nagios
chgrp -R www-data /usr/local/nagios/var/spool

cd $WORKDIR

#Instalando RAMDisk

echo "Configurando RAMDisk"

mkdir /usr/local/nagios/var/ramdisk
mount -t tmpfs none /usr/local/nagios/var/ramdisk -o size=200m
chown nagios /usr/local/nagios/var/ramdisk
mount -t tmpfs none /usr/local/nagios/var/spool/checkresults -o size=100m
chown nagios /usr/local/nagios/var/spool/checkresults

echo " " >> /etc/fstab
echo "# Nagios RAM Disk" >> /etc/fstab
echo "tmpfs           /usr/local/nagios/var/ramdisk/  tmpfs   size=200m                0       0" >> /etc/fstab
echo "# Check Results for Nagios RAM Disk" >> /etc/fstab
echo "tmpfs           /usr/local/nagios/var/spool/checkresults  tmpfs size=100m        0       0" >> /etc/fstab

#Instalando el archivo de Nagios

echo "Instalando archivo de configuracion principal"

cp /usr/local/nagios/etc/nagios.cfg /usr/local/nagios/etc/nagios.cfg.BAK
cp nagios.cfg /usr/local/nagios/etc

#Instalando un archivo de configuracion personalizado de SSH

echo "Instalando el archivo de configuracion de SSH"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.BAK
cp sshd_config /etc/ssh

echo "Reinicio de servicios"

service apache2 restart

service nsca restart
service nsca-ng restart

service npcd restart

service nagios restart

service ocsp stop
service ocsp start

service ssh restart

read -p "Ingrese a su navegador e instale NagiosQL, por favor no modifique el nombre de la base de datos, al finalizar la instalación vuelva y presione una tecla para continuar"

cd $WORKDIR

mysql -u root -pmysqlmanager db_nagiosql_v32 < db_nagiosql_v32.sql

echo "Recuerde que se cambio la configuracion del SSH"

echo "Luego disfrute de Nagios"
