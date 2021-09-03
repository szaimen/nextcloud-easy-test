# Nextcloud easy test instance
This is a one-command Nextcloud instance that makes it possible to test different branches and apps with only one command.

## How to use this?

### Preparation (only needed if not yet done):
Install Docker on your OS:
- On Linux via:
    ```shell
    curl -fsSL get.docker.com | sudo sh
    ```
- On macOS and Windows via Docker Desktop:
https://www.docker.com/products/docker-desktop 

### Execution
Run the container:  
(You can change the branch by changing `master` in `SERVER_BRANCH=master` to the branch that you want to test during the initial container creation.)

On Linux and macOS:
```
docker run \
-e SERVER_BRANCH=master \
--name nextcloud-test \
-p 127.0.0.1:8443:443 \
ghcr.io/szaimen/nextcloud-onedev:latest
```

<details>
<summary>On Windows</summary>

```
docker run ^
-e SERVER_BRANCH=master ^
--name nextcloud-test ^
-p 127.0.0.1:8443:443 ^
ghcr.io/szaimen/nextcloud-onedev:latest
```

</details>

After the initial startup you will be able to access the instance via https://localhost:8443 and using `admin` as username and `nextcloud` as password.

### Follow up

**After you are done testing**, you can simply stop the container by pressing `[CTRL] + [c]` and delete the container by running:
```
docker stop nextcloud-test
docker rm nextcloud-test
```

### Running in a VM
If you want to run this in a VM, you need to change the port in the initial command from to `-p 127.0.0.1:8443:443` to `-p 8443:443` and add the following flag: `-e TRUSTED_DOMAIN=ip.of.the.VM` in order to automatically make it work.

### Additionally Available Environmental Variables
Additionally, the container currently reacts on the following variables:
```
CALENDAR_BRANCH
CONTACTS_BRANCH
TASKS_BRANCH
VIEWER_BRANCH
```
If one of the above variables are set via e.g. `-e CALENDAR_BRANCH=master` during the initial container creation, then will the container automatically get the chosen branch from github and compile and enable the chosen apps on the instance during the startup.

## How does it work?
The docker image comes pre-bundled with all needed dependencies for a minimal instance of Nextcloud, has the master branch already included and allows to define a target branch via environmental variables that will automatically be switched to and refreshed during the container startup (or restart).
