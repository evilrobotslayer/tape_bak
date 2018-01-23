#!/bin/bash
#
# A UNIX / Linux shell script to backup dirs to tape device like /dev/st0 (linux)
# This script make both full and incremental backups.
# You need at two sets of five  tapes. Label each tape as Mon, Tue, Wed, Thu and Fri.
# You can run script at midnight or early morning each day using cronjons.
# The operator or sys admin can replace the tape every day after the script has done.
# Script must run as root or configure permission via sudo.
# -------------------------------------------------------------------------
# Copyright (c) 1999 Vivek Gite <vivek@nixcraft.com>
# This script is licensed under GNU GPL version 2.0 or above
# -------------------------------------------------------------------------
# This script is part of nixCraft shell script collection (NSSC)
# Visit http://bash.cyberciti.biz/ for more information.
# -------------------------------------------------------------------------
# Last updated on : March-2003 - Added log file support.
# Last updated on : Feb-2007 - Added support for excluding files / dirs.
# -------------------------------------------------------------------------
# Modified heavily by georgeg@oit.rutgers.edu -- 08/05/14

LOGBASE=/root/backup/log
 
# Backup dirs; do not prefix /
BACKUP_ROOT_DIR="opt/backups"
 
# Get todays day like Mon, Tue and so on
NOW=$(date +"%a")
DATE=$(date +"%F")
 
# Tape device name
# georgeg #
# We want to store a weeks worth of archives to the tape before rotation.
# No point in using the auto-rewinding device node.  Using nst0 instead.
#TAPE="/dev/st0"
TAPE="/dev/nst0"
CHANGER="/dev/sg4"
 
# georgeg #
# Direct tar to send output to stdout so that tee can generate an md5sum and 
# add aggregate totals to log output just for s&gs.
TAR_ARGS="--totals -O"

# Exclude file
EXCLUDE_CONF=/root/.backup.exclude.conf
 
# Backup Log file
# georgeg #
# Configure logrotate to take take care of these.
LOGFILE=$LOGBASE/$DATE.backup.log
MD5=$LOGBASE/$DATE.md5
 
# Path to binaries
FIND=/usr/bin/find
MD5SUM=/usr/bin/md5sum
MKDIR=/bin/mkdir
MT=/bin/mt
MTX=/usr/sbin/mtx
TAR=/bin/tar
TEE=/usr/bin/tee
XARGS=/usr/bin/xargs
 
# ------------------------------------------------------------------------
# Excluding files when using tar
# Create a file called $EXCLUDE_CONF using a text editor
# Add files matching patterns such as follows (regex allowed):
# home/vivek/iso
# home/vivek/*.cpp~
# ------------------------------------------------------------------------
[ -f $EXCLUDE_CONF ] && TAR_ARGS="-X $EXCLUDE_CONF"
 
#### Custom functions #####
# Make a full backup
full_backup(){
	echo -e "Performing Full\n\n"
	local old=$(pwd)
	cd /
	$TAR $TAR_ARGS -cvpf $TAPE $BACKUP_ROOT_DIR
	# georgeg #
        # Do not rewind, or take tape offline.  We want to put 7 archives on the tape
        # and we explicitly set the non-rewinding tape device above.
        # $MT -f $TAPE rewind
        # $MT -f $TAPE offline
	cd $old
}
 
# Make a  partial backup
partial_backup(){
	# georgeg #
 	# Making major modifications here
	echo -e "Performing Partial\n\n"
	local old=$(pwd)
	cd /

	# There's no verification of the backup?  WTF?!
	# Let's add it here.
	# Use tar to archive everything newer than 1 day and then pipe it to tee.
	# Then tee will split the output to create md5 and write to tape.
	# After writing to tape rewind to previous file and its starting filemark
	# and then compare the md5.  If md5 is good continue on.
	echo -e "Starting tar operation\n\n"

	# Define arguments for find command.
	# Set min/max depth to 1 to only return subs and -ctime 0 for files created in last day.
	FIND_ARGS="-mindepth 1 -maxdepth 1 -ctime 0 -print"
	$FIND $BACKUP_ROOT_DIR $FIND_ARGS | $XARGS $TAR $TAR_ARGS -cvp | $TEE >($MD5SUM > $MD5) > $TAPE
	echo
	echo "tar and md5 completed!"

	# We should be at the end of the tape.  Tapes are terminated with 2 EOF markers.
	# This looks like an extra file, so jump back to previous file, then jump to its
	# file marker.  Man, tape I/O is kinda wonky.
	echo 
	echo "Seeking back to file"
	$MT -f $TAPE bsf 
	$MT -f $TAPE bsfm
	echo "Validating checksum"
	$MD5SUM -c $MD5 < $TAPE
	if [ $? -eq 0 ]
	then
		echo -e "Successful backup!\nMD5 Matches!"
	else
		echo -e "Backup not successful\nSomething went very very wrong. :("
	fi
	# Seek to end of tape so that we can add another archive tomorrow.
	$MT -f $TAPE eom 
	cd $old
}
 
# Make sure all dirs exist
verify_backup_dirs(){
	local s=0
	echo "Backup Directory: /$BACKUP_ROOT_DIR"
	for d in $BACKUP_ROOT_DIR
	do
		if [ ! -d /$d ];
		then
			echo "Error: /$d directory does not exist!"
			s=1
		fi
	done
	# if not; just die
	[ $s -eq 1 ] && exit 1
}

# georgeg #
# Function to rewind and eject tape
# Returns tape from drive to slot 1 in left cartridge
eject_tape(){
	$MT -f $TAPE offline
	$MTX -f $CHANGER unload 1
}

load_tape(){
	# Always load tape from slot 1
	SLOT="1"
	$MTX -f $CHANGER load 1
}
 
cron_logic(){
	# Make sure log dir exits
	[ ! -d $LOGBASE ] && $MKDIR -p $LOGBASE

	# Verify dirs
	verify_backup_dirs
 
	# georgeg #
	# Backup dumps full/partial already defined by the postgres dumping mechanism.
	# All we need to do is store the files to tape.  Weekly's get dumped by 
	# postgres every Thursday night, and incrementals are done on every day other 
	# than Thursday. So we never actually need to do a "full".
	echo "Today is: $NOW"
	case $NOW in
	#       Mon)    full_backup;;
        	Sun|Mon|Tue|Fri|Sat)    partial_backup;;
	        Wed)            partial_backup; eject_tape;;
        	Thu)            load_tape; partial_backup;;
	        *) ;;
	esac > $LOGFILE 2>&1
}

#### Main logic ####

if [ `id -u` != "0" ]; then
  echo "You must be root to run this script."
  exit 1
fi

case "$1" in
    cron)
	cron_logic 
	;;
    disp_bdir)
	verify_backup_dirs
	;;
    eject)
	eject_tape
	;;    
    load)
	load_tape
	;;
    full)
	#full_backup
	echo "Full backup support not included at this time"
	;;
    partial)
	partial_backup
	;;	
    *)
	echo "Usage: tape_backup.sh [cron|verify|eject|load|full|partial]" >&2
	echo "  cron - Indicates cron is running the backup and uses automated logic" >&2
	echo "  disp_bdir - Displays the set backup directory and verifies that it exists" >&2
	echo "  eject - Ejects tape to cartridge in tape robot" >&2
	echo "  load - Loads new tape from cartridge in tape robot" >&2
	#echo "  full - Performs full backup on backup dir" >&2
	echo "  partial - Performs partial backup on backup dir (files created in last day)" >&2
	echo ""
	exit 3
	;;
esac

