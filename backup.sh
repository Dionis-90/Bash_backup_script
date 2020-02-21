#!/bin/bash
source backup.conf

echo -e "$DATE $TIME\n--------------------------------------------------------------------------------------------" >> $BACKUPLOGPTH
[ ! -f "$BACKUPLOGPTH" ] && echo "Can not to create log-file. Probably you run script with not enough permissions! Exiting..." && exit 1

function error() {
echo "Backup unsuccessful on `hostname`." | mail -s "Backup unsuccessful" $EMAIL -A $BACKUPLOGPTH
exit 1
}

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
