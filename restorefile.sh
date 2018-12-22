#!/bin/bash
# This script will carry out a restore operation
# This operation restores items backed up by scripts fbackup.sh and dbackup.sh back to the home partition in a selective way: only the items (files/directories) chosen by user/admin will be restored. These can belong to different users. The items are selected by entering a keyword based on which a search will be performed by script. The found paths will be presented on the screen. If the admin acknowledges them, they will be retrieved from the backup folders and restored to the appropriate locations in the home filesystem.   
# The restore will begin with first backup directory (created by fbackup.sh) and will continue with the differential backup directories (in the same order in which they were created) until the required content of the last created backup folder is restored to home filesystem.
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
#                  _____________Local variables________________________________________________
# 
central_backup_dir=`sed '1q;d' "$param"`; #read absolute path of the central backup folder from the first line of the parameters file
old_homedir=`sed '2q;d' "$param"`; #read absolute path (mount point) of the old home filesystem directory from line 2 of the parameters file
homedir=`sed '3q;d' "$param"`; #read absolute path (mount point) of the actual home filesystem directory from the third line of the parameters file
dat="date +%d.%m.%Y_%H:%M:%S"; #placeholder for the instruction showing the current date (including hour/min/sec). Usage: echo `$dat`
backuplist=$central_backup_dir/backuplist; #backuplist.txt 
olddir=$central_backup_dir/olddir; #olddir.txt
operations_log=$central_backup_dir/operations_log; #operations_log.txt
temp_operations_log=$central_backup_dir/temp_operations_log; #temp_operations_log.txt
restore=$central_backup_dir/restore; #restore.txt
restoretemp=$central_backup_dir/restoretemp; #restoretemp.txt
restore_log=$central_backup_dir/restore_log; #restore_log.txt
restore_errors=$central_backup_dir/restore_errors; #restore_errors.txt
temp=$central_backup_dir/temp; #temp.txt
temp1=$central_backup_dir/temp1; #temp1.txt
files=$1; #first argument of the script is the search keyword (other arguments are ignored) 
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
if [[ -z $files ]]; then #if no search keyword was entered
    clear;
    echo 'No search keyword entered'; 
    echo 'Script aborted'; #error message, end of script
    echo; 
    exit 3;
fi
if [[ ! -d "$homedir" ]]; then #if actual home filesystem does not exist or the mount point is an invalid directory
    clear;
    echo "The home filesystem directory used for restore does not exist or path $homedir is invalid"; 
    echo 'Script aborted'; #error message, end of script
    echo; 
    exit 1;
else
    let "hlength_old=`echo ${#old_homedir}`+1"; #length of the actual home partition path (including the "/" after the directory name, e.g. /home/ -> last /)
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
elif [[ ! -e "$olddir" ]]; then #if file olddir.txt (containing absolute paths of all files that existed in the home partition when the last backup was made) does not exist
    clear;
    echo "File $olddir not found";
    echo 'Script aborted'; #error message, end of program
    echo; 
    exit 1;
else
    fbackupdir=`sed '1q;d' "$backuplist"`; #name of the full backup directory is read from first line of backuplist.txt
    firstchar=${fbackupdir:0:1}; #first character of the full backup directory name
    cd "$central_backup_dir"; #cd to central backup directory
    if [[ ! -d "$fbackupdir" ]] || [[ $firstchar != 'f' ]]; then #if the full backup directory does not exist or name does not begin with small f
	clear;
	echo 'No full backup directory found';
	echo 'Script aborted'; #error message, end of program
	echo; 
	exit 1;
    fi
fi
#
let "col_nr_old=$hlength_old+1"; #variable used for calculating relative paths to the (old) home filesystem directory
restoreok='no'; #this variable is used to determine the user decision regarding items restore (yes - restore; no - reenter search keyword; any other combination - abort script; initial value is 'no' - user must actively approve the operation)
until [[ $restoreok == 'yes' ]]; do #proceed to restore only when acknowledged by admin ("ok"); exit if required 
    grep "$files" "$olddir" | cut -c $col_nr_old- | sort > "$restore"; #search for items to be restored; output (relative pathnames to old home filesystem directory) redirected to restore.txt
    clear;
    > "$temp"; #create empty temp.txt
    while read -r entry; do #get absolute paths of the found items (as visible after restore); write output to temp.txt
	echo $homedir/$entry >> "$temp"; 
    done < "$restore"; 
    echo > "$temp1"; 
    for i in {1,2,3,4,5,6,7,8,9,10,11,12,13}; do
	echo >> "$temp1"; 
    done
    echo 'Following entries were found: ' >> "$temp1";
    echo >> "$temp1"; 
    cat "$temp" >> "$temp1"; 
    more "$temp1"; #list the found items (if any)
    rm "$temp"; #remove temp.txt
    rm "$temp1"; #remove temp1.txt
    echo;
    echo 'Do you wish to restore these items?';
    echo; 
    echo 'Warning! If any of these instances still exists in the home partition, it will be erased prior to restore';
    echo 'Directories will be deleted along with their entire content'; 
    echo; 
    echo 'Enter:'; #prompt user to choose the requested action: 
    echo ' - yes: to proceed with restore'; #restore
    echo ' - no: to change the search keyword'; #reenter search keyword
    echo ' - any other key combination or ENTER: to abort'; #abort script
    echo;
    read restoreok;
    if [[ $restoreok != 'yes' && $restoreok != 'no' ]]; then #if user did not enter "yes" or "no" (case sensitive) 
	clear;
	echo 'Script aborted'; #abort script
	echo; 
	exit 2;
    elif [[ $restoreok == 'no' ]]; then #if user entered "no" 
	files=""; #reset variable
	clear;
	until [[ ! -z $files ]]; do #user must enter a search keyword to continue
	    echo 'Reenter search criteria for the files to be restored: ';
	    echo;
	    read files;
	    if [[ -z $files ]]; then #if nothing was entered 
		clear;
		echo 'No input entered. Please try again'; #user prompted to retry
	    fi
	done
    else  #if user entered "yes"
	if [[ ! -s "$restore" ]]; then #but no items were found
	    clear; 
	    echo 'No items to be restored';
	    echo 'Script aborted'; #error, abort script
	    echo;
	    exit 5;
	fi
    fi 
done
#
> "$restore_log"; #restore_log.txt is created 
> "$restore_errors"; #create restore_errors.txt as empty file or empty it if already existing
#
echo _____Restore_files_keyword:"$files":_`$dat`_____ > "$temp_operations_log"; #add header for current restore to temp_operations_log.txt
echo >> "$temp_operations_log";
clear; 
echo 'Cleaning up home filesystem...';
echo `$dat` '-> cleaning up home filesystem, erasing any instances of items that need to be restored...' >> "$temp_operations_log";  
echo | tee -a "$temp_operations_log"; 
while read -r bentry; do #all instances of items to be restored are erased from home partition prior to restore operation
    if [[ -e "$homedir/$bentry" ]]; then
	rm -r "$homedir/$bentry"; #if instance to be erased is a directory, all content will be removed
    fi
done < "$restore"; 
echo 'DONE' | tee -a "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
echo 'Proceeding to restore...' | tee -a "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
let "all_backup_dirs_restore_total=0"; #total number of items contained in all backup directories, which are instances of the items selected for restore 
let "total_existing_dirs=0"; #total number of times (during the whole restore operation) when a directory had already been restored from a previous backup folder, so it didn't need to be restored from current backup directory
let "total_restored_dirs=0"; #total number of directories that were restored during the whole restore operation 
let "total_restored_files=0"; #total number of files that were restored during the whole restore operation
let "total_failed_restores=0"; #total number of failed restore attempts
let backup_dirs_total=$(lcount "$backuplist"); #total number of backup directories
let "backup_dirs_restored=0"; #current number of backup directories from which the required content was fully restored by script
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
    comm -12 "$restore" "$logpath" | sort > "$restoretemp"; #all files contained in both restore.txt and log.txt are written to restoretemp.txt
    restore_total=$(lcount "$restoretemp"); #total number of items to be restored from the current backup directory 
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
    while read -r bentry; do #read absolute path of current item to be restored from current backup folder
	echo; 
	echo "Current item: $bpath/$bentry";
	echo; 
	echo `$dat` "-> checking $bpath/$bentry" >> "$temp_operations_log";
	if [[ -d "$bentry" ]]; then #if current item is a directory
	    if [[  -d "$homedir/$bentry" ]]; then #if the directory had already been restored to the home partition
		echo "$bentry" >> "$restore_log"; #relative item path to home filesystem logged to restore_log.txt if not already contained
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
		    echo "$bentry" >> "$restore_log"; #relative item path to home filesystem logged to restore_log.txt
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
		echo 'Error! Cannot restore' | tee -a "$temp_operations_log"; #error messsage
	    else #if operation successful  
		echo "$bentry" >> "$restore_log"; #relative item path to home filesystem logged to restore_log.txt
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
	let "remaining=$remaining-1"; #decrement number of items left to restore
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
    done < "$restoretemp";
    let "backup_dirs_restored=$backup_dirs_restored+1"; #increment number of backup directories where required content was fully restored
    let "all_backup_dirs_restore_total=$all_backup_dirs_restore_total+$restore_total"; #update total number of instances of the requested items (from all backup folders)
    if [[ $restore_total == 0 ]]; then #no items to be restored, log to temp_operations_log.txt
	echo 'No items to be restored' >> "$temp_operations_log"; 
    fi
done < "$backuplist"; 
# last screen of the active restore operations (purpose is a final update of the number of backup directories where required content was fully restored) 
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
echo 'Setting up permissions for restored items...'; 
echo >> "$temp_operations_log"; 
echo `$dat` '-> setting up permissions for restored items:' >> "$temp_operations_log";
echo | tee -a "$temp_operations_log"; 
sort "$restore_log" > "$temp"; #sort restore_log.txt
mv "$temp" "$restore_log";
while read -r rentry; do 
    echo "$homedir/$rentry" >> "$temp_operations_log"; #write current item path to temp_operations_log.txt
    if [[ -d "$homedir/$rentry" ]]; then #if restored item is a directory
	chmod 755 "$homedir/$rentry"; #set permission drwxr-xr-x
    else #if item is a file
	chmod 644 "$homedir/$rentry"; #set permission -rw-r--r--
    fi
done < "$restore_log"; 
echo >> "$temp_operations_log"; 
echo 'DONE' | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
clear;
echo `$dat` '-> restore finished' >> "$temp_operations_log"; #active restore operations finished
echo >> "$temp_operations_log"; 
echo 'Summary of restore operations: ' | tee -a "$temp_operations_log";  #summary of the restore operations
echo "-> total number of items to be restored from all backup folders: $all_backup_dirs_restore_total" | tee -a "$temp_operations_log";
echo "-> total number of restored files: $total_restored_files" | tee -a "$temp_operations_log";
echo "-> total number of restored directories: $total_restored_dirs" | tee -a "$temp_operations_log";
echo "-> total number of duplicate directories: $total_existing_dirs" | tee -a "$temp_operations_log";
echo "-> total number of failed restore attempts: $total_failed_restores" | tee -a "$temp_operations_log";
echo "-> content restored from $backup_dirs_restored backup directories" | tee -a "$temp_operations_log"; 
echo | tee -a "$temp_operations_log"; 
comm -23 "$restore" "$restore_log" | sort > "$temp"; #items found in restore.txt (list of items requested for restore) but not in restore_log.txt (list of actually restored items) are written to temp.txt
if [[ -s "$restore_errors" ]] && [[ -s "$temp" ]]; then #if both files are not empty
#output to screen: 
    echo 'Some items could not be restored'; 
    echo 'For details please check: '; 
    echo "-> $operations_log"; 
    echo "-> $restore_errors"; #check restore_errors.txt and operations_log.txt
#log to temp_operations_log.txt:
    echo 'Following items are missing from home filesystem: ' >> "$temp_operations_log"; #not all requested items could be restored
    echo >> "$temp_operations_log"; 
    while read -r path; do 
	echo "$homedir/$path" >> "$temp_operations_log"; #all requested items that failed to be restored to be logged to temp_operations_log.txt
    done < "$temp"; 
    echo >> "$temp_operations_log"; 
    echo 'They could not be restored due to restore errors and probably errors that occurred at previous backup' >> "$temp_operations_log"; 
    echo "For more information please check: $restore_errors" >> "$temp_operations_log"; 
elif [[ -s "$temp" ]]; then #if temp.txt is not empty
#output to screen: 
    echo 'Some items could not be restored due to errors that occurred at previous backup'; 
    echo "For details please check $operations_log"; #check operations_log.txt
#log to temp_operations_log.txt
    echo 'Following items are missing from home filesystem: ' >> "$temp_operations_log"; #not all requested items could be restored
    echo >> "$temp_operations_log"; 
    while read -r path; do 
	echo "$homedir/$path" >> "$temp_operations_log"; #all requested items that failed to be restored to be logged to temp_operations_log.txt
    done < "$temp"; 
    echo >> "$temp_operations_log"; 
    echo 'They could not be restored due to errors that occurred at previous backup' >> "$temp_operations_log"; 
    rm "$restore_errors"; #remove restore_errors.txt
else
    rm "$restore_errors"; #remove restore_errors.txt
    echo 'All items were successfully restored' | tee -a "$temp_operations_log"; #success! 
fi
rm "$temp"; #remove temp.txt
rm "$restore"; #remove restore.txt
rm "$restoretemp"; #remove restoretemp.txt
rm "$restore_log"; #remove restore_log.txt
echo | tee -a "$temp_operations_log"; 
echo `$dat` '-> all operations completed' >> "$temp_operations_log"; #all restore and post-restore operations are finished
mv "$temp_operations_log" "$operations_log"; #temp_operations_log.txt renamed operations_log.txt
exit 0; #end of script
