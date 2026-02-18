# From https://github.com/juliusknorr/nextcloud-docker-dev/blob/master/docker/php82/Dockerfile
FROM ghcr.io/juliusknorr/nextcloud-dev-php82

# Get other dependencies
RUN apt-get update; \
    apt-get install -y --no-install-recommends \
        openssl \
        ca-certificates \
        nano \
        openssh-client \
        unzip \
    ; \
    rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Copy server CNF (contains SAN for nextcloud.local)
COPY server.cnf /server.cnf

# Generate a certificate signed by a local CA and add CA to system trust
RUN set -eux; \
    mkdir -p /certs; \
    cd /certs; \
# Create a local CA
    openssl genrsa -out ca.key 4096; \
    openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 -subj "/C=DE/ST=BE/L=Local/O=Dev CA/CN=nextcloud-dev-ca" -out ca.crt; \
# Create server key and CSR with SAN for nextcloud.local
    openssl genrsa -out ssl.key 4096; \
    openssl req -new -key ssl.key -out server.csr -config /server.cnf; \
# Sign server CSR with the CA, including SAN extension
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ssl.crt -days 3650 -sha256 -extfile /server.cnf -extensions req_ext; \
# Install CA into the system trust store so host trusts the cert
    cp ca.crt /usr/local/share/ca-certificates/nextcloud-dev-ca.crt; \
    update-ca-certificates; \
    chmod -R +r /certs

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

# Install NVM (Iron = v20, Jod = v22, Krypton = v24)
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
    && export NVM_DIR="/var/www/.nvm" \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install lts/krypton \
    && nvm install-latest-npm \
    && nvm install lts/iron \
    && nvm install-latest-npm \
    && nvm install lts/jod \
    && nvm install-latest-npm

ENV APACHE_PORT 443

# Set entrypoint
ENTRYPOINT  ["start.sh"]

# Set CMD
CMD ["apache2-foreground"]
