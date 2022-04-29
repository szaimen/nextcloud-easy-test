#!/bin/bash

# Function to show text in green
print_green() {
    local TEXT="$1"
    printf "%b%s%b\n" "\e[0;92m" "$TEXT" "\e[0m"
}

# Show how to reach the server
show_startup_info() {
    if [ -z "$TRUSTED_DOMAIN" ]; then
        print_green "The server should now be reachable via https://localhost:8443/"
    else
        print_green "The server should now be reachable via https://$TRUSTED_DOMAIN:8443/"
    fi
}

# Manual install: will skip everything and just start apache
manual_install() {
    if [ -n "$MANUAL_INSTALL" ]; then
        touch /var/www/server-completed
        show_startup_info
        exit 0
    fi
}

# version_greater A B returns whether A > B
version_greater() {
    [ "$(printf '%s\n' "$@" | sort -t '.' -n -k1,1 -k2,2 -k3,3 -k4,4 | head -n 1)" != "$1" ]
}

# Handle empty server branch variable
if [ -z "$SERVER_BRANCH" ]; then
    export SERVER_BRANCH="nextcloud:master"
fi

# Handle case that branch is present in nextcloud repo
if ! echo "$SERVER_BRANCH" | grep -q ':'; then
    export SERVER_BRANCH="nextcloud:$SERVER_BRANCH"
fi

# Get NVM code
export NVM_DIR="/var/www/.nvm"
. "$NVM_DIR/nvm.sh"

# Get latest changes
if ! [ -f /var/www/server-completed ]; then
    set -x
    FORK_OWNER="${SERVER_BRANCH%%:*}"
    FORK_BRANCH="${SERVER_BRANCH#*:}"
    set +x
    cd /var/www/nextcloud
    if ! git clone https://github.com/"$FORK_OWNER"/server.git --branch "$FORK_BRANCH" --single-branch --depth 1 .; then
        echo "Could not clone the requested server branch '$FORK_BRANCH' of '$FORK_OWNER'. Does it exist?"
        exit 1
    fi

    # Initiate submodules
    git submodule update --init

    # Allow to compile the server javascript
    if [ -n "$COMPILE_SERVER" ]; then
        set -x
        installed_version="$(php -r 'require "/var/www/nextcloud/version.php"; echo implode(".", $OC_Version);')"
        if version_greater "$installed_version" "24.0.0.0"; then
            echo "Compiling server..."
            if ! npm ci || ! npm run build --if-present; then
                echo "Could not compile server."
                exit 1
            fi
        else
            echo "Could not compile server because the version is not higher than 24.0.0"
            exit 1
        fi
        set +x
    fi

    # Manual install
    manual_install

    # Install Nextcloud
    if ! php -f occ \
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
    touch /var/www/server-completed
fi

# Manual install
manual_install

# Handle skeleton archive url
if [ -n "$SKELETON_ARCHIVE_URL" ] && ! [ -f "/var/www/skeleton-completed" ]; then
    set -x
    if ! curl -fsSL "$SKELETON_ARCHIVE_URL" -o /var/www/nextcloud/data/skeletondir.tar.gz; then
        echo "Could not get the sekeleton archive url"
        exit 1
    fi
    mkdir -p "/var/www/nextcloud/data/skeletondir"
    if ! tar -xf "/var/www/nextcloud/data/skeletondir.tar.gz" -C "/var/www/nextcloud/data/skeletondir"; then
        echo "Could not untar the archive. Is it a tar.gz archive?"
        exit 1
    fi
    if ! php -f occ config:system:set skeletondirectory --value="/var/www/nextcloud/data/skeletondir"; then
        echo "Could not set the skeletondir"
        exit 1
    fi
    if ! rm -r /var/www/nextcloud/data/admin/files/*; then
        echo "Could not remove the default admin files"
        exit 1
    fi
    if ! cp -R /var/www/nextcloud/data/skeletondir/* /var/www/nextcloud/data/admin/files/; then
        echo "Could not copy the files to the admin user"
        exit 1
    fi
    if ! php -f occ files:scan admin; then
        echo "Could not scan the new files for the admin user."
        exit 1
    fi
    set +x
    touch /var/www/skeleton-completed
fi

# Install and enable apps
install_enable_app() {

# Variables
local BRANCH="$1"
local APPID="$2"

# Logic
if [ -n "$BRANCH" ] && ! [ -f "/var/www/$APPID-completed" ]; then

    # Go into apps directory
    cd /var/www/nextcloud/apps

    # Remove app directory
    if [ -d ./"$APPID" ]; then
        php -f ../occ app:disable "$APPID"
        rm -r ./"$APPID"
    fi

    # Handle case that branch is present in nextcloud repo
    if ! echo "$BRANCH" | grep -q ':'; then
        BRANCH="nextcloud:$BRANCH"
    fi

    # Clone repo
    set -x
    local APP_OWNER="${BRANCH%%:*}"
    local APP_BRANCH="${BRANCH#*:}"
    set +x
    if ! git clone https://github.com/"$APP_OWNER"/"$APPID".git --branch "$APP_BRANCH" --single-branch --depth 1; then
        echo "Could not clone the requested branch '$APP_BRANCH' of the $APPID app of '$APP_OWNER'. Does it exist?"
        exit 1
    fi

    # Go into app directory
    cd ./"$APPID"
    
    # Handle node versions
    set -x
    if [ -f package.json ]; then
        local NODE_LINE=$(grep '"node":' package.json | head -1)
    fi
    if [ -n "$NODE_LINE" ] && echo "$NODE_LINE" | grep -q '>='; then
        local NODE_VERSION="$(echo "$NODE_LINE" | grep -oP '>=[0-9]+' | sed 's|>=||')"
        if [ -n "$NODE_VERSION" ] && [ "$NODE_VERSION" -gt 14 ]; then
            set +x
            if [ "$NODE_VERSION" -gt 16 ]; then
                echo "The node version of $APPID is too new. Need to update the container."
                exit 1
            fi
            nvm use lts/gallium
        else
            set +x
            nvm use lts/fermium
        fi
    else
        set +x
        nvm use lts/fermium
    fi

    if [ "$APPID" = mail ]; then
        wget https://getcomposer.org/download/1.10.22/composer.phar
        chmod +x ./composer.phar
        if ! ./composer.phar install --no-dev; then
            echo "Could not install composer dependencies of the mail app."
            exit 1
        fi
    # Install composer dependencies
    elif [ -f composer.json ]; then
        if ! composer install --no-dev; then
            echo "Could not install composer dependencies of the $APPID app."
            exit 1
        fi
    fi

    # Compile apps
    if [ -f package.json ]; then
        if ! npm ci || ! npm run build --if-present; then
            echo "Could not compile the $APPID app."
            exit 1
        fi
    fi

    # Go into occ directory
    cd /var/www/nextcloud

    # Enable app
    if ! php -f occ app:enable "$APPID"; then
        echo "Could not enable the $APPID app."
        exit 1
    fi

    # The app was enabled
    touch "/var/www/$APPID-completed"
fi
}

# Compatible apps
install_enable_app "$ACTIVITY_BRANCH" activity
install_enable_app "$APPROVAL_BRANCH" approval
install_enable_app "$BOOKMARKS_BRANCH" bookmarks
install_enable_app "$CALENDAR_BRANCH" calendar
install_enable_app "$CIRCLES_BRANCH" circles
install_enable_app "$CONTACTS_BRANCH" contacts
install_enable_app "$DECK_BRANCH" deck
install_enable_app "$DOWNLOADLIMIT_BRANCH" files_downloadlimit
install_enable_app "$E2EE_BRANCH" end_to_end_encryption
install_enable_app "$FIRSTRUNWIZARD_BRANCH" firstrunwizard
install_enable_app "$FORMS_BRANCH" forms
install_enable_app "$GROUPFOLDERS_BRANCH" groupfolders
install_enable_app "$GUESTS_BRANCH" guests
install_enable_app "$IMPERSONATE_BRANCH" impersonate
install_enable_app "$ISSUTEMPLATE_BRANCH" issuetemplate
install_enable_app "$LOGREADER_BRANCH" logreader
install_enable_app "$MAIL_BRANCH" mail
install_enable_app "$MAPS_BRANCH" maps
install_enable_app "$NEWS_BRANCH" news
install_enable_app "$NOTES_BRANCH" notes
install_enable_app "$NOTIFICATIONS_BRANCH" notifications
install_enable_app "$PDFVIEWER_BRANCH" files_pdfviewer
install_enable_app "$PHOTOS_BRANCH" photos
install_enable_app "$POLLS_BRANCH" polls
install_enable_app "$RECOMMENDATIONS_BRANCH" recommendations
install_enable_app "$SERVERINFO_BRANCH" serverinfo
install_enable_app "$TALK_BRANCH" spreed
install_enable_app "$TASKS_BRANCH" tasks
install_enable_app "$TEXT_BRANCH" text
install_enable_app "$VIEWER_BRANCH" viewer
install_enable_app "$ZIPPER_BRANCH" files_zip

# Clear cache
cd /var/www/nextcloud
if ! php -f occ maintenance:repair; then
    echo "Could not clear the cache"
    exit 1
fi

# Show how to reach the server
show_startup_info
print_green "You can log in with the user 'admin' and its password 'nextcloud'"
