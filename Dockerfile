# From https://github.com/juliushaertl/nextcloud-docker-dev/blob/master/docker/Dockerfile.php74
FROM ghcr.io/juliushaertl/nextcloud-dev-php74

# Get current npm
RUN curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -

# Get other dependencies
RUN apt-get update; \
    apt-get install -y --no-install-recommends \
        openssl \
        nano \
        openssh-client \
        nodejs \
    ; \
    rm -rf /var/lib/apt/lists/*

# Update NPM
RUN npm install -g npm

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
    a2ensite apache.conf && \
    service apache2 restart 

# Copy start script
COPY start.sh /usr/bin/
RUN chmod +x /usr/bin/start.sh

# Correctly set rights
RUN chown www-data:www-data -R /var/www

# Switch to www-data user to make container more secure
USER www-data

# Set entrypoint
ENTRYPOINT  ["start.sh"]

# Set CMD
CMD ["apache2-foreground"]

# Clone master branch of server
RUN cd /var/www/html && \
    rm -rf ./* && \
    git clone https://github.com/nextcloud/server.git .
