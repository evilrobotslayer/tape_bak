#!/bin/bash
#
# This script will take a tape with multiple tar archives
# and extract them straight to disk.  Load tape before running.
# georgeg@oit.rutgers.edu -- 04/29/15

#LOGBASE=/root/backup/log
 
# Recover dirs
# Directory to dump tape archives into
RECOVER_ROOT_DIR="/root/backup/tape_recovery"
 
# Tape device name
# georgeg #
# Use non-rewinding node (nst0) so that multiple archives can easily be pulled
#TAPE="/dev/st0"
TAPE="/dev/nst0"
CHANGER="/dev/sg4"
 
# Backup Log file
# georgeg #
# Configure logrotate to take take care of these.
#LOGFILE=$LOGBASE/$DATE.backup.log
#MD5=$LOGBASE/$DATE.md5
 
# Path to binaries
#MD5SUM=/usr/bin/md5sum
MT=/bin/mt
MTX=/usr/sbin/mtx
TAR=/bin/tar
#TEE=/usr/bin/tee
#XARGS=/usr/bin/xargs

# Script assumes tape is already loaded
# Load tape from slot 1
#$MTX -f $CHANGER load 1

# Wind to end of tape and get file count
$MT -f $TAPE eom
NRFILES=`mt -f /dev/nst0 status | grep file | cut -d' ' -f 4`
echo "Number of archives on tape: $NRFILES"

# Rewind tape
$MT -f $TAPE rewind

for idx in `seq 1 $NRFILES`; do
  $TAR -C $RECOVER_ROOT_DIR -xvf $TAPE && 
  $MT -f $TAPE fsf &&
  echo "Archive $idx Recovered"
  echo "======================"
  echo ""
done;

$MT -f $TAPE offline
$MTX -f $CHANGER unload 1
echo "Recovery finished: Tape rewound & ejected"

