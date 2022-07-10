FROM debian:bookworm

ENV DEBIAN_FRONTEND noninteractive

# dependencies for virtual desktop stuff
RUN apt-get update
RUN apt-get install -y xserver-xorg-core xserver-xorg-video-fbdev x11-xserver-utils libgl1-mesa-dri  \
    xserver-xorg-video-vesa xautomation xauth xinit x11vnc feh matchbox-window-manager procps gawk  \
    dbus-x11 xserver-xorg-video-dummy 

# dependencies for your app
RUN apt-get install -y x11-apps xterm

# black wallpaper
COPY wallpaper.png /etc/wallpaper.png

COPY entrypoint.sh /entrypoint.sh

# replace /usr/bin/xeyes with whatever you want to run
ENTRYPOINT [ "/entrypoint.sh", "/usr/bin/xeyes" ]
