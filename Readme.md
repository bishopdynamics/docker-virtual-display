# Generic Virtual Display Container

Run desktop app in a virtual display in a docker container, and access it via VNC.

[MIT License](LICENSE)

Edit [`Dockerfile`](Dockerfile) to adjust.

This is intended as a template (right now it runs `xeyes`, woo!), 
for you to create your own containerized application that needs a desktop.

# Files

Files
* [`Dockerfile`](Dockerfile) - container for running this
* [`docker-compose.yml`](docker-compose.yml) - example compose file
* [`entrypoint.sh`](entrypoint.sh) - takes care of virtual display
* `wallpaper.png` - black wallpaper, so the screen goes black if the app quits

Dev scripts:
* [`build.sh`](build.sh) - build the container image
* [`deploy.sh`](deploy.sh) - deploy using [`docker-compose.yml`](docker-compose.yml)
* [`stop.sh`](stop.sh) - stop what you started
* [`test.sh`](test.sh) - run the instance from [`docker-compose.yml`](docker-compose.yml) interactively, without detaching
  * if you pass any args, they will be passed to `/entrypoint.sh` instead of the default entrypoint
  * example: `./test.sh /usr/bin/xeyes -fg blue`
  * connect to it at: [vnc://localhost:5901](vnc://localhost:5901)

## entrypoint.sh

The script [`entrypoint.sh`](entrypoint.sh) takes as arguments: a command or script to run inside the virtual display.

So in `Dockerfile` it looks like:
```dockerfile
ENTRYPOINT [ "/entrypoint.sh", "/usr/bin/xeyes" ]
```

It will pass along any subsequent arguments along to the command.
```dockerfile
ENTRYPOINT [ "/entrypoint.sh", "/usr/bin/xeyes", "-fg", "blue" ]
```

Inside the container, it will create a new non-root user using the `PUID` and `GUID` provided in environment.
It will set that user's home folder to `/config` and chown that folder.

It will then run the given command/script as the new non-root user, with all arguments and environment vars passed along.

Here are the environment vars that [`entrypoint.sh`](entrypoint.sh) uses, and their default values:
```bash
WINDOW_WIDTH="800"  # Window Width
WINDOW_HEIGHT="600"  # Window Height
VNC_PASSWORD="badpass"  # vnc password
VNC_PORT="5900"  # vnc port
EXTRA_VNC_ARGS=""  # additional arguments for x11vnc
EXTRA_X_ARGS=""  # additional arguments for X server
PUID="1000"  # User ID
PGID="1000"  # Group ID
VIRTUAL_VRAM="192000"  # need more vram for higher resolutions
REFRESH_RATE="60"  # hz, refresh rate, probably should stick with 60
RUNAS_ROOT="false"  # override to "true" to run as root instead of the non-root user
```