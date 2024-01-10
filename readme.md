# Nextcloud easy test instance
This is a one-command Nextcloud instance that makes it possible to test different branches and apps with just one command.

## How to use this?

### Preparation (only needed if not done yet):
Install Docker on your OS:
- On Linux via:
    ```shell
    curl -fsSL https://get.docker.com | sudo sh
    ```
- On macOS and Windows via Docker Desktop:
https://www.docker.com/products/docker-desktop 

### Execution
Run the container:  
(You can change the branch by changing `master` in `SERVER_BRANCH=master` to the branch that you want to test during the initial container creation.)

On Linux and macOS:
```
docker run -it \
-e SERVER_BRANCH=master \
--name nextcloud-easy-test \
-p 127.0.0.1:8443:443 \
--volume="nextcloud_easy_test_npm_cache_volume:/var/www/.npm" \
ghcr.io/szaimen/nextcloud-easy-test:latest
```

<details>
<summary>On Windows</summary>

```
docker run -it ^
-e SERVER_BRANCH=master ^
--name nextcloud-easy-test ^
-p 127.0.0.1:8443:443 ^
--volume="nextcloud_easy_test_npm_cache_volume:/var/www/.npm" ^
ghcr.io/szaimen/nextcloud-easy-test:latest
```

</details>

<details>
<summary>Explanation of the command</summary>

`docker run -it`  
This command creates a new docker container.

`-e SERVER_BRANCH=master`  
This inserts the environment variable `SERVER_BRANCH` into the container and sets it to the value `master`. 

`--name nextcloud-easy-test`  
This gives the container a distinct name `nextcloud-easy-test` so that you are able to easily run other docker commands on the container.

`-p 127.0.0.1:8443:443`  
This makes the container listen on `localhost` and maps the host port `8443` to the container port `443` so that you are able to access the container by opening https://localhost:8443.

`--volume="nextcloud_easy_test_npm_cache_volume:/var/www/.npm"`
This stores the npm cache in a docker volume so that compiling apps takes less time from the second time. You can clean it with `sudo docker volume rm nextcloud_easy_test_npm_cache_volume`.

`ghcr.io/szaimen/nextcloud-easy-test:latest`  
This is the image name that you will use as base for the container. `latest` is the tag that will be used.

---

</details>

After the initial startup you will be able to access the instance via https://localhost:8443 and using `admin` as username and `nextcloud` as password.

### Follow up

**After you are done testing**, you can simply stop the container by pressing `[CTRL] + [c]` and delete the container by running:
```
docker stop nextcloud-easy-test
docker rm nextcloud-easy-test
```

### Running in a VM
If you want to run this in a VM, you need to change the port in the initial command from `-p 127.0.0.1:8443:443` to `-p 8443:443` and add the following flag: `-e TRUSTED_DOMAIN=ip.of.the.VM` in order to automatically make it work.

### Available APPS
Additionally, the container currently reacts on the following apps variables and installs and compiles those automatically if provided:
```
ACTIVITY_BRANCH
ANNOUNCEMENTS_BRANCH
APPROVAL_BRANCH
BOOKMARKS_BRANCH
BRUTEFORCESETTINGS_BRANCH
CALENDAR_BRANCH
CIRCLES_BRANCH
CONTACTS_BRANCH
DECK_BRANCH
DOWNLOADLIMIT_BRANCH
E2EE_BRANCH
FILES_LOCK_BRANCH
FIRSTRUNWIZARD_BRANCH
FORMS_BRANCH
GROUPFOLDERS_BRANCH
GUESTS_BRANCH
IMPERSONATE_BRANCH
INTEGRATIONGITHUB_BRANCH
ISSUTEMPLATE_BRANCH
LOGREADER_BRANCH
MAIL_BRANCH
MAPS_BRANCH
NEWS_BRANCH
NOTES_BRANCH
NOTIFICATIONS_BRANCH
OCS_API_VIEWER_BRANCH
PASSWORDPOLICY_BRANCH
PDFVIEWER_BRANCH
PHOTOS_BRANCH
POLLS_BRANCH
PRIVACY_BRANCH
RECOMMENDATIONS_BRANCH
RELATEDRESOURCES_BRANCH
RIGHTCLICK_BRANCH
SERVERINFO_BRANCH
SURVEYCLIENT_BRANCH
TALK_BRANCH
TASKS_BRANCH
TEXT_BRANCH
TWOFACTORWEBAUTHN_BRANCH
TWOFACTORTOTP_BRANCH
VIEWER_BRANCH
ZIPPER_BRANCH
```

<details>
<summary>For easy copy and paste</summary>

```
-e ACTIVITY_BRANCH=master \
-e ANNOUNCEMENTS_BRANCH=master \
-e APPROVAL_BRANCH=main \
-e BOOKMARKS_BRANCH=master \
-e BRUTEFORCESETTINGS_BRANCH=master \
-e CALENDAR_BRANCH=main \
-e CIRCLES_BRANCH=master \
-e CONTACTS_BRANCH=main \
-e DECK_BRANCH=main \
-e DOWNLOADLIMIT_BRANCH=master \
-e E2EE_BRANCH=master \
-e FILES_LOCK_BRANCH=main \
-e FIRSTRUNWIZARD_BRANCH=master \
-e FORMS_BRANCH=main \
-e GROUPFOLDERS_BRANCH=master \
-e GUESTS_BRANCH=master \
-e IMPERSONATE_BRANCH=master \
-e INTEGRATIONGITHUB_BRANCH=main \
-e ISSUTEMPLATE_BRANCH=master \
-e LOGREADER_BRANCH=master \
-e MAIL_BRANCH=main \
-e MAPS_BRANCH=master \
-e NEWS_BRANCH=master \
-e NOTES_BRANCH=main \
-e NOTIFICATIONS_BRANCH=master \
-e OCS_API_VIEWER_BRANCH=main \
-e PASSWORDPOLICY_BRANCH=master \
-e PDFVIEWER_BRANCH=master \
-e PHOTOS_BRANCH=master \
-e POLLS_BRANCH=master \
-e PRIVACY_BRANCH=master \
-e RECOMMENDATIONS_BRANCH=master \
-e RELATEDRESOURCES_BRANCH=master \
-e RIGHTCLICK_BRANCH=master \
-e SERVERINFO_BRANCH=master \
-e SURVEYCLIENT_BRANCH=master \
-e TALK_BRANCH=main \
-e TASKS_BRANCH=master \
-e TEXT_BRANCH=main \
-e TWOFACTORWEBAUTHN_BRANCH=main \
-e TWOFACTORTOTP_BRANCH=master \
-e VIEWER_BRANCH=master \
-e ZIPPER_BRANCH=main \
```

</details>

If one of the above variables are set via e.g. `-e CALENDAR_BRANCH=main` during the initial container creation, then will the container automatically get the chosen branch from github and compile and enable the chosen apps on the instance during the startup.

Branches from custom forks can be installed as well. Use `-e CALENDAR_BRANCH=user:main` to install the `main` branch from the fork of `user`. If the fork has a different name (e.g. nextcloud-calendar), you can use the extended format `-e CALENDAR_BRANCH=user:main@nextcloud-calendar` to pull the branch `main` of the repo `user/nextcloud-calendar`. This format can be used with all app branch variables including `SERVER_BRANCH` and `NEXTCLOUDVUE_BRANCH`.

### Other variables
- `MANUAL_INSTALL` if the variable is set, it will skip all apps variables and only clone the given server branch and start Apache directly. You will then be able to provide your own credentials and install recommended apps.
- `SKELETON_ARCHIVE_URL` if the variable is set it will try to download a tar.gz file from a remote server, will untar it and will try to use that as a skeletondir which will make them the default files for new users ony the test instance.
- `COMPILE_SERVER` if the variable is set (so e.g. via `-e COMPILE_SERVER=1`) it will compile javascript files for the chosen server branch. This only works for branches starting from version 24.0.0.
- `FULL_INSTANCE_BRANCH` if the variable is set it will download and install all apps that are bundled by default with a default Nextcloud instance. Set it for example to `stable28`. (**Please note**: Only stable branches are supported and not master or main. Also the support app and the suspicious_login app are never included. Additionally, any js compiling will be skipped if this variable is set).
- `APACHE_PORT` if the variable is set, it will instead of the default port 443 inside the container, use the chosen Port for APACHE.
- `NEXTCLOUDVUE_BRANCH` if the variable is set it will compile javascript files for the chosen nextcloud vue branch and automatically link all chosen apps that use nextcloud vue and additionally the server if COMPILE_SERVER is set.
- `XDEBUG_MODE` if the variable is set it will change the Xdebug mode to the set value. For example `debug`, `trace` or `profile` can be used. If the variable is not set, Xdebug mode will be `off` by default.

`NEXTCLOUD_LOGLEVEL` this can modify the loglevel of Nextcloud and must be an integer. By default it is set to 3. Valid values are: 0 = Debug, 1 = Info, 2 = Warning, 3 = Error, and 4 = Fatal.

## How does it work?
The docker image comes pre-bundled with all needed dependencies for a minimal instance of Nextcloud and allows to define a target branch via environmental variables that will automatically be cloned and compiled during the container startup. For a refresh, you need to recreate the container by first removing it and then running the same command again.
