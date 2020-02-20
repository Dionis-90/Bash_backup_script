#!/bin/bash
##Add to crontab example
# 0 2 * * *	root	/root/backup.sh 2>/dev/null

###VARIABLES
##Choose upload client
# 1 - use FTP-client (.netrc require for auth.)
# 2 - SMB-client
CLIENT='2'

##MYSQL BACKUP
#1 - Use MySQL backup
MYSQLBAK='1'
NONSTARTDSKPERCENT="90"

FTPHOST='192.168.1.3'
SMBHOST='192.168.1.3'
SMBUSER='backup'
SMBPASS='your_SMB-Password'
SMBRESURS='backup'
DATE=`date +"%Y-%m-%d"`
TIME=`date +"%H:%M:%S"`
EMAIL='root'
BACKUPLOGPTH="/var/log/backup-${DATE}.log"

#Set your space-separeted pathes which you will need to backup.
DEST="`ls /home/`"
#Example
#DEST="/root/1 /root/2 /etc"

echo -e "$DATE $TIME\n--------------------------------------------------------------------------------------------" >> $BACKUPLOGPTH

function error() {
echo "Backup unsuccessful on `hostname`." | mail -s "Backup unsuccessful" $EMAIL -A $BACKUPLOGPTH
exit 1
}

#You will need to use auth_socket plugin for mysql-user root. Or specify parameter -pYour_password for mysql and mysqladmin.
MYSQLDBS=`mysql -Bse "show databases;" | grep -v '.*_schema' | grep -v 'sys' | grep -v 'test' | xargs`

[ "$CLIENT" -eq "1" ] && which ftp > /dev/null && REMOTE="ftp $FTPHOST" && echo "Using FTP." >> $BACKUPLOGPTH
[ "$CLIENT" -eq "2" ] && which smbclient > /dev/null && REMOTE="smbclient -U $SMBUSER //$SMBHOST/$SMBRESURS $SMBPASS" && echo "Using SMB." >> $BACKUPLOGPTH
[ -z "${REMOTE}" ] && echo "Selected client does not exist in system. Please install the client." >> $BACKUPLOGPTH  && error

if (( `df -h | grep "^/.*/$" | awk '{print $5}' | grep -o '[0-9]*'` > "$NONSTARTDSKPERCENT" ))
	then
	echo "Too small free disk space. Exiting.." >> $BACKUPLOGPTH
	error
fi

echo "mkdir $DATE" | ${REMOTE}
[ "${PIPESTATUS[1]}" -eq 1 ] && echo "No connection to remote server. Exiting.." >> $BACKUPLOGPTH && error

echo -e "cd $DATE\nmkdir DBS" | ${REMOTE}
cd /tmp

function mysqlbak() {
[ `mysqladmin ping 2> /dev/null | grep -c alive` -eq "0" ] && echo "No connection to mysql" >> $BACKUPLOGPTH && error
[ -z "${MYSQLDBS}" ] && echo "Databeses for backup is not found." >> $BACKUPLOGPTH && error
for d in ${MYSQLDBS}
	do
	echo "Dumping DB ${d}..." >> $BACKUPLOGPTH
	mysqldump $d > /tmp/${d}.sql
	nice tar -zcf /tmp/${d}.sql.tgz ${d}.sql
	echo "Uploading DB ${d}..." >> $BACKUPLOGPTH
	echo -e "cd $DATE\ncd DBS\n`[ "$CLIENT" -eq "1" ] && echo 'binary'`\nput ${d}.sql.tgz" | ${REMOTE}
	rm -f /tmp/${d}.sql
	rm -f /tmp/${d}.sql.tgz
	echo "Removing dump of ${d}." >> $BACKUPLOGPTH
done
}

if [ "$MYSQLBAK" -eq "1" ]
	then
	mysqlbak
	else
	echo "MySQL backup not enabled" >> $BACKUPLOGPTH
fi


[ -z $DEST ] && echo "Folders for backup is not specified. Please see readme." >> $BACKUPLOGPTH && error
for i in ${DEST}
	do
	FOLDERNAME=`echo $i | sed 's,/,-,g'`
	OBJNAME="$FOLDERNAME.tgz"
	echo "Packing $OBJNAME..." >> $BACKUPLOGPTH
	nice tar -zcf /tmp/${OBJNAME} $i
	echo "Uploading $OBJNAME..." >> $BACKUPLOGPTH
	echo -e "cd $DATE\n`[ "$CLIENT" -eq "1" ] && echo 'binary'`\nput ${OBJNAME}" | $REMOTE
	rm -f /tmp/${OBJNAME}
	echo "File $OBJNAME removed from local." >> $BACKUPLOGPTH
done
echo "Done!" >> $BACKUPLOGPTH
exit 0
