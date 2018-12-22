#!/bin/bash
# This script will do a differential backup of the home filesystem by considering only items that were added, removed or changed since last backup 
#
#                  _____________Local variables________________________________________________
# 
param='/root/brcsparam'; #variable that stores the path of the parameters file
central_backup_dir=`sed '1q;d' "$param"`; #reading the path of the central backup folder from the first line of the parameters file
old_homedir=`sed '2q;d' "$param"`; #reading the path of the previous home filesystem directory (previous mountpoint) from the second line of the parameters file 
homedir=`sed '3q;d' "$param"`; #reading the path of the actual home filesystem directory (actual mountpoint) from the third line of the parameters file 
dat="date +%d.%m.%Y_%H:%M:%S"; #placeholder for the instruction showing the current date (including hour:min:second). Usage: echo `$dat`
bdir=dbackup_`$dat`; #differential backup directory name
backup_dir=$central_backup_dir/$bdir; #absolute path of the differential backup directory
backuplist=$central_backup_dir/backuplist; #backuplist.txt 
olddir=$central_backup_dir/olddir; #olddir.txt
operations_log=$central_backup_dir/operations_log; #operations_log.txt
temp_operations_log=$central_backup_dir/temp_operations_log; #temp_operations_log.txt
backup_operations_log=$backup_dir/backup_operations_log; #backup_operations_log.txt
newdir=$central_backup_dir/newdir; #newdir.txt
todelete=$central_backup_dir/todelete; #todelete.txt
tobackup=$central_backup_dir/tobackup; #tobackup.txt
tocheck=$central_backup_dir/tocheck; #tocheck.txt
log=$central_backup_dir/log; #log.txt
backup_errors=$central_backup_dir/backup_errors; #backup_errors.txt
bdate=$central_backup_dir/bdate; #bdate.txt
temp_bdate=$central_backup_dir/temp_bdate; #temp_bdate.txt
temp=$central_backup_dir/temp; #temp.txt
temp1=$central_backup_dir/temp1; #temp1.txt
#
#                  _____________Functions_______________________________________________________
function lcount { #this function is used to count the lines from one file
    s=`wc -l "$1"`; #the number of lines of the file indicated by the first argument of the function (along with the name of the file) are stored in the variable s
    arr=( $s ); #variable arr is an array that stores the content of s (arr[0] will contain the actual number of lines from file $1) 
    echo ${arr[0]}; 
}
#
#                _________ Script instructions__________________________________________________
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
    let "hlength_old=`echo ${#old_homedir}`+1"; #calculate length of the previous home filesystem directory path (including the "/" after the directory name, e.g. /home/ -> last /) 
    let "hlength=`echo ${#homedir}`+1"; #calculate length of the actual home filesystem directory path (including the "/" after the directory name, e.g. /home/ -> last /) 
fi
if [[ ! -d "$central_backup_dir" ]]; then #if central backup folder does not exist
    clear; 
    echo "Central backup directory does not exist or the path $central_backup_dir is invalid";
    echo 'Script aborted'; #error message, end of script
    echo; 
    exit 1;
elif [[ ! -e "$backuplist" ]]; then #if file containing list of backups does not exist
    clear; 
    echo "File $backuplist not found";
    echo 'Script aborted'; #error message, end of program
    echo;
    exit 1;
elif [[ ! -e "$olddir" ]]; then #if file olddir.txt (containing absolute paths of all home filesystem items that existed when previous backup took place) does not exist
    clear;
    echo "File $olddir not found";
    echo 'Script aborted'; #error message, end of program
    echo; 
    exit 1;
else
    fbackupdir=`sed '1q;d' "$backuplist"`; #name of the full backup directory is read from first line of backuplist.txt
    firstchar=${fbackupdir:0:1}; #first character of the full backup directory name
    cd "$central_backup_dir"; #cd to central backup directory
    if [[ ! -d "$fbackupdir" ]] || [[ $firstchar != 'f' ]]; then #if the full backup directory does not exist or name does not begin with small 'f'
	clear;
	echo 'No full backup directory found';
	echo 'Script aborted'; #error message, end of program
	echo; 
	exit 1;
    fi
fi
#
echo _____Diff_Backup_"$backup_dir"_____ | tee "$temp_bdate" > "$temp_operations_log"; #a header for the current backup is written to temp_operations_log.txt and temp_bdate.txt; temp_bdate.txt will be renamed bdate.txt after the script was successfully executed; bdate.txt is used by differential backup scripts to check which files/directories changed since previous backup. 
echo >> "$temp_operations_log";
mkdir "$backup_dir"; #create differential backup directory
> "$log"; #log.txt is created
> "$backup_errors"; #create backup_errors.txt
clear; 
echo "Scanning $homedir..."; 
echo `$dat` "-> scanning $homedir, searching for all files/directories..." >> "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
find "$homedir" | sed '1d' | sort > "$newdir"; #the current home filesystem structure is recreated in newdir.txt; the first line containing the mountpoint of the home filesystem (e.g. /home) is removed
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
let "col_nr_old=$hlength_old+1"; #parameter used for calculating relative paths to the old home filesystem directory (folder in which all user home directories were located when previous backup was made) 
let "col_nr=$hlength+1"; #parameter used for calculating relative paths to the actual home filesystem directory (folder in which all user home directories are currently located) 
cut -c $col_nr_old- "$olddir" | sort > "$temp"; #relative paths to old home filesystem directory written to temp.txt
cut -c $col_nr- "$newdir" | sort > "$temp1"; #relative paths to actual home filesystem directory written to temp1.txt
comm -23 "$temp" "$temp1" | sort > "$todelete"; #items that were deleted from the home filesystem since last backup (to be marked as deleted)
comm -13 "$temp" "$temp1" | sort > "$tobackup"; #items that were added to the home filesystem since last backup (to be backed up) 
comm -12 "$temp" "$temp1" | sort > "$tocheck"; #items that were kept in the home filesystem since last backup (to be checked; to be backed up only if they changed since last backup) 
#
# *** Actual Backup ***
#
echo `$dat` '-> backup started' >> "$temp_operations_log"; #start of backup 
#
line_nr_td=$(lcount "$todelete"); #number of items to be marked as deleted
line_nr_tb=$(lcount "$tobackup"); #number of items to be backed up in Phase 1
line_nr_tc=$(lcount "$tocheck"); #number of items to be checked in Phase 2
line_nr_blist=$(lcount "$backuplist"); #number of backup folders previously created
prev_backup_dir=$central_backup_dir/`sed "$line_nr_blist"'q;d' "$backuplist"`; #absolute path of previous backup directory
#
cd "$homedir"; #cd to home filesystem directory
#
# Phase 1: copy items that have been changed and directories that have been kept since last backup
echo >> "$temp_operations_log"; 
echo 'Step 1: all items changed and all directories kept since last backup to be copied to current backup directory' >> "$temp_operations_log"; #start of phase 1
let "total_lines_tc=$line_nr_tc"; #total number of items kept in the home filesystem since last backup
let "checked=0"; #current number of checked items
let "backed_up=0"; #current number of items (out of the checked ones) that have been backed up 
let "errors=0"; #current number of items (out of the checked ones) that failed to be backed up 
clear;
echo "Step 1: checking unchanged item paths"; #phase 1 - first screen 
echo | tee -a "$temp_operations_log"; 
echo "Total: $total_lines_tc";
echo "Checked: $checked";
echo "Backed up: $backed_up"; 
echo "Errors: $errors"; 
echo "Items left to check: $line_nr_tc";
echo; 
while read -r tc; do #current item to be checked 
    echo; 
    echo "Currently checked: $homedir/$tc"; #display absolute path
    echo; 
    echo `$dat` "-> checking $homedir/$tc" >> "$temp_operations_log";
    if [[ -d "$tc" ]]; then #if item is a directory
	echo 'Backing up directory...'; #it should be backed up
	echo; 
	echo "Copying directory to $backup_dir/$tc..." >> "$temp_operations_log";
	echo "$tc" >> "$todelete"; #add item to todelete.txt
	mkdir -p "$backup_dir/$tc" 2>> "$temp_operations_log"; #recreate the directory in the backup folder by preserving the relative path to the home partition
	if [[ $? != 0 ]]; then #if not successfully backed up 
	    let "errors=$errors+1"; #increment number of backup errors
	    echo 'Error, cannot copy directory' | tee -a "$temp_operations_log"; #error message 
	    echo "$homedir/$tc" >> "$backup_errors"; #absolute path written to backup_errors.txt
	else 
	    let "backed_up=backed_up+1"; #number of backed up items (out of the checked ones) is incremented
	    echo 'DONE' | tee -a "$temp_operations_log"; #confirm operation success
	fi 
    elif [[ "$tc" -nt "$bdate" ]] || [[ -d "$prev_backup_dir/$tc" ]]; then #if checked item is a file and has been modified since last backup 
	echo 'File changed. Backing up...'; #it is backed up 
	echo; 
	echo "File changed, copying to $backup_dir/$tc" >> "$temp_operations_log";
	echo "$tc" >> "$todelete"; #add item to todelete.txt
	cp --parents "$tc" "$backup_dir" 2>> "$temp_operations_log"; #file is copied to backup directory by preserving the relative path to the home partition
	if [[ $? != 0 ]]; then #if not successfully backed up 
	    let "errors=$errors+1"; #increment number of backup errors
	    echo 'Error, cannot copy file' | tee -a "$temp_operations_log"; #error message
	    echo "$homedir/$tc" >> "$backup_errors"; #absolute path written to backup_errors.txt
	else 
	    let "backed_up=backed_up+1"; #number of backed up files (out of the checked ones) is incremented
	    echo 'DONE' | tee -a "$temp_operations_log"; #confirm operation success 
	fi 
    else
	echo "File hasn't changed, no need to backup" | tee -a "$temp_operations_log"; #no change, no backup
    fi
    let "checked=$checked+1"; #increment the number of checked files 
    let "line_nr_tc=$line_nr_tc-1"; #decrement the number of files left to check 
    clear;
    echo "Step 1: checking unchanged item paths"; #phase 1 - screen update 
    echo;
    echo "Total: $total_lines_tc";
    echo "Checked: $checked";
    echo "Backed up: $backed_up"; 
    echo "Errors: $errors"; 
    echo "Items left to check: $line_nr_tc";
    echo; 
done < "$tocheck"; 
let "total_backed_up=$backed_up"; #total number of backed up items
let "total_checked_backed_up=$backed_up+$errors"; #total number of backed up items in Phase 1 (including backup errors)
let "total_errors=$errors"; #total number of errors
#
# Phase 2: copy files that have been added to the home filesystem since last backup
echo >> "$temp_operations_log"; 
echo 'Step 2: all items added to home filesystem since last backup to be copied to current backup directory' >> "$temp_operations_log"; #start of phase 2
let "total_lines_tb=$line_nr_tb"; #total number of items added to home filesystem since last backup 
let "backed_up=0"; #number of items (out of $total_lines_tb) currently backed up 
let "errors=0"; #number of items (out of $total_lines_tb) that failed to be backed up 
clear; 
echo "Step 2: copying items added to home filesystem since last backup"; #phase 2 - first screen
echo | tee -a "$temp_operations_log"; 
echo "Total: $total_lines_tb"; 
echo "Backed up: $backed_up"; 
echo "Errors: $errors"; 
echo "Items left to backup: $line_nr_tb";
echo; 
while read -r tb; do #current item to be backed up 
    echo;
    echo "Currently backed up: $homedir/$tb"; #absolute item path
    echo; 
    echo `$dat` "-> copying $homedir/$tb to $backup_dir/$tb:" >> "$temp_operations_log";
    if [[ -d "$tb" ]]; then #if item is a directory 
	mkdir -p "$backup_dir/$tb" 2>> "$temp_operations_log"; #recreate it in the backup folder by preserving the relative path to the home partition 
    else #if item is a file
	cp --parents "$tb" "$backup_dir" 2>> "$temp_operations_log"; #file is copied to the backup directory by preserving the relative path to the home partition
    fi
    if [[ $? != 0 ]]; then #if item backup was not successful
	echo "$homedir/$tb" >> "$backup_errors"; #absolute item path written to backup_errors.txt
	let "errors=$errors+1"; #increment number of backup errors
	echo 'Error, cannot copy file/directory' | tee -a "$temp_operations_log"; #error message
    else
	let "backed_up=$backed_up+1"; #increment number of backed up files 
	echo 'DONE' | tee -a "$temp_operations_log"; #confirm operation was successful
    fi 
    let "line_nr_tb=$line_nr_tb-1"; #decrement number of files that haven't been backed up yet in this phase
    clear; 
    echo "Step 2: copying items added to home filesystem since last backup"; #phase 2 - screen update
    echo; 
    echo "Total: $total_lines_tb";
    echo "Backed up: $backed_up";
    echo "Errors: $errors";
    echo "Items left to backup: $line_nr_tb";
    echo; 
done < "$tobackup"; 
if [[ $backed_up == 0 ]]; then #if no items were backed up
    echo 'No items added since last backup' >> "$temp_operations_log"; #no items added since last backup
fi
# 
sort "$todelete" > "$temp"; 
mv "$temp" "$todelete"; #sort todelete.txt
#
# Phase 3: mark following items for deletion from all previous backup directories: 
# - items deleted from home filesystem since last backup
# - items changed since last backup AND were successfully backed up in phase 2
echo >> "$temp_operations_log"; 
echo 'Step 3: all items that were either successfully backed up in Step 2 or have been removed from home filesystem since last backup to be marked for deletion from previous backup directories' >> "$temp_operations_log"; #start of phase 3
clear; 
echo 'Step 3: marking items that were changed or removed since last backup as deleted from previous backup directories'; #phase 3 - first screen
echo | tee -a "$temp_operations_log"; 
echo "Backup directories still left to check: $line_nr_blist"; 
echo; 
let "deleted_from_backups=0"; #total number of instances (of items deleted from home filesystem since last backup), which were marked for deletion in all previous backup directories
cd "$central_backup_dir"; #cd to central backup directory 
while read -r bpath; do #reading "current" previous backup directory name from backuplist.txt
    if [[ ! -d "$bpath" ]]; then #if backup directory does not exist
	clear; 
	echo "Cannot reach previous backup directory $central_backup_dir/$bpath" | tee -a "$temp_operations_log"; #error, end of script 
	echo 'Script aborted' | tee -a "$temp_operations_log"; 
	echo; 
	exit 1; 
    fi
    bpath=$central_backup_dir/$bpath; #get absolute path of "current" previous backup folder
    logpath=$bpath/log; #absolute path of the log.txt file belonging to "current" previous backup
    if [[ ! -e "$logpath" ]]; then #if log.txt does not exist
	clear;
	echo "Cannot find $logpath" | tee -a "$temp_operations_log";
	echo 'Script aborted' | tee -a "$temp_operations_log"; #error message, end of script
	echo; 
	exit 1;
    fi
    mfd=$bpath/mfd; #absolute path of the mfd.txt file belonging to "current" previous backup
    echo;
    echo "Current backup directory: $bpath";
    echo `$dat` "-> marking following items from backup directory $bpath for deletion:" >> "$temp_operations_log"; 
    echo | tee -a "$temp_operations_log";
    comm -12 "$logpath" "$todelete" > "$temp1"; #items contained by both log.txt and todelete.txt are marked for deletion from current backup folder
    comm -23 "$logpath" "$todelete" | sort > "$temp"; #items belonging to log.txt but NOT to todelete.txt are kept in current backup folder
    mv "$temp" "$logpath"; #paths of the kept (not m.f.d.) items are rewritten to log.txt
    if [[ -s "$temp1" ]]; then #if temp1.txt is not empty
	cat "$temp1" | tee -a "$mfd" >> "$temp_operations_log"; #append m.f.d items to mfd.txt and temp_operations_log.txt
	echo 'Required items were m.f.d.'; #confirm m.f.d. 
    else
	echo 'No items were m.f.d.' | tee -a "$temp_operations_log"; #no items were m.f.d.
    fi
    let "deleted_from_backups=$deleted_from_backups+$(lcount "$temp1")"; #update total number of instances which were marked for deletion
    let "line_nr_blist=$line_nr_blist-1"; #decrement number of backup directories left to check for items to be m.f.d.
    clear; 
    echo 'Step 3: marking items that were changed or removed since last backup as deleted from previous backup directories'; #phase 3 - screen update
    echo;
    echo "Backup directories still left to check: $line_nr_blist"; 
    echo | tee -a "$temp_operations_log"; 
done < "$backuplist"; 
#
let "total_backed_up=$total_backed_up+$backed_up"; #update the total number of backed up items
let "total_errors=$total_errors+$errors"; #update the total number of errors
echo `$dat` '-> all backup steps completed' >> "$temp_operations_log"; #confirm end of active backup operations
echo >> "$temp_operations_log"; 
#
# final operations, closing the backup
let "blength=`echo ${#backup_dir}`+1"; #length of the backup directory path (including "/")
let "col_nr=$blength+1"; #variable used for calculating relative paths to home partition/backup directory (should be the same) 
find "$backup_dir" | sed '1d' | cut -c $col_nr- | sort > "$log"; #calculate paths of backed up items relative to backup directory and write them to log.txt
clear;
echo "Backup finished!" | tee -a "$temp_operations_log"; #last screen, operations summary
echo "_Items added to home filesystem since last backup: $total_lines_tb" | tee -a "$temp_operations_log"; 
echo "_Items changed and directories kept in home filesystem since last backup: $total_checked_backed_up" | tee -a "$temp_operations_log";
echo "_Items deleted from home filesystem since last backup: $line_nr_td" | tee -a "$temp_operations_log"; 
echo "_Total number of backed up items: $total_backed_up" | tee -a "$temp_operations_log";
echo "_Total number of instances marked for deletion from all previous backup directories: $deleted_from_backups" | tee -a "$temp_operations_log";
echo "_Backup errors: $total_errors" | tee -a "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
if [[ -s "$backup_errors" ]]; then #if backup errors occurred
    mv "$backup_errors" "$backup_dir"; #backup_errors.txt moved from central backup directory to full backup directory
    echo 'Some items could not be backed up' | tee -a "$temp_operations_log"; #notify user/admin
    echo "Please check $backup_dir/backup_errors for details" | tee -a "$temp_operations_log"; 
else
    echo 'All items were successfully backed up' | tee -a "$temp_operations_log"; #no errors, all items successfully backed up
    rm "$backup_errors"; #backup_errors.txt removed, no longer needed
fi
echo | tee -a "$temp_operations_log"; 
mv "$newdir" "$olddir"; #newdir.txt renamed olddir.txt
mv "$log" "$backup_dir"; #log.txt moved from central backup directory to full backup directory
echo $bdir >> "$backuplist"; #name of backup directory appended to backuplist.txt
rm "$todelete"; #remove todelete.txt
rm "$tobackup"; #remove tobackup.txt
rm "$tocheck"; #remove tocheck.txt
sed '2d' "$param" > "$temp1"; #replace second line of the parameters file (old home filesystem directory path)...
echo $homedir >> "$temp1"; #...with the content of the third line of the parameters file (actual home filesystem directory path) 
mv "$temp1" "$param"; #write changes back to parameters file
echo `$dat` '-> all operations completed' >> "$temp_operations_log"; #end of all operations
cat "$temp_operations_log" | tee "$operations_log" > "$backup_operations_log"; #temp_operations_log.txt copied to operations_log.txt (this file reflects the last backup/restore operation) and to backup_operations_log.txt (which is dedicated to this backup only)
rm "$temp_operations_log"; #remove temp_operations_log.txt
mv "$temp_bdate" "$bdate"; #temp_bdate.txt is renamed bdate.txt
exit 0; #end of script 
