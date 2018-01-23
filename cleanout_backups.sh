#! /bin/sh
#
# The purpose of this script is to clear out 
# backup dumps older than 40 days, and to
# clear out logs older than 365 days.
#
# It gets run daily by a cron job at 7am (EST).
# 0 5 * * * /root/bin/cleanout_backups.sh
#
# georgeg@oit.rutgers.edu
###############################################

find /opt/backups -type d -ctime +40 -print0 | sort | xargs -0 rm -rf
find /root/backup/log -type f -ctime +365 -print0 | sort | xargs -0 rm -rf
