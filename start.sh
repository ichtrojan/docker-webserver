#!/bin/bash

# UPDATE THE WEBROOT IF REQUIRED.
if [[ ! -z "${WEBROOT}" ]] && [[ ! -z "${WEBROOT_PUBLIC}" ]]; then
    sed -i "s#root /var/www/public;#root ${WEBROOT_PUBLIC};#g" /etc/nginx/sites-available/default.conf
else
    export WEBROOT=/var/www
    export WEBROOT_PUBLIC=/var/www/public
fi

 # UPDATE THE INJECTED JS SCRIPT URL
if [[ ! -z "${CIROUE_URL}" ]]; then
    sed -i "s#http://127.0.0.1:8000#${CIROUE_URL}#g" /etc/nginx/sites-available/default.conf
fi

# # RUN KEY GENERATE
#if [[ ! -z "${GENERATE_KEY}" ]]; then
#    cd ${WEBROOT}
#    php artisan key:generate --ansi
#    cd -
#fi

#docker run -d -p 4488:80 --name=testapp -e "WEBROOT_PUBLIC=/var/www" -v $PWD:/var/www ciroue/notebook
# UPDATE COMPOSER PACKAGES ON BUILD.
## 💡 THIS MAY MAKE THE BUILD SLOWER BECAUSE IT HAS TO FETCH PACKAGES.
if [[ ! -z "${COMPOSER_DIRECTORY}" ]] && [[ "${COMPOSER_UPDATE_ON_BUILD}" == "1" ]]; then
    cd ${COMPOSER_DIRECTORY}
    composer update && composer dump-autoload -o
fi

# LARAVEL APPLICATION
if [[ "${LARAVEL_APP}" == "1" ]]; then
    # RUN LARAVEL MIGRATIONS ON BUILD.
    if [[ "${RUN_LARAVEL_MIGRATIONS_ON_BUILD}" == "1" ]]; then
        cd ${WEBROOT}
        php artisan migrate
    fi

    # LARAVEL SCHEDULER
    if [[ "${RUN_LARAVEL_SCHEDULER}" == "1" ]]; then
        echo '* * * * * cd /var/www && php artisan schedule:run >> /dev/null 2>&1' > /etc/crontabs/root
        crond
    fi
fi

# SYMLINK CONFIGURATION FILES.
ln -s /etc/php7/php.ini /etc/php7/conf.d/php.ini
ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# PRODUCTION LEVEL CONFIGURATION.
if [[ "${PRODUCTION}" == "1" ]]; then
    sed -i -e "s/;log_level = notice/log_level = warning/g" /etc/php7/php-fpm.conf
    sed -i -e "s/clear_env = no/clear_env = yes/g" /etc/php7/php-fpm.d/www.conf
    sed -i -e "s/display_errors = On/display_errors = Off/g" /etc/php7/php.ini
else
    sed -i -e "s/;log_level = notice/log_level = notice/g" /etc/php7/php-fpm.conf
    sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php7/php-fpm.conf
fi

# PHP & SERVER CONFIGURATIONS.
if [[ ! -z "${PHP_MEMORY_LIMIT}" ]]; then
    sed -i "s/memory_limit = 128M/memory_limit = ${PHP_MEMORY_LIMIT}M/g" /etc/php7/conf.d/php.ini
fi

if [ ! -z "${PHP_POST_MAX_SIZE}" ]; then
    sed -i "s/post_max_size = 50M/post_max_size = ${PHP_POST_MAX_SIZE}M/g" /etc/php7/conf.d/php.ini
fi

if [ ! -z "${PHP_UPLOAD_MAX_FILESIZE}" ]; then
    sed -i "s/upload_max_filesize = 10M/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE}M/g" /etc/php7/conf.d/php.ini
fi


find /etc/php7/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# START SUPERVISOR.
exec /usr/bin/supervisord -n -c /etc/supervisord.conf
