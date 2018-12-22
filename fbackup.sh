#!/bin/bash
# This script will run a full backup of the home filesystem
#
# local variables
#
param='/root/brcsparam'; #variable that stores the path of the parameters file
central_backup_dir=`sed '1q;d' "$param"`; #absolute path of the central backup directory is read from the first line of the parameters file 
homedir=`sed '3q;d' "$param"`; #absolute path of the home filesystem directory (mountpoint of the home filesystem) is read from the third line of the parameters file 
dat="date +%d.%m.%Y_%H:%M:%S"; #placeholder for the instruction showing the current date (including hour:min:second). Usage: echo `$dat`
bdir=fbackup_`$dat`; #full backup directory name
backup_dir=$central_backup_dir/$bdir; #the absolute path of the full backup directory
log=$backup_dir/log; #log.txt
backup_errors=$backup_dir/backup_errors; #backup_errors.txt 
backuplist=$central_backup_dir/backuplist; #backuplist.txt
old_backuplist=$central_backup_dir/old_backuplist; #old_backuplist.txt
operations_log=$central_backup_dir/operations_log; #operations_log.txt
temp_operations_log=$central_backup_dir/temp_operations_log; #temp_operations_log.txt
backup_operations_log=$backup_dir/backup_operations_log; #backup_operations_log.txt
olddir=$central_backup_dir/olddir; #olddir.txt
bdate=$central_backup_dir/bdate; #bdate.txt
temp_bdate=$central_backup_dir/temp_bdate; #temp_bdate.txt
temp=$central_backup_dir/temp; #temp.txt
temp1=$central_backup_dir/temp1; #temp1.txt
#
# functions
function lcount { #this function is used to count the lines from one file
    s=`wc -l "$1"`; #the number of lines of the file indicated by the first argument of the function (along with the name of the file) are stored in the variable s
    arr=( $s ); #variable arr is an array that stores the content of s (arr[0] will contain the actual number of lines from file $1) 
    echo ${arr[0]}; 
}
#
# *** Pre-Backup Instructions ***
#
if [[ ! -d "$homedir" ]]; then #if the home filesystem directory does not exist
    clear;
    echo "Invalid home filesystem path: $homedir"; 
    echo 'Script aborted'; #error message, end of script
    echo;
    exit 1;
else
    let "hlength=`echo ${#homedir}`+1"; #length of the central home directory path (including the "/" after the directory name, e.g. /home/ -> last /) is calculated 
fi
if [[ ! -d "$central_backup_dir" ]]; then #if central backup directory does not exist 
    mkdir "$central_backup_dir"; #then it is created
    if [[ ! -d "$central_backup_dir" ]]; then #if central backup directory cannot be created an error is triggered and the script is terminated
	clear; 
	echo "Cannot create central backup directory: $central_backup_dir";
	echo 'Script aborted'; 
	echo;
	exit 1;
    fi 
fi
#
echo _____Full_Backup_"$backup_dir"_____ | tee "$temp_bdate" > "$temp_operations_log"; #a header for the current backup is written to temp_operations_log.txt and temp_bdate.txt; temp_bdate.txt is used as a temporary file and will be renamed bdate.txt after the script successfully executed; bdate.txt will be used by next running backup script (if differential) to check which items changed since this moment
echo >> "$temp_operations_log";
mkdir "$backup_dir"; #create full backup directory 
> "$backup_errors"; #create backup_errors.txt
clear; 
echo "Scanning $homedir..."; 
echo `$dat` "-> scanning $homedir, searching for all files/directories..." >> "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
find "$homedir" | sed '1d' | sort > "$olddir"; #the current home filesystem structure is recreated in olddir.txt. The first line is removed as it contains the central home directory path (not useful for backup). 
if [[ $? != 0 ]]; then #if scanning operation failed
    echo "Failed scanning $homedir" | tee -a "$temp_operations_log"; #error message, end of script
    echo 'Script aborted' | tee -a "$temp_operations_log"; 
    echo; 
    exit 1; 
fi
echo 'DONE' | tee -a "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
echo 'Starting backup...' | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
let "col_nr=$hlength+1"; #parameter used for calculating relative paths to the home filesystem directory (folder in which all user home directories are located) 
cat "$olddir" | cut -c $col_nr- | sort > "$log"; #relative pathnames of all items to the home partition are written to log.txt
> "$temp"; #create empty temp.txt file
#
# *** Actual Backup ***
#
echo `$dat` '-> backup started' >> "$temp_operations_log"; #start of backup 
echo >> "$temp_operations_log"; 
#
line_nr_log=$(lcount "$log"); #items still left to backup
let "total_lines=$line_nr_log"; #total number of items contained in the home partition
let "backed_up=0"; #current number of backed up items
let "errors=0"; #current number of items that couldn't be backed up (backup errors)
cd "$homedir"; #cd to home filesystem directory 
clear;
echo "Copying items..."; #first screen of the backup operation
echo; 
echo "Total: $total_lines"; 
echo "Backed up: $backed_up";
echo "Errors: $errors"; 
echo "Items left to backup: $line_nr_log"; 
echo;
while read -r line; do #read current item path from log.txt
    echo; 
    echo "Currently backed up: $homedir/$line"; #currently backed up item
    echo; 
    echo `$dat` "-> copying $homedir/$line to $backup_dir/$line..." >> "$temp_operations_log";
    if [[ -d "$line" ]]; then #if item is a directory
	mkdir -p "$backup_dir/$line" 2>> "$temp_operations_log"; #it is recreated in the backup directory by preserving the relative path to the home filesystem directory
    else #if item is a file
	cp --parents "$line" "$backup_dir" 2>> "$temp_operations_log"; #it is copied to the backup folder by preserving the relative path to the home filesystem directory
    fi
    if [[ $? != 0 ]]; then #if item was not successfully copied
	echo 'Error, cannot copy item' | tee -a "$temp_operations_log"; #error message
	echo "$line" >> "$temp"; #relative item path to home filesystem directory written to temp.txt
	echo $homedir/$line >> "$backup_errors"; #absolute item path written to backup_errors.txt
	let "errors=$errors+1"; #increment number of backup errors  
    else
	echo 'DONE' | tee -a "$temp_operations_log"; #item backup ended successfully 
	let "backed_up=$backed_up+1"; #increment the number of backed up items
    fi 
    let "line_nr_log=$line_nr_log-1"; #decrement the number of files that haven't been backed up yet
    clear; #clear screen
    echo "Copying items..."; #screen update
    echo; 
    echo "Total: $total_lines"; 
    echo "Backed up: $backed_up";
    echo "Errors: $errors"; 
    echo "Items left to backup: $line_nr_log"; 
    echo;
done < "$log"; 
echo >> "$temp_operations_log"; 
echo `$dat` '-> no more items to copy' >> "$temp_operations_log"; #no more items to backup
echo >> "$temp_operations_log"; 
clear;
echo "Backup finished!" | tee -a "$temp_operations_log"; #last screen, operations summary
echo "_Total number of items: $total_lines" | tee -a "$temp_operations_log";
echo "_Backed up: $backed_up" | tee -a "$temp_operations_log"; 
echo "_Backup errors: $errors" | tee -a "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
if [[ -s "$backup_errors" ]]; then #if backup errors occurred
    echo 'Some items could not be backed up' | tee -a "$temp_operations_log"; #notify user/admin
    echo "Please check $backup_errors for details" | tee -a "$temp_operations_log"; 
    sort "$temp" > "$temp1"; 
    mv "$temp1" "$temp"; #sort temp.txt
    comm -23 "$log" "$temp" | sort > "$temp1"; #log.txt cleanup, remove all items that couldn't be backed up 
    mv "$temp1" "$log"; #write cleaned-up output back to log.txt  
else
    echo 'All files and directories were successfully backed up!' | tee -a "$temp_operations_log"; #no errors, all items backed up successfully 
    rm "$backup_errors"; #backup_errors.txt removed, no longer needed
fi
echo | tee -a "$temp_operations_log";
if [[ -e "$backuplist" ]]; then #if backuplist.txt already exists (previous backups were made)
    cat "$backuplist" >> "$old_backuplist"; #append the actual content to old_backuplist.txt
fi
echo $bdir > "$backuplist"; #name of the full backup directory is overwritten to backuplist.txt
sed '2d' "$param" > "$temp"; #replace second line of the parameters file (old home filesystem directory path)...
echo "$homedir" >> "$temp"; #...with the content of the third line of the parameters file (actual home filesystem directory path)
mv "$temp" "$param"; #write changes back to parameters file
echo `$dat` '-> all operations completed' >> "$temp_operations_log"; #end of all operations
cat "$temp_operations_log" | tee "$operations_log" > "$backup_operations_log"; #temp_operations_log.txt copied to operations_log.txt (file which contains the log of the last operation, backup or restore) and to backup_operations_log.txt (a file dedicated to this backup only) 
rm "$temp_operations_log"; #file removed, no longer needed
mv "$temp_bdate" "$bdate"; #rename temp_bdate.txt to bdate.txt
exit 0; #end of script
