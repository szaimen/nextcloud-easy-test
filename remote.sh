#!/bin/bash

# Function to show text in green
print_green() {
    local TEXT="$1"
    printf "%b%s%b\n" "\e[0;92m" "$TEXT" "\e[0m"
}

# Show how to reach the server
show_startup_info() {
    local SHOWN_PORT
    if [ "$APACHE_PORT" = 443 ]; then
        SHOWN_PORT=8443
    else
        SHOWN_PORT="$APACHE_PORT"
    fi
    if [ -z "$TRUSTED_DOMAIN" ]; then
        print_green "The server should now be reachable via https://localhost:$SHOWN_PORT/"
    else
        print_green "The server should now be reachable via https://$TRUSTED_DOMAIN:$SHOWN_PORT/"
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

# Handle node versions
handle_node_version() {
    set -x
    if [ -f package.json ]; then
        local NODE_LINE
        NODE_LINE=$(grep '"node":' package.json | head -1)
    fi
    if [ -n "$NODE_LINE" ] && echo "$NODE_LINE" | grep -q '\^'; then
        local NODE_VERSION
        NODE_VERSION="$(echo "$NODE_LINE" | grep -oP '\^[0-9]+' | sed 's|\^||' | head -n 1)"
        if [ -n "$NODE_VERSION" ] && [ "$NODE_VERSION" -gt 18 ]; then
            if [ "$NODE_VERSION" -gt 20 ]; then
                # TODO: NODE_VERSION test should check for 20 and not 22 but checking for 22 temporarily so that script is able to proceed
                if [ "$NODE_VERSION" -gt 22 ]; then
                    echo "The node version of $APPID is too new. Need to update the container."
                    exit 1
                fi
                set +x
                nvm use lts/jod
            else
                set +x
                nvm use lts/iron
            fi
        else
            set +x
            nvm use lts/hydrogen
        fi
    else
        set +x
        nvm use lts/hydrogen
    fi
}

# Handle npm versions
handle_npm_version() {
    set -x
    if [ -f package.json ]; then
        local NPM_LINE
        NPM_LINE=$(grep '"npm":' package.json | head -1)
    fi
    if [ -n "$NPM_LINE" ] && echo "$NPM_LINE" | grep -q '\^'; then
        local NPM_VERSION
        NPM_VERSION="$(echo "$NPM_LINE" | grep -oP '\^[0-9]+' | sed 's|\^||' | head -n 1)"
        if [ -n "$NPM_VERSION" ] && [ "$NPM_VERSION" -eq 7 ]; then
            set +x
            npm i -g npm@latest-7
            return
        fi
    fi

    set +x
    nvm install-latest-npm
}

install_nextcloud_vue() {
    if [ -n "$NEXTCLOUDVUE_BRANCH" ] && [ ! -f "/var/www/nextcloud-vue-completed" ]; then
        # Handle case that branch is present in nextcloud repo
        if ! echo "$NEXTCLOUDVUE_BRANCH" | grep -q ':'; then
            NEXTCLOUDVUE_BRANCH="nextcloud:$NEXTCLOUDVUE_BRANCH"
        fi
        set -x
        local VUE_OWNER="${NEXTCLOUDVUE_BRANCH%%:*}"
        local VUE_BRANCH="${NEXTCLOUDVUE_BRANCH#*:}"
        local VUE_REPO=nextcloud-vue
        if echo "$VUE_BRANCH" | grep -q '@'; then
            VUE_REPO="${VUE_BRANCH#*@}"
            VUE_BRANCH="${VUE_BRANCH%%@*}"
        fi
        set +x
        mkdir /var/www/nextcloud-vue
        cd /var/www/nextcloud-vue || exit
        if ! git clone https://github.com/"$VUE_OWNER"/"$VUE_REPO".git --branch "$VUE_BRANCH" --single-branch --depth 1 .; then
            echo "Could not clone the requested nextcloud vue branch '$VUE_BRANCH' of '$VUE_OWNER/$VUE_REPO'. Does it exist?"
            exit 1
        fi

        if [ -z "$FULL_INSTANCE_BRANCH" ]; then
            # Handle node version
            handle_node_version

            # Handle npm version
            handle_npm_version

            echo "Compiling Nextcloud vue..."
            if ! npm ci --no-audit || ! npm run dev --if-present; then
                echo "Could not compile Nextcloud vue"
                exit 1
            fi

            npm link
        fi

        touch "/var/www/nextcloud-vue-completed"
    fi
}

link_nextcloud_vue() {
    if [ -n "$NEXTCLOUDVUE_BRANCH" ]; then
        if grep -q '@nextcloud/vue' package.json; then
            if ! npm link @nextcloud/vue; then
                echo "Could not link nextcloud vue in $1."
                exit 1
            fi
        fi
    fi
}

# Handle empty server branch variable
if [ -z "$SERVER_BRANCH" ]; then
    export SERVER_BRANCH="nextcloud:master"
fi

# Handle case that branch is present in nextcloud repo
if ! echo "$SERVER_BRANCH" | grep -q ':'; then
    export SERVER_BRANCH="nextcloud:$SERVER_BRANCH"
fi

if [ -n "$FULL_INSTANCE_BRANCH" ]; then
    export SERVER_BRANCH="nextcloud:$FULL_INSTANCE_BRANCH"
    export ACTIVITY_BRANCH="$FULL_INSTANCE_BRANCH"
    export BRUTEFORCESETTINGS_BRANCH="$FULL_INSTANCE_BRANCH"
    export CIRCLES_BRANCH="$FULL_INSTANCE_BRANCH"
    export PDFVIEWER_BRANCH="$FULL_INSTANCE_BRANCH"
    export FIRSTRUNWIZARD_BRANCH="$FULL_INSTANCE_BRANCH"
    export LOGREADER_BRANCH="$FULL_INSTANCE_BRANCH"
    export ANNOUNCEMENTS_BRANCH="$FULL_INSTANCE_BRANCH"
    export NOTIFICATIONS_BRANCH="$FULL_INSTANCE_BRANCH"
    export PASSWORDPOLICY_BRANCH="$FULL_INSTANCE_BRANCH"
    export PHOTOS_BRANCH="$FULL_INSTANCE_BRANCH"
    export PRIVACY_BRANCH="$FULL_INSTANCE_BRANCH"
    export RECOMMENDATIONS_BRANCH="$FULL_INSTANCE_BRANCH"
    export RELATEDRESOURCES_BRANCH="$FULL_INSTANCE_BRANCH"
    export SERVERINFO_BRANCH="$FULL_INSTANCE_BRANCH"
    export SURVEYCLIENT_BRANCH="$FULL_INSTANCE_BRANCH"
    export TEXT_BRANCH="$FULL_INSTANCE_BRANCH"
    export TWOFACTORTOTP_BRANCH="$FULL_INSTANCE_BRANCH"
    export VIEWER_BRANCH="$FULL_INSTANCE_BRANCH"
fi

# Get NVM code
export NVM_DIR="/var/www/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"

# Get latest changes
if ! [ -f /var/www/server-completed ]; then
    set -x
    FORK_OWNER="${SERVER_BRANCH%%:*}"
    FORK_BRANCH="${SERVER_BRANCH#*:}"
    FORK_REPO=server
    if echo "$FORK_BRANCH" | grep -q '@'; then
        FORK_REPO="${FORK_BRANCH#*@}"
        FORK_BRANCH="${FORK_BRANCH%%@*}"
    fi
    set +x
    cd /var/www/nextcloud || exit
    if ! git clone https://github.com/"$FORK_OWNER"/"$FORK_REPO".git --branch "$FORK_BRANCH" --single-branch --depth 1 .; then
        echo "Could not clone the requested server branch '$FORK_BRANCH' of '$FORK_OWNER/$FORK_REPO'. Does it exist?"
        exit 1
    fi

    # Initiate submodules
    git submodule update --init

    # Allow to compile the server javascript
    if [ -z "$FULL_INSTANCE_BRANCH" ] && [ -n "$COMPILE_SERVER" ]; then
        set -x
        # shellcheck disable=SC2016
        installed_version="$(php -r 'require "/var/www/nextcloud/version.php"; echo implode(".", $OC_Version);')"
        if version_greater "$installed_version" "24.0.0.0"; then
            # Install Nextcloud vue
            install_nextcloud_vue
            cd /var/www/nextcloud || exit

            # Handle node version
            handle_node_version

            # Handle npm version
            handle_npm_version

            echo "Compiling server..."
            if ! npm ci --no-audit || ! link_nextcloud_vue server || ! npm run dev --if-present || ! npm run sass --if-present || ! npm run icon --if-present; then
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

    php -f occ config:system:set log_type --value "errorlog"

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
    cd /var/www/nextcloud/apps || exit

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
    local APP_REPO="$APPID"
    if echo "$APP_BRANCH" | grep -q '@'; then
        APP_REPO="${APP_BRANCH#*@}"
        APP_BRANCH="${APP_BRANCH%%@*}"
    fi
    set +x
    if ! git clone https://github.com/"$APP_OWNER"/"$APP_REPO".git --branch "$APP_BRANCH" --single-branch --depth 1 "$APPID"; then
        echo "Could not clone the requested branch '$APP_BRANCH' of the $APPID app of '$APP_OWNER/$APP_REPO'. Does it exist?"
        exit 1
    fi

    # Install Nextcloud vue
    install_nextcloud_vue
    cd /var/www/nextcloud/apps/ || exit

    # Go into app directory
    cd ./"$APPID" || exit

        # if [ "$APPID" = mail ]; then
        #     wget https://getcomposer.org/download/1.10.22/composer.phar
        #     chmod +x ./composer.phar
        #     if ! ./composer.phar install --no-dev; then
        #         echo "Could not install composer dependencies of the mail app."
        #         exit 1
        #     fi

        # Install composer dependencies
        if [ -f composer.json ]; then
            if ! composer install --no-dev; then
                echo "Could not install composer dependencies of the $APPID app."
                exit 1
            fi
        fi

    if [ -z "$FULL_INSTANCE_BRANCH" ]; then
        # Handle node version
        handle_node_version

        # Handel npm version
        handle_npm_version

        # Compile apps
        if [ -f package.json ]; then
            # Link nextcloud vue
            link_nextcloud_vue "$APPID"
            if ! npm ci --no-audit || ! link_nextcloud_vue "$APPID" || ! npm run dev --if-present; then
                echo "Could not compile the $APPID app."
                exit 1
            fi
        fi
    fi

    # Go into occ directory
    cd /var/www/nextcloud || exit

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
install_enable_app "$ANNOUNCEMENTS_BRANCH" nextcloud_announcements
install_enable_app "$APPROVAL_BRANCH" approval
install_enable_app "$BOOKMARKS_BRANCH" bookmarks
install_enable_app "$BRUTEFORCESETTINGS_BRANCH" bruteforcesettings
install_enable_app "$CALENDAR_BRANCH" calendar
install_enable_app "$CIRCLES_BRANCH" circles
install_enable_app "$CONTACTS_BRANCH" contacts
install_enable_app "$DECK_BRANCH" deck
install_enable_app "$DOWNLOADLIMIT_BRANCH" files_downloadlimit
install_enable_app "$E2EE_BRANCH" end_to_end_encryption
install_enable_app "$FILES_LOCK_BRANCH" files_lock
install_enable_app "$FIRSTRUNWIZARD_BRANCH" firstrunwizard
# shellcheck disable=SC2153
install_enable_app "$FORMS_BRANCH" forms
install_enable_app "$GROUPFOLDERS_BRANCH" groupfolders
install_enable_app "$GUESTS_BRANCH" guests
install_enable_app "$IMPERSONATE_BRANCH" impersonate
install_enable_app "$INTEGRATIONGITHUB_BRANCH" integration_github
install_enable_app "$ISSUTEMPLATE_BRANCH" issuetemplate
install_enable_app "$LOGREADER_BRANCH" logreader
install_enable_app "$MAIL_BRANCH" mail
# shellcheck disable=SC2153
install_enable_app "$MAPS_BRANCH" maps  
install_enable_app "$NEWS_BRANCH" news
install_enable_app "$NOTES_BRANCH" notes
install_enable_app "$NOTIFICATIONS_BRANCH" notifications
install_enable_app "$OCS_API_VIEWER_BRANCH" ocs_api_viewer
install_enable_app "$PASSWORDPOLICY_BRANCH" password_policy
install_enable_app "$PDFVIEWER_BRANCH" files_pdfviewer
install_enable_app "$PHOTOS_BRANCH" photos
install_enable_app "$POLLS_BRANCH" polls
install_enable_app "$PRIVACY_BRANCH" privacy
install_enable_app "$RECOMMENDATIONS_BRANCH" recommendations
install_enable_app "$RELATEDRESOURCES_BRANCH" related_resources
install_enable_app "$RIGHTCLICK_BRANCH" files_rightclick
install_enable_app "$SERVERINFO_BRANCH" serverinfo
install_enable_app "$SURVEYCLIENT_BRANCH" survey_client
install_enable_app "$SUSPICIOUSLOGIN_BRANCH" suspicious_login
install_enable_app "$TABLES_BRANCH" tables
install_enable_app "$TALK_BRANCH" spreed
install_enable_app "$TASKS_BRANCH" tasks
install_enable_app "$TEXT_BRANCH" text
install_enable_app "$TWOFACTORWEBAUTHN_BRANCH" twofactor_webauthn
install_enable_app "$TWOFACTORTOTP_BRANCH" twofactor_totp
install_enable_app "$VIEWER_BRANCH" viewer
install_enable_app "$ZIPPER_BRANCH" files_zip

# Clear cache
cd /var/www/nextcloud || exit
if ! php -f occ maintenance:repair; then
    echo "Could not clear the cache"
    exit 1
fi

# Set Xdebug options
if [ -n "$XDEBUG_MODE" ]; then
    sed -i 's/^xdebug.mode\s*=\s*.*/xdebug.mode='"$XDEBUG_MODE"'/g' /usr/local/etc/php/conf.d/xdebug.ini
fi

# Set loglevel
if [ -n "$NEXTCLOUD_LOGLEVEL" ]; then
    php -f occ config:system:set loglevel --value "$NEXTCLOUD_LOGLEVEL" --type int
    if [ "$NEXTCLOUD_LOGLEVEL" = 0 ]; then
        php -f occ config:system:set debug --value true --type bool
    fi
fi

# Show how to reach the server
show_startup_info
print_green "You can log in with the user 'admin' and its password 'nextcloud'"
