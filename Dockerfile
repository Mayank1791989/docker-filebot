FROM phusion/baseimage:0.11

LABEL maintainer="Mayank Agarwal <mayank1791989@gmail.com>"

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

ENV DEBIAN_FRONTEND noninteractive
ADD dpkg-excludes /etc/dpkg/dpkg.cfg.d/excludes

RUN true \
  && apt-get update \
  && apt-get install -y default-jre libjna-java mediainfo libchromaprint-tools unrar p7zip-full p7zip-rar mkvtoolnix mp4v2-utils gnupg curl wget \
  && apt-get install -y python3-setuptools python3-pip && pip3 install watchdog \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV USER_ID 0
ENV GROUP_ID 0
ENV UMASK 0000

VOLUME ["/media", "/input", "/output", "/config"]

# Set the locale, to support files that have non-ASCII characters
# RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV FILEBOT_DATA /config/data
ENV FILEBOT_OPTS "-Dapplication.deployment=docker -Duser.home=$FILEBOT_DATA"
ENV FILEBOT_VERSION=4.9.1

# Create dir to keep things tidy. Make sure it's readable by $USER_ID
RUN mkdir /files && chmod a+rwX /files

RUN true \
  # To find the latest version: https://www.filebot.net/download.php?mode=s&type=deb&arch=amd64
  # We'll use a specific version for reproducible builds
  && wget --no-check-certificate -q -O /files/filebot.deb \
    https://get.filebot.net/filebot/FileBot_${FILEBOT_VERSION}/FileBot_${FILEBOT_VERSION}_universal.deb \
  && dpkg -i /files/filebot.deb && rm /files/filebot.deb \
  # Revision-lock to a specific version to avoid any surprises.
  && wget --no-check-certificate -q -O /files/runas.sh \
    'https://raw.githubusercontent.com/coppit/docker-inotify-command/1d4b941873b670525fd159dcb9c01bb2570b0565/runas.sh' \
  && chmod +x /files/runas.sh \
  && wget --no-check-certificate -q -O /files/monitor.py \
    'https://raw.githubusercontent.com/coppit/docker-inotify-command/c9e9c8b980d3a5ba4abfe7c1b069f684a56be6d2/monitor.py' \
  && chmod +x /files/monitor.py

COPY startapp.sh /
COPY install_license.sh /

# Add scripts. Make sure everything is executable by $USER_ID
COPY pre-run.sh filebot.sh filebot.conf /files/
RUN chmod a+x /files/pre-run.sh
RUN chmod a+w /files/filebot.conf

ADD 50_configure_filebot.sh /etc/my_init.d/

RUN mkdir -p /etc/service/filebot
ADD monitor.sh /etc/service/filebot/run
RUN chmod +x /etc/service/filebot/run