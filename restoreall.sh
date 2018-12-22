#!/bin/bash
# This script will carry out a restore operation
# This operation restores all files backed up by scripts fbackup.sh and dbackup.sh back to the central home directory (e.g. /home)
# The restore will begin with first backup directory (created by fbackup.sh) and will continue with the differential backup directories (in the same order in which they were created) until the content of the last created backup folder is restored to the home filesystem
#
#                  ---prompt for parameters file check ---
param='/root/brcsparam'; #path of the parameters file
clear;
echo "Please check file $param to determine if all parameters are set up correctly"; #prompt user for check
echo 'Enter ok when done or any other key combination (including ENTER) to exit script'; # ok - check is done; any other combination/ENTER - exit script
echo; 
read data_input;
clear;
if [[ $data_input != 'ok' ]]; then #if a combination different from 'ok' was entered
    echo 'Script aborted'; #end of script
    echo; 
    exit 2;
fi
#
#                  _____________Local variables________________________________________________
# 
central_backup_dir=`sed '1q;d' "$param"`; #read absolute path of the central backup folder from the first line of the parameters file
homedir=`sed '3q;d' "$param"`; #read absolute path (mount point) of the actual home filesystem (where all files will be restored) from the third line of the parameters file; 
dat="date +%d.%m.%Y_%H:%M:%S"; #placeholder for the instruction showing the current date (including hour/min/sec). Usage: echo `$dat`
backuplist=$central_backup_dir/backuplist; #backuplist.txt 
operations_log=$central_backup_dir/operations_log; #operations_log.txt
temp_operations_log=$central_backup_dir/temp_operations_log; #temp_operations_log.txt
restore_errors=$central_backup_dir/restore_errors; #restore_errors.txt
temp=$central_backup_dir/temp; #temp.txt
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
#
# *** Pre-Restore Instructions ***
#
if [[ ! -d "$homedir" ]]; then #if actual home filesystem does not exist or the mount point is an invalid directory
    clear;
    echo "The home filesystem directory used for restore does not exist or path $homedir is invalid"; 
    echo 'Script aborted'; #error message, end of script
    echo; 
    exit 1;
fi
#
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
> "$restore_errors"; #create restore_errors.txt as empty file or empty it if already existing
#
echo _____Restore_`$dat`_____ > "$temp_operations_log"; #add header for current restore to temp_operations_log.txt
echo >> "$temp_operations_log";
clear; 
echo 'Erasing actual content of home partition...'; 
echo `$dat` '-> erasing actual content of home partition to ensure a clean restore...' >> "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
cd "$homedir"; #cd to the actual home filesystem directory
rm -r *; #remove all content of home partition
echo 'DONE' | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
echo 'Proceeding to restore...' | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
let "all_backup_dirs_restore_total=0"; #total number of items contained (according to log.txt files) in all backup directories 
let "total_existing_dirs=0"; #total number of times (during the whole restore operation) when a directory had already been restored from a previous backup folder, so it didn't need to be restored from current backup directory
let "total_restored_dirs=0"; #total number of directories that were restored during the whole restore operation 
let "total_restored_files=0"; #total number of files that were restored during the whole restore operation
let "total_failed_restores=0"; #total number of failed restore attempts
let backup_dirs_total=$(lcount "$backuplist"); #total number of backup directories
let "backup_dirs_restored=0"; #current number of backup directories which were fully restored by script
#
# *** Actual restore operation ***
#
echo `$dat` '-> Start of restore operation' >> "$temp_operations_log"; #start of restore operation
while read -r bpath; do #name of current backup directory
    cd "$central_backup_dir"; #cd to central backup directory
    echo >> "$temp_operations_log"; 
    echo "Restoring from backup directory $central_backup_dir/$bpath" >> "$temp_operations_log";
    echo >> "$temp_operations_log"; 
    cd "$bpath" 2>> "$temp_operations_log"; #cd to current backup directory
    if [[ $? != 0 ]]; then #if cd operation failed
	clear; 
	echo "Cannot reach current backup directory $central_backup_dir/$bpath" | tee -a "$temp_operations_log"; #error, end of script 
	echo 'Script aborted' | tee -a "$temp_operations_log"; 
	echo; 
	exit 1; 
    fi
    bpath=$central_backup_dir/$bpath; #get absolute path of current backup folder
    logpath=$bpath/log; #absolute path of the log.txt file contained in current backup folder
    if [[ ! -e "$logpath" ]]; then #if log.txt does not exist
	clear;
	echo "Cannot find $logpath" | tee -a "$temp_operations_log";
	echo 'Script aborted' | tee -a "$temp_operations_log"; #error message, end of script
	echo; 
	exit 1;
    fi
    restore_total=$(lcount "$logpath"); #total number of items to be restored from the current backup directory
    let "remaining=$restore_total"; #items left to restore from current backup folder
    let "restored_dirs=0"; #current number of directories restored from current backup folder
    let "restored_files=0"; #current number of files restored from current backup folder
    let "existing_dirs=0"; #current number of directories that don't need to be restored from current backup folder (already restored from previous backup directories)
    let "failed_restores=0"; #current number of failed restore attempts from current backup folder
    clear;
    echo 'Restoring items...'; #restore operation - first screen 
    echo; 
    echo "Total backup directories: $backup_dirs_total"; 
    echo "Fully restored backup directories: $backup_dirs_restored"; 
    echo "Current backup directory: $bpath"; 
    echo 'Current backup directory statistics: '; 
    echo "-> total items to be restored: $restore_total"; 
    echo "-> restored directories: $restored_dirs"; 
    echo "-> duplicate directories: $existing_dirs"; 
    echo "-> restored files: $restored_files"; 
    echo "-> failed restores: $failed_restores"; 
    echo "-> items left to restore: $remaining"; 
    echo;
    while read -r bentry; do #read absolute path of current item from current backup folder 
	echo; 
	echo "Current item: $bpath/$bentry";
	echo; 
	echo `$dat` "-> checking $bpath/$bentry" >> "$temp_operations_log";
	if [[ -d "$bentry" ]]; then #if current item is a directory
	    if [[ -d "$homedir/$bentry" ]]; then #if the directory had already been restored to the home partition 
		let "existing_dirs=$existing_dirs+1"; #update variables
		let "total_existing_dirs=$total_existing_dirs+1";
		echo "Directory already restored: $homedir/$bentry" | tee -a "$temp_operations_log"; #no need to restore
	    else 
		echo "Restoring directory to: $homedir/$bentry" | tee -a "$temp_operations_log";
		echo; 
		mkdir -p "$homedir/$bentry" 2>> "$temp_operations_log"; #recreate directory by preserving the relative path to home partition
		if [[ $? != 0 ]]; then #check if operation was successful; if not: 
		    echo "$bpath/$bentry" >> "$restore_errors"; #write the directory path to restore_errors.txt
		    let "failed_restores=$failed_restores+1"; #increment number of failed restore attempts from current backup directory
		    let "total_failed_restores=$total_failed_restores+1"; #increment total number of failed restore attempts (from all backup folders)
		    echo 'Error! Cannot restore' | tee -a "$temp_operations_log"; #error message 
		else #if operation successful 
		    let "restored_dirs=$restored_dirs+1"; #increment number of directories restored from current backup folder
		    let "total_restored_dirs=$total_restored_dirs+1"; #increment total number of directories restored from all backup folders
		    echo 'DONE' | tee -a "$temp_operations_log"; #confirm operation success
		fi
	    fi
	elif [[ -e "$bentry" ]]; then #if current item is a file 
	    echo "Restoring file to: $homedir/$bentry" | tee -a "$temp_operations_log";
	    echo; 
	    cp --parents "$bentry" "$homedir" 2>> "$temp_operations_log"; #file is restored by preserving the relative path to the home filesystem
	    if [[ $? != 0 ]]; then #check if operation was successful; if not:  
		echo "$bpath/$bentry" >> "$restore_errors"; #write the file path to restore_errors.txt
		let "failed_restores=$failed_restores+1"; #increment number of failed restore attempts from current backup directory
		let "total_failed_restores=$total_failed_restores+1"; #increment total number of failed restore attempts (from all backup folders)
		echo 'Error! Cannot restore' | tee -a "$temp_operations_log"; #error message
	    else #if operation successful
		let "restored_files=$restored_files+1"; #increment number of files restored from current backup directory
		let "total_restored_files=$total_restored_files+1"; #increment total number of files restored from all backup folders
		echo 'DONE' | tee -a "$temp_operations_log"; #confirm operation success
	    fi
	else #if item cannot be found in the current backup directory 
	    echo "$bpath/$bentry" >> "$restore_errors"; #write item path to restore_errors.txt 
	    let "failed_restores=$failed_restores+1"; #increment number of failed restore attempts from current backup directory
	    let "total_failed_restores=$total_failed_restores+1"; #increment total number of failed restore attempts (from all backup folders)
	    echo 'Error! Item not found, cannot restore' | tee -a "$temp_operations_log"; #error message
	fi
	let "remaining=$remaining-1"; #decrement number of items left to be restored
	clear;
	echo 'Restoring items...'; #restore operation - screen update
	echo; 
	echo "Total backup directories: $backup_dirs_total";
	echo "Fully restored backup directories: $backup_dirs_restored";
	echo "Current backup directory: $bpath";
	echo 'Current backup directory statistics: '; 
	echo "-> total items to be restored: $restore_total";
	echo "-> restored directories: $restored_dirs";
	echo "-> duplicate directories: $existing_dirs";
	echo "-> restored files: $restored_files";
	echo "-> failed restores: $failed_restores";
	echo "-> items left to restore: $remaining"; 
	echo;
    done < "$logpath"; 
    let "backup_dirs_restored=$backup_dirs_restored+1"; #increment number of fully restored backup directories
    let "all_backup_dirs_restore_total=$all_backup_dirs_restore_total+$restore_total"; #update total number of items contained in all backup folders
    if [[ $restore_total == 0 ]]; then #no items to be restored, log to temp_operations_log.txt
	echo 'No items to be restored' >> "$temp_operations_log"; 
    fi
done < "$backuplist";
# last screen of the active restore operations (purpose is a final update of the number of fully restored backup directories)
clear;
echo 'Restoring items...'; 
echo; 
echo "Total backup directories: $backup_dirs_total";
echo "Fully restored backup directories: $backup_dirs_restored";
echo; 
echo; 
echo 'Restore finished!';
# post-restore operations, final output
clear; 
echo >> "$temp_operations_log"; 
echo 'Setting up permissions for restored items...'; 
echo `$dat` '-> setting up permissions for restored items...' >> "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
find "$homedir" | sed '1d' | sort > "$temp"; #absolute paths of the restored items
while read -r rentry; do 
    if [[ -d "$rentry" ]]; then #if restored item is a directory
	chmod 755 "$rentry"; #set permission drwxr-xr-x
    else #if item is a file
	chmod 644 "$rentry"; #set permission -rw-r--r--
    fi
done < "$temp"; 
echo 'DONE' | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
clear;
echo `$dat` '-> restore finished' >> "$temp_operations_log"; #active restore operations finished 
echo >> "$temp_operations_log"; 
echo 'Summary of restore operations: ' | tee -a "$temp_operations_log"; #summary of restore operations
echo "-> total number of items contained in all backup folders: $all_backup_dirs_restore_total" | tee -a "$temp_operations_log"; 
echo "-> total number of restored files: $total_restored_files" | tee -a "$temp_operations_log";
echo "-> total number of restored directories: $total_restored_dirs" | tee -a "$temp_operations_log";
echo "-> total number of duplicate directories: $total_existing_dirs" | tee -a "$temp_operations_log";
echo "-> total number of failed restore attempts: $total_failed_restores" | tee -a "$temp_operations_log";
echo "-> content restored from $backup_dirs_restored backup directories" | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
if [[ -s "$restore_errors" ]]; then #if restore errors occurred
    echo 'Some items could not be restored' | tee -a "$temp_operations_log"; 
    echo "For details please check $restore_errors" | tee -a "$temp_operations_log"; 
else 
    rm "$restore_errors"; #remove restore_errors.txt if no errors occurred
    echo 'All items were successfully restored' | tee -a "$temp_operations_log"; 
fi
rm "$temp"; #remove temp.txt
echo | tee -a "$temp_operations_log"; 
echo `$dat` '-> all operations completed' >> "$temp_operations_log"; #all restore and post-restore operations are finished
mv "$temp_operations_log" "$operations_log"; #temp_operations_log.txt renamed operations_log.txt
exit 0; #end of script
