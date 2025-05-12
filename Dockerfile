# From https://github.com/juliusknorr/nextcloud-docker-dev/blob/master/docker/Dockerfile.php81
FROM ghcr.io/juliusknorr/nextcloud-dev-php81

# Get other dependencies
RUN apt-get update; \
    apt-get install -y --no-install-recommends \
        openssl \
        nano \
        openssh-client \
        unzip \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Generate self signed certificate
RUN mkdir -p /certs && \
    cd /certs && \
    openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj "/C=DE/ST=BE/L=Local/O=Dev/CN=localhost" -keyout ./ssl.key -out ./ssl.crt && \
    chmod -R +r ./

# Remove default ports
RUN rm /etc/apache2/ports.conf; \
    sed -s -i -e "s/Include ports.conf//" /etc/apache2/apache2.conf; \
    sed -i "/^Listen /d" /etc/apache2/apache2.conf

# Enable apache mods
RUN a2enmod rewrite \
    headers \
    proxy \
    proxy_fcgi \
    setenvif \
    env \
    mime \
    dir \
    authz_core \
    alias \
    ssl

# Copy apache conf
COPY apache.conf /etc/apache2/sites-available/

# Adjust apache sites
RUN a2dissite 000-default && \
    a2dissite default-ssl && \
    a2ensite apache.conf

# Copy start script
COPY cron.sh /cron.sh
COPY start.sh /usr/bin/

# Replace occ script with fixed version
COPY occ /usr/local/bin/occ

# Make scripts executable
RUN chmod +x /usr/bin/start.sh; \
    chmod +x /usr/local/bin/occ; \
    chmod +x /cron.sh

# Correctly set rights and add directories
RUN cd /var/www; \
    rm -rf nextcloud; \
    mkdir nextcloud; \
    chown www-data:www-data -R /var/www

# Switch to www-data user to make container more secure
USER www-data

# Install NVM (Hydrogen = v18, Iron = v20, Jod = v22)
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
    && export NVM_DIR="/var/www/.nvm" \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install lts/jod \
    && nvm install-latest-npm \
    && nvm install lts/hydrogen \
    && nvm install-latest-npm \
    && nvm install lts/iron \
    && nvm install-latest-npm

ENV APACHE_PORT 443

# Set entrypoint
ENTRYPOINT  ["start.sh"]

# Set CMD
CMD ["apache2-foreground"]

