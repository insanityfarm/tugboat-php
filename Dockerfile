# ============================
# PULL OFFICIAL PHP REPO
# ============================
FROM php:7.0-apache

# ===============================================
# ENVIRONMENT VARS
# ================================================
ENV ROOT_USER_PASS=dev
ENV DEV_USER_PASS=dev

# ===============================================
# FIX PERMISSIONS / ADD DEV USER / SET PASSWORDS
# ================================================
RUN usermod -u 1000 www-data
RUN groupmod -g 1000 www-data
RUN useradd -p dev -ms /bin/bash -d /var/www/html dev
RUN usermod -aG www-data dev
RUN usermod -aG dev www-data
RUN chown -R dev:dev /var/www/html

# ============================
# ADD APT SOURCES
# ============================
# RUN echo "deb http://ftp.debian.org/debian jessie-backports main" | tee -a /etc/apt/sources.list

# ============================
# UPDATE/UPGRADE APT PACKAGES
# ============================
RUN apt-get update
RUN apt-get upgrade -y

# ============================
# UPDATE/UPGRADE APT PACKAGES
# ============================
RUN apt-get install -y \
    build-essential \
    apt-utils \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng12-dev \
    libpq-dev \
	zlib1g-dev libicu-dev g++ \
    sqlite3 libsqlite3-dev \
    libxml2-dev \
    libssh2-1-dev \
    libssh2-1 \
	libxslt-dev

RUN apt-get install -y git vim cron htop zip unzip pwgen curl wget chkconfig ruby rubygems ruby-dev screen openssl openssh-server

# ============================
# CONFIG PHP EXTENSIONS
# ============================
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-install gd
RUN docker-php-ext-install iconv
RUN docker-php-ext-install mcrypt
RUN docker-php-ext-install mbstring
RUN docker-php-ext-install mysqli
RUN docker-php-ext-install pgsql
RUN docker-php-ext-install pdo_mysql pdo_pgsql pdo_sqlite
RUN docker-php-ext-install soap
RUN docker-php-ext-install tokenizer
RUN docker-php-ext-install zip
RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
RUN docker-php-ext-install xsl
RUN docker-php-ext-configure bcmath
RUN docker-php-ext-install bcmath
RUN pecl install redis-3.1.0 \
    && docker-php-ext-enable redis

# ============================
# PECL SSH2 library
# ============================
RUN pecl install ssh2-1.0

# ============================
# xDebug
# ============================
RUN pecl install xdebug-2.5.0 \
    && docker-php-ext-enable redis xdebug

# ============================
# Setup Composer
# ============================
RUN php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
RUN php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('/tmp/composer-setup.php'); } echo PHP_EOL;"
RUN php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer


# ============================
# Create SSL Cert
# ============================
RUN mkdir /etc/apache2/ssl

RUN openssl genrsa -des3 -passout pass:x -out server.pass.key 2048
RUN openssl rsa -passin pass:x -in server.pass.key -out /etc/apache2/ssl/apache.key
RUN rm server.pass.key
RUN openssl req -new -key /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/server.csr  \
  -subj "/C=US/ST=Washington/L=SEA/O=coolblue/OU=IT Department/CN=localhost"
RUN openssl x509 -req -days 365 -in /etc/apache2/ssl/server.csr -signkey /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.crt
RUN chmod 600 /etc/apache2/ssl/*

# ============================
# Configure Apache/PHP
# ============================
RUN rm /etc/apache2/sites-enabled/*
COPY config/apache/vhost.conf /etc/apache2/sites-available/default.conf
COPY config/apache/vhost-ssl.conf /etc/apache2/sites-available/default-ssl.conf
COPY config/php/php.ini /usr/local/etc/php/

RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod proxy
RUN a2enmod headers
RUN a2enmod expires

# ============================
# Enable Sites
# ============================
RUN a2ensite default-ssl
RUN a2ensite default

# ============================
# CONFIG OPENSSH / START SERVICE
# ============================
COPY config/ssh/sshd_config /etc/ssh/sshd_config
RUN service ssh start

# ============================
# MHSendmail CONFIG
# ============================
RUN DEBIAN_FRONTEND=noninteractive apt-get -y install golang-go
RUN mkdir /opt/go && export GOPATH=/opt/go && go get github.com/mailhog/mhsendmail


# ============================
# Startup Script
# ============================
ADD scripts/run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh
CMD ["/usr/local/bin/run.sh"]
