#!/bin/bash
#
# This is inspired and mostly taken from
# Original author
# @author: Seb Dangerfield
# http://www.sebdangerfield.me.uk/?p=513
# Created:   11/08/2011
# Modified:   07/01/2012
# Modified:   27/11/2012
#
# Modified by me (David Lonjon) to suit the need for my project
# This is focused for wordpress vhost
# Modified: 04/10/2014

# Modify the following to match your system
NGINX_CONFIG='/etc/nginx/sites-available'
NGINX_SITES_ENABLED='/etc/nginx/sites-enabled'
PHP_INI_DIR='/etc/php5/fpm/pool.d'
WEB_SERVER_GROUP='www-data'
FTP_SERVER_GROUP='ftp-access'
NGINX_INIT='/etc/init.d/nginx'
PHP_FPM_INIT='/etc/init.d/php5-fpm'
WP_VHOST_TEMPLATE='/etc/nginx/templates/wordpress-example.com.template'
PHP_FPM_POOL_TEMPLATE='/etc/nginx/templates/pool.conf.template'
FPM_SERVERS_DEFAULT='2'
MIN_SERVERS_DEFAULT='1'
MAX_SERVERS_DEFAULT='3'

# --------------END
SED=`which sed`

if [ -z $1 ]; then
	echo "No domain name given"
	exit 1
fi
DOMAIN=$1

# check the domain is valid!
PATTERN="^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$";
if [[ "$DOMAIN" =~ $PATTERN ]]; then
	DOMAIN=`echo $DOMAIN | tr '[A-Z]' '[a-z]'`
	echo "Creating hosting for:" $DOMAIN
else
	echo "invalid domain name"
	exit 1
fi

# Create a new user!
echo "Please specify the username for this site?"
read USERNAME
HOME_DIR=$USERNAME
adduser $USERNAME

echo "Would you like to change to web root directory (y/n)?"
read CHANGEROOT
if [ $CHANGEROOT == "y" ]; then
	echo "Enter the new web root dir (after the public_html/) otherwise it will be /public_html/$DOMAIN"
	read DIR
	PUBLIC_HTML_DIR='/public_html/'$DIR
else
	PUBLIC_HTML_DIR='/public_html/'$DOMAIN
fi

# Now we need to copy the virtual host template
CONFIG=$NGINX_CONFIG/$DOMAIN
cp $WP_VHOST_TEMPLATE $CONFIG
$SED -i "s/@@HOSTNAME@@/$DOMAIN/g" $CONFIG
$SED -i "s#@@PATH@@#\/home\/"$USERNAME$PUBLIC_HTML_DIR"#g" $CONFIG
$SED -i "s/@@LOG_PATH@@/\/home\/$USERNAME\/_logs/g" $CONFIG
$SED -i "s#@@SOCKET@@#/var/run/"$USERNAME"_fpm.sock#g" $CONFIG

echo "How many FPM servers would you like (Press enter for default: $FPM_SERVERS_DEFAULT):"
read FPM_SERVERS
if [ -z "$FPM_SERVERS" ]; then
    FPM_SERVERS = FPM_SERVERS_DEFAULT
fi
echo "Min number of FPM servers would you like (Press enter for default: $MIN_SERVERS_DEFAULT):"
read MIN_SERVERS
if [ -z "$MIN_SERVERS" ]; then
    MIN_SERVERS = MIN_SERVERS_DEFAULT
fi
echo "Max number of FPM servers would you like (Press enter for default: $MAX_SERVERS_DEFAULT):"
read MAX_SERVERS
if [ -z "$MAX_SERVERS" ]; then
    MAX_SERVERS = MAX_SERVERS_DEFAULT
fi
# Now we need to create a new php fpm pool config
FPMCONF="$PHP_INI_DIR/$DOMAIN.pool.conf"

cp $PHP_FPM_POOL_TEMPLATE $FPMCONF

$SED -i "s/@@USER@@/$USERNAME/g" $FPMCONF
$SED -i "s/@@HOME_DIR@@/\/home\/$USERNAME/g" $FPMCONF
$SED -i "s/@@START_SERVERS@@/$FPM_SERVERS/g" $FPMCONF
$SED -i "s/@@MIN_SERVERS@@/$MIN_SERVERS/g" $FPMCONF
$SED -i "s/@@MAX_SERVERS@@/$MAX_SERVERS/g" $FPMCONF
MAX_CHILDS=$((MAX_SERVERS+START_SERVERS))
$SED -i "s/@@MAX_CHILDS@@/$MAX_CHILDS/g" $FPMCONF

usermod -aG $USERNAME $WEB_SERVER_GROUP
usermod -aG $USERNAME $FTP_SERVER_GROUP
chmod g+rx /home/$HOME_DIR
chmod 600 $CONFIG

ln -s $CONFIG $NGINX_SITES_ENABLED/$DOMAIN

# set file perms and create required dirs!
mkdir -p /home/$HOME_DIR$PUBLIC_HTML_DIR
mkdir /home/$HOME_DIR/_logs
mkdir /home/$HOME_DIR/_sessions
chmod 750 /home/$HOME_DIR -R
chmod 700 /home/$HOME_DIR/_sessions
chmod 770 /home/$HOME_DIR/_logs
chmod 750 /home/$HOME_DIR$PUBLIC_HTML_DIR
chown $USERNAME:$USERNAME /home/$HOME_DIR/ -R

$NGINX_INIT reload
$PHP_FPM_INIT restart

echo -e "\nSite Created for $DOMAIN with PHP support"

