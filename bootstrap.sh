#!/usr/bin/env bash

SCRIPT_LOCATION=$(readlink -f "$0")
SCRIPT_PATH=$(dirname ${SCRIPT_LOCATION})
PROJECT_PATH="${PROJECT_PATH:-$SCRIPT_PATH}"
NGINX_VERSION=1.17.9
NGINX_RTMP_MODULE_VERSION=1.2.7
NGINX_PATH=/usr/sbin/nginx                              # Make sure to change the init file too
NGINX_CONFIG_WATCHER_PATH=/usr/local/nginx/conf-watcher # Make sure to change the init file too

echo "Script location: ${SCRIPT_LOCATION}"
echo "Project path: ${PROJECT_PATH}"
echo "Nginx version: ${NGINX_VERSION}"
echo "Nginx RTPM module version: ${NGINX_RTMP_MODULE_VERSION}"
echo "Nginx path: ${NGINX_PATH}"

# Check that Nginx is not already installed
if [ ! -e $NGINX_PATH ]; then
    echo "Nginx server doesn't exist yet."

    # Add an APT repository to install FFMpeg (used to encode video stream)
    add-apt-repository ppa:mc3man/$(cat /etc/lsb-release | grep -oPe "(?<=DISTRIB_CODENAME=)(.*)")-media
    
    # Make sure the new APT repository is taken into account
    apt-get update
    
    # Install requirements
    apt-get install -y build-essential libpcre3 libpcre3-dev openssl libssl-dev unzip libaio1 ffmpeg zlib1g-dev stunnel4
    
    # Download Nginx server
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
    
    # Unzip the downloaded tarball
    tar -zxvf nginx-${NGINX_VERSION}.tar.gz
    
    # Download Nginx's RTMP module used for live broadcasting
    wget https://github.com/winshining/nginx-http-flv-module/archive/v${NGINX_RTMP_MODULE_VERSION}.zip
    # Unzip the zip file
    unzip v${NGINX_RTMP_MODULE_VERSION}.zip
    
    # Build Nginx with the RTMP module included
    cd nginx-${NGINX_VERSION}
    ./configure --with-http_ssl_module --add-module=../nginx-http-flv-module-${NGINX_RTMP_MODULE_VERSION}
    make
    make install
    cd ..

    # Remove downloaded archives
    rm v${NGINX_RTMP_MODULE_VERSION}.zip nginx-${NGINX_VERSION}.tar.gz

    # Remove folder used to build Nginx
    rm -rf nginx-${NGINX_VERSION} nginx-rtmp-module-master

    # Create a symlink to use Nginx as a command
    ln -fs /usr/local/nginx/sbin/nginx $NGINX_PATH

    # Create symlinks for Nginx config files
    rm -rf /usr/local/nginx/html
    ln -fs ${PROJECT_PATH}/nginx/html /usr/local/nginx/
    ln -fs ${PROJECT_PATH}/nginx/conf/nginx.conf /usr/local/nginx/conf
    ln -fs ${PROJECT_PATH}/nginx/conf/mime.types /usr/local/nginx/conf

    # Create missing directory
    if [ ! -e /usr/local/nginx/logs ]; then
        mkdir /usr/local/nginx/logs
    fi
    # Make sure Nginx HTML files will be readable online
    chmod 755 ${PROJECT_PATH}/nginx/html/*

    # Create new aliases
    echo "alias gonginx='cd /usr/local/nginx'" >> ~/.bashrc

    # Copy Nginx scripts
    cp -rf ${PROJECT_PATH}/nginx/script/ /usr/local/nginx

    # Copy Nginx script to launch Nginx at startup
    cp -f ${PROJECT_PATH}/nginx/init/nginx /etc/init.d/
    
    # Make sure that the script uses Unix line endings
    sed -i 's/\r//' /etc/init.d/nginx
    sed -i 's/\r//' /usr/local/nginx/script/restart.sh

    # Make sure the scripts can be executed 
    chmod +x /etc/init.d/nginx
    chmod +x /usr/local/nginx/script/restart.sh
    
    update-rc.d nginx defaults
    
    # Copy stunnel config
    cp -f ${PROJECT_PATH}/stunnel/stunnel.conf /etc/stunnel
fi

if [ ! -e $NGINX_CONFIG_WATCHER_PATH ]; then
    echo "Nginx's configuration watcher doesn't exist yet."

    # Install Node JS and NPM
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
	apt-get install -y nodejs # nodejs-legacy
	
    # Install forever
    npm install forever -g

    # Copy the Nginx config file watcher script
    cp -rf ${PROJECT_PATH}/nodejs/nginx-conf-watcher ${NGINX_CONFIG_WATCHER_PATH}

    # Copy nginx-conf-watcher to watch Nginx config file at startup
    cp -f ${PROJECT_PATH}/nginx/init/nginx-conf-watcher /etc/init.d/

    # Make sure that the script use Unix line endings
    sed -i 's/\r//' /etc/init.d/nginx-conf-watcher
        
    # Make sure the scripts can be executed 
    chmod +x /etc/init.d/nginx-conf-watcher
    
    update-rc.d nginx-conf-watcher defaults
fi
systemctl start stunnel4.service
systemctl status stunnel4.service
/etc/init.d/nginx start
/etc/init.d/nginx-conf-watcher start
