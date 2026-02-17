FROM debian:trixie-slim

# Set environment variables for container
ENV DEBIAN_FRONTEND=noninteractive \
    HOME="/app"

# Set environment variables for setup
ENV WINE_KEY="https://dl.winehq.org/wine-builds/winehq.key" \
    WINE_KEY_DEST="/etc/apt/keyrings/winehq-archive.key" \
    WINE_SOURCE="https://dl.winehq.org/wine-builds/debian/dists/trixie/winehq-trixie.sources"

# Install dependencies
RUN apt-get update \
    && apt-get upgrade -y --fix-missing \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        sudo \
        passwd \
        diffutils \
        findutils \
        procps \
        libnss-myhostname \
        pinentry-curses \
        bc \
        less \
        lsof \
        gpg \
        fonts-wine \
        libgl1 \
        libasound2 \
        libpulse0 \
        libxrandr2 \
        libxi6 \
        libxcursor1 \
        libxinerama1 \
        
    && dpkg --add-architecture i386 \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -O - "$WINE_KEY" | gpg --batch --yes --dearmor -o "$WINE_KEY_DEST" \
    && wget -NP /etc/apt/sources.list.d/ "$WINE_SOURCE" \
    && apt-get update \
    && apt-get install -y winehq-stable wine32 \
    && apt-get install -y --no-install-recommends \
        systemd \
        debhelper \
        samba \
        gawk \
        p7zip \
        curl \
        cabextract \
        mokutil \
        lsb-release \
        spacenavd \
        x11-xserver-utils \
        gettext \
        smbclient \
        winbind \
        xdg-utils \
        mesa-utils \
        7zip \
        p7zip-full \
        polkitd \
        pkexec \
        xvfb \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Initialize Wine prefix headlessly
ENV WINEPREFIX=/app/.wine \
    WINEARCH=win64

RUN mkdir -p $WINEPREFIX \
    && Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp & \
    XVFB_PID=$! \
    && sleep 5 \
    && DISPLAY=:99 wineboot --init \
    && wineserver -w \
    && kill $XVFB_PID

# Run Fusion 360 installer with virtual display for Wine
COPY ./files/setup/autodesk_fusion_installer_x86-64.sh \
    /usr/local/bin/install_fusion
RUN chmod +x /usr/local/bin/install_fusion \
    && Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp & \
    XVFB_PID=$! \
    && sleep 5 \
    && DISPLAY=:99 /usr/local/bin/install_fusion --install --default --full --headless \
    && wineserver -w \
    && kill $XVFB_PID \
    && rm -f /usr/local/bin/install_fusion

# Cleanup unnecessary packages and files
RUN apt-get remove --purge -y \
        debhelper \
        xvfb \
        mokutil \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install wrapper and desktop file for Distrobox export
COPY ./files/setup/data/fusion360-wrapper.sh \
    /usr/local/bin/fusion360
COPY ./files/setup/data/autodesk-fusion.desktop \
    /usr/share/applications/autodesk-fusion.desktop
RUN chmod +x /usr/local/bin/fusion360
