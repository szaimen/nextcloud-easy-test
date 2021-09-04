#!/bin/bash

# Handle empty server branch variable
if [ -z "$SERVER_BRANCH" ]; then
    export SERVER_BRANCH=master
fi

# Get latest changes
cd /var/www/html
git stash
git pull
if ! git checkout "$SERVER_BRANCH"; then
    echo "Could not get the '$SERVER_BRANCH' server branch. Doesn't seem to exist."
    exit 1
fi
git pull
git submodule update --init

# Install Nextcloud
if ! [ -f config/config.php ] \
&& ! php -f occ \
        maintenance:install \
        --database=sqlite \
        --admin-user=admin \
        --admin-pass=nextcloud; then
    echo "Failed to create the instance."
    exit 1
fi

# Set trusted domain if needed 
if [ -n "$TRUSTED_DOMAIN" ]; then
    if ! php -f occ config:system:set trusted_domains 1 --value="$TRUSTED_DOMAIN"; then
        echo "Could not set the trusted domain '$TRUSTED_DOMAIN'"
        exit 1
    fi
fi

# Install and enable apps
install_enable_app() {
BRANCH="$1"
APPID="$2"
if [ -n "$BRANCH" ]; then
    cd /var/www/html/apps
    if [ -d ./"$APPID" ]; then
        php -f ../occ app:disable "$APPID"
        rm -r ./"$APPID"
    fi
    if ! git clone https://github.com/nextcloud/"$APPID".git --branch "$BRANCH"; then
        echo "Could not clone the requested branch '$BRANCH' of the $APPID app. Does it exist?"
        exit 1
    fi
    cd ./"$APPID"
    if [ "$APPID" = maps ]; then
        if ! make build; then
            echo "Could not compile the maps app."
            exit 1
        fi
    else
        if ! make dev-setup || ! make build-js-production; then
            echo "Could not compile the $APPID app."
            exit 1
        fi
    fi
    cd /var/www/html
    if ! php -f occ app:enable "$APPID"; then
        echo "Could not enable the $APPID app."
        exit 1
    fi
fi
}

# Compatible apps
install_enable_app "$CALENDAR_BRANCH" calendar
install_enable_app "$CONTACTS_BRANCH" contacts
install_enable_app "$FIRSTRUNWIZARD_BRANCH" firstrunwizard
install_enable_app "$MAPS_BRANCH" maps
install_enable_app "$TALK_BRANCH" spreed
install_enable_app "$TASKS_BRANCH" tasks
install_enable_app "$TEXT_BRANCH" text
install_enable_app "$VIEWER_BRANCH" viewer

# Clear cache
cd /var/www/html
if ! php -f occ maintenance:repair; then
    echo "Could not clear the cache"
    exit 1
fi
