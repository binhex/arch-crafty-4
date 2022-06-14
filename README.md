**Application**

[Crafty Controller v4](https://craftycontrol.com/)

**Description**

Crafty Controller is a free and open-source Minecraft launcher and manager that allows users to start and administer Minecraft servers from a user-friendly interface. The interface is run as a self-hosted web server that is accessible to devices on the local network by default and can be port forwarded to provide external access outside of your local network. Crafty is designed to be easy to install and use, requiring only a bit of technical knowledge and a desire to learn to get started. Crafty Controller is still actively being developed by Arcadia Technology and we are continually making major improvements to the software.

Crafty Controller is a feature rich panel that allows you to create and run servers, manage players, run commands, change server settings, view and edit server files, and make backups. With the help of Crafty Controller managing a large number of Minecraft servers on separate versions is easy and intuitive to do.

**Build notes**

Latest commit to GitHub branch 'master'.

**Usage**
```
docker run -d \
    -p <host port for crafty web ui>:8000 \
    -p <host port range for minecraft servers>:25565-25575 \
    --name=<container name> \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e JAVA_VERSION=<8|11|latest> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-crafty-4
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access Crafty Web UI**

`https://<host ip>:8000`

Credentials are shown on first run in the log file ```/config/supervisord.log```

**Example**
```
docker run -d \
    -p 8000:8000 \
    -p 25565-25575:25565-25575 \
    --name=crafty \
    -v /apps/docker/crafty:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e JAVA_VERSION=latest \
    -e UMASK=000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-crafty-4
```

**Notes**

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](https://forums.unraid.net/topic/108893-support-binhex-crafty/)

Crafty is a Minecraft Server Wrapper / Controller / Launcher. The purpose of Crafty is to launch a Minecraft server in the background and present a web interface for the admin to use to interact with their server.

**Build notes**

Latest commit to GitHub branch 'master'.

**Usage**
```
docker run -d \
    -p <host port for crafty web ui>:8000 \
    -p <host port range for minecraft servers>:25565-25575 \
    --name=<container name> \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e JAVA_VERSION=<8|11|latest> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-crafty
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access Crafty Web UI**

`https://<host ip>:8000`

Credentials are shown on first run in the log file ```/config/supervisord.log```

**Example**
```
docker run -d \
    -p 8000:8000 \
    -p 25565-25575:25565-25575 \
    --name=crafty \
    -v /apps/docker/crafty:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e JAVA_VERSION=latest \
    -e UMASK=000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-crafty
```

**Notes**

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](https://forums.unraid.net/topic/108893-support-binhex-crafty/)