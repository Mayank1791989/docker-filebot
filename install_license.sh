#!/bin/bash

. /files/FileBot.conf

function ts {
  echo [`date '+%b %d %X'`]
}

echo "$(ts) Installing license file"
/files/runas.sh $USER_ID $GROUP_ID $UMASK env HOME=$FILEBOT_DATA filebot --license /config/license/*.psm