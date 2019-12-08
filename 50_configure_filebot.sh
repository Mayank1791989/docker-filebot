#!/bin/bash

function ts {
  echo [`date '+%b %d %X'`]
}

#-----------------------------------------------------------------------------------------------------------------------

function initialize_configuration {
  echo "$(ts) Creating /config/filebot.conf.new"
  cp /files/filebot.conf /config/filebot.conf.new

  if [ ! -f /config/filebot.conf ]
  then
    echo "$(ts) Creating /config/filebot.conf"
    cp /files/filebot.conf /config/filebot.conf
    chmod a+w /config/filebot.conf
  fi

  # Clean up carriage returns
  tr -d '\r' < /config/filebot.conf > /tmp/filebot.conf
  mv -f /tmp/filebot.conf /config/filebot.conf

  # Create filebot.sh unless there is already one
  if [ ! -f /config/filebot.sh ]
  then
    echo "$(ts) Creating /config/filebot.sh and exiting"
    cp /files/filebot.sh /config/filebot.sh
    exit 1
  fi

  if [ ! -d /config/data ]
  then
    echo "$(ts) Creating /config/data dir"
    mkdir /config/data
    chmod a+w /config/data
  fi
}

#-----------------------------------------------------------------------------------------------------------------------

function check_filebot_sh_version {
  USER_VERSION=$(grep '^VERSION=' /config/filebot.sh 2>/dev/null | sed 's/VERSION=//')
  CURRENT_VERSION=$(grep '^VERSION=' /files/filebot.sh | sed 's/VERSION=//')

  echo "$(ts) Comparing user's filebot.sh at version $USER_VERSION versus current version $CURRENT_VERSION"

  if [ -z "$USER_VERSION" ] || [ "$USER_VERSION" -lt "$CURRENT_VERSION" ]
  then
    echo "$(ts) ERROR: The container's filebot.sh is newer than the one in /config."
    echo "$(ts)   Copying the new script to /config/filebot.sh.new."
    echo "$(ts)   Compare your filebot.sh and filebot.sh.new. Save filebot.sh to reset its timestamp,"
    echo "$(ts)   then restart the container."
    cp /files/filebot.sh /config/filebot.sh.new
    exit 1
  fi
}

#-----------------------------------------------------------------------------------------------------------------------

function create_conf_and_sh_files {
  # Create the config file for monitor.py
  cat <<"EOF" > /files/FileBot.conf
if [[ -z "$INPUT_DIR" ]]
then
  INPUT_DIR=/input
fi

if [[ -z "$OUTPUT_DIR" ]]
then
  OUTPUT_DIR=/output
fi

EOF

  tr -d '\r' < /config/filebot.conf >> /files/FileBot.conf

  # Literal $INPUT_DIR
  cat <<"EOF" >> /files/FileBot.conf

WATCH_DIR="$INPUT_DIR"
EOF

  # Interpolate $USER_ID, $GROUP_ID, and $UMASK
  cat <<EOF >> /files/FileBot.conf

COMMAND="bash env HOME=$FILEBOT_DATA /files/filebot.sh"

IGNORE_EVENTS_WHILE_COMMAND_IS_RUNNING=0

USER_ID=$USER_ID
GROUP_ID=$GROUP_ID
UMASK=$UMASK
EOF

  # Strip \r from the user-provided filebot.sh
  tr -d '\r' < /config/filebot.sh > /files/filebot.sh
  chmod a+wx /files/filebot.sh

}

#-----------------------------------------------------------------------------------------------------------------------

function validate_configuration {
  . /files/FileBot.conf

  if [[ ! -d "$INPUT_DIR" ]]; then
    echo "$(ts) INPUT_DIR=$INPUT_DIR does not exist"
    exit 1
  fi

  if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "$(ts) OUTPUT_DIR=$OUTPUT_DIR does not exist"
    exit 1
  fi

  if find "$INPUT_DIR" -inum $(stat -c '%i' "$OUTPUT_DIR") 2>/dev/null | grep . 1>/dev/null 2>&1; then
    echo "$(ts) OUTPUT_DIR=$OUTPUT_DIR can not be a subdirectory of INPUT_DIR=$INPUT_DIR"
    exit 1
  fi
}

#-----------------------------------------------------------------------------------------------------------------------

function setup_opensubtitles_account {
  . /files/FileBot.conf

  if [ "$OPENSUBTITLES_USER" != "" ]; then
    echo "$(ts) Configuring for OpenSubtitles user \"$OPENSUBTITLES_USER\""
    echo -en "$OPENSUBTITLES_USER\n$OPENSUBTITLES_PASSWORD\n" | /files/runas.sh $USER_ID $GROUP_ID $UMASK env HOME=$FILEBOT_DATA filebot -script fn:configure
  else
    echo "$(ts) No OpenSubtitles user set. Skipping setup..."
  fi
}

#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------

function configure_java_prefs {
  . /files/FileBot.conf

  echo "$(ts) Creating user for ID $USER_ID and group for ID $GROUP_ID if necessary"
  # Running command as user "user_99_100"...
  runas_user=$(/files/runas.sh $USER_ID $GROUP_ID $UMASK true | grep Running | sed 's/.*"\(.*\)".*/\1/')

  mkdir -p /config/java_prefs /$runas_user/.java/.userPrefs/net
  chown -R $USER_ID:$GROUP_ID /config/java_prefs /$runas_user/.java
  rm -f /$runas_user/.java/.userPrefs/net/filebot
  echo Before creating symlink
  ls -al /config/java_prefs /$runas_user/.java/.userPrefs/net
  ln -s /config/java_prefs /$runas_user/.java/.userPrefs/net/filebot
  echo After creating symlink
  ls -al /config/java_prefs /$runas_user/.java/.userPrefs/net
}

#-----------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------------------------------------------------

function print_filebot_info {
  echo "---------------------------------------------------------------------------------------"
  echo "$(ts) Filebot info \n\n"
  /files/runas.sh $USER_ID $GROUP_ID $UMASK env HOME=$FILEBOT_DATA filebot -script fn:sysinfo
  echo "---------------------------------------------------------------------------------------"
}

#-----------------------------------------------------------------------------------------------------------------------

echo "$(ts) Starting FileBot container"

initialize_configuration

check_filebot_sh_version

create_conf_and_sh_files

validate_configuration

setup_opensubtitles_account

configure_java_prefs

print_filebot_info