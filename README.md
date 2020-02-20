# Bash backup script.
### This is script for backup MySQL databases and files from Linux-server via SMB or FTP.

## Dependences
###### For Debian-based systems
You will need to install smbclient or ftp-client and mailutils (optional, for sending unsuccessful report if you have mailserver)
```
sudo apt update && sudo apt install mailutils ftp
```
or if you need to use SMB
```
sudo apt update && sudo apt install mailutils smbclient
```
## Usage
1. Put this script to `</root>` 
2. Open backup.sh on text-editor
3. Using tips in the script set variables:
   CLIENT 
   MYSQLBAK
   EMAIL (optioanal)
   DEST
   FTPHOST or SMBHOST
if you need to use SMB:
   SMBUSER
   SMBPASS
   SMBRESURS
4. If you need to use ftp-client put .netrc to `/root` and set correct permissions

   `sudo chown root:root /root/.netrc && sudo chmod 600 /root/.netrc`
   
5. Open .netrc in text-editor and set correct authentication data
6. Add cron-task to root-crontab.

`sudo echo "0 2 * * *	root	/root/backup.sh 2>/dev/null" >> /etc/crontab`
