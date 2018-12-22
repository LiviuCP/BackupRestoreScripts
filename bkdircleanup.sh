#!/bin/bash
# This script will physically remove all files and directories which were marked for deletion from all backup folders
# The directories from a specific backup folder which were marked for deletion will only be removed if all items contained in them are m.f.d. as well
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
dat="date +%d.%m.%Y_%H:%M:%S"; #placeholder for the instruction showing the current date (including hour/min/sec). Usage: echo `$dat`
backuplist=$central_backup_dir/backuplist; #backuplist.txt 
operations_log=$central_backup_dir/operations_log; #operations_log.txt
temp_operations_log=$central_backup_dir/temp_operations_log; #temp_operations_log.txt
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
#
# *** Pre-Cleanup Instructions ***
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
echo _____bkdircleanup_`$dat`_____ > "$temp_operations_log"; #add header for cleanup operation to temp_operations_log.txt
echo >> "$temp_operations_log";
let "total_mfd_items=0"; #total number of instances (files/directories) marked for deletion in all backup directories 
let "total_deleted_dirs=0"; #total number of deleted directories (from all backup folders)
let "total_deleted_files=0"; #total number of deleted files (from all backup folders)
let "total_mfd_dirs=0"; #total number of directories (from all backup folders) that could not be erased as they contained items which were not marked for deletion
let "total_not_found=0"; #total number of items (from all backup folders) that couldn't be found in the backup directories where they were marked for deletion
let backup_dirs_total=$(lcount "$backuplist"); #total number of backup directories
let "backup_dirs_cleaned=0"; #current number of backup directories where erase operations are finished
let "backup_dirs_not_cleaned=0"; #current number of backup directories where no cleanup was needed (no m.f.d. items physically erased)
#
# *** Actual cleanup operation ***
#
echo `$dat` '-> Start of cleanup operation' >> "$temp_operations_log"; #start of cleanup operation is timestamped
while read -r bpath; do #read name of current backup directory
    cd "$central_backup_dir"; #cd to central backup directory
    echo >> "$temp_operations_log"; 
    echo "Current backup directory: $central_backup_dir/$bpath" >> "$temp_operations_log";
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
    mfd=$bpath/mfd; #absolute path of mfd.txt (if a instance of this file is contained in current backup folder)
    deleted=$bpath/deleted; #absolute path of deleted.txt (if a instance of this file needs to be created in current backup folder)
    notfound=$bpath/notfound; #absolute path of notfound.txt (if a instance of this file needs to be created in current backup folder)
    if [[ ! -e "$mfd" ]] || [[ ! -s "$mfd" ]]; then #if mfd.txt does not exist or is empty
	clear;
	echo 'Removing items...'; #screen update... 
	echo; 
	echo "Total backup directories: $backup_dirs_total"; 
	echo "Cleaned up backup directories: $backup_dirs_cleaned"; 
	echo "Backup directories - no cleanup needed: $backup_dirs_not_cleaned";
	echo "Current backup directory: $bpath"; 
	echo; 
	echo;
	echo 'No m.f.d. items contained in this directory' | tee -a "$temp_operations_log"; #...nothing to be deleted from current backup folder
	let "backup_dirs_not_cleaned=$backup_dirs_not_cleaned+1"; #increment number of backup directories where no cleanup was needed 
    else
	> "$temp1"; #empty temp1.txt
	sort -r "$mfd" > "$temp"; #reverse sort mfd.txt, write output to temp.txt
	mfd_items=$(lcount "$mfd"); #total number of items marked for deletion in current backup directory
	let "remaining=$mfd_items"; #mfd items from current backup directory left to be checked (and deleted if applicable)
	let "deleted_dirs=0"; #current number of directories deleted from current backup folder
	let "deleted_files=0"; #current number of files deleted from current backup folder
	let "mfd_dirs=0"; #current number of directories that couldn't be erased from current backup folder as they contain items that are not marked for deletion
	let "not_found=0"; #current number of m.f.d. items that couldn't be found in the current backup directory
	clear;
	echo 'Removing items...'; #cleanup operation for current backup directory - first screen 
	echo; 
	echo "Total backup directories: $backup_dirs_total"; 
	echo "Cleaned up backup directories: $backup_dirs_cleaned"; 
	echo "Backup directories - no cleanup needed: $backup_dirs_not_cleaned";
	echo "Current backup directory: $bpath"; 
	echo 'Current backup directory statistics: '; 
	echo "-> total items marked for deletion: $mfd_items"; 
	echo "-> erased directories: $deleted_dirs"; 
	echo "-> directories that cannot be erased: $mfd_dirs"; 
	echo "-> erased files: $deleted_files"; 
	echo "-> not found: $not_found"; 
	echo "-> items left to check: $remaining"; 
	echo; 
	while read -r bentry; do #read absolute path of current m.f.d item
	    echo;
	    echo "Current m.f.d. item: $bpath/$bentry"; 
	    echo; 
	    echo `$dat` "-> checking $bpath/$bentry" >> "$temp_operations_log";
	    if [[ -d "$bentry" ]]; then #if current item is a directory
		not_empty=`ls -A "$bentry"`; #list all items (if any)
		if [[ -z $not_empty ]]; then #if directory is empty
		    echo "Directory is empty. Deleting..." | tee -a "$temp_operations_log"; 
		    echo; 
		    rmdir "$bentry"; #erase it
		    echo "$bentry" >> "$deleted"; #add entry to deleted.txt
		    let "deleted_dirs=$deleted_dirs+1"; #increment number of erased directories
		    let "total_deleted_dirs=$total_deleted_dirs+1";
		    echo 'DONE' | tee -a "$temp_operations_log";  #confirm operation success
		else 
		    echo "$bentry" >> "$temp1"; #write directory path to temp1.txt
		    let "mfd_dirs=$mfd_dirs+1"; #increment number of directories which remain marked for deletion (but are not deleted) 
		    let "total_mfd_dirs=$total_mfd_dirs+1"; 
		    echo 'Directory not empty, cannot delete' | tee -a "$temp_operations_log"; #directory not empty, cannot remove
		fi
	    elif [[ -e "$bentry" ]]; then #if item is a file
		echo "Item is a file. Deleting..." | tee -a "$temp_operations_log"; 
		echo; 
		rm "$bentry"; #erase it
		echo "$bentry" >> "$deleted"; #write file path to deleted.txt
		let "deleted_files=$deleted_files+1"; #increment number of erased files
		let "total_deleted_files=$total_deleted_files+1";
		echo 'DONE' | tee -a "$temp_operations_log";  #confirm operation success
	    else #if item cannot be found in the current backup directory
		echo "$bentry" >> "$notfound"; #write item path to notfound.txt
		let "not_found=$not_found+1"; #increment number of mfd items not found anymore 
		let "total_not_found=$total_not_found+1";
		echo 'Error! Item not found' | tee -a "$temp_operations_log"; #error message
	    fi
	    let "remaining=$remaining-1"; #decrement number of items left to be checked for deletion
	    clear;
	    echo 'Removing items...'; #cleanup operation for current backup directory - screen update
	    echo; 
	    echo "Total backup directories: $backup_dirs_total"; 
	    echo "Cleaned up backup directories: $backup_dirs_cleaned"; 
	    echo "Backup directories - no cleanup needed: $backup_dirs_not_cleaned";
	    echo "Current backup directory: $bpath"; 
	    echo 'Current backup directory statistics: '; 
	    echo "-> total items marked for deletion: $mfd_items"; 
	    echo "-> erased directories: $deleted_dirs"; 
	    echo "-> directories that cannot be erased: $mfd_dirs"; 
	    echo "-> erased files: $deleted_files"; 
	    echo "-> not found: $not_found"; 
	    echo "-> items left to check: $remaining"; 
	    echo; 
	done < "$temp"; 
	if [[ -s "$temp1" ]]; then #if some mfd directories could not be deleted from current backup folder
	    sort "$temp1" > "$mfd"; #write their paths back to mfd.txt
	    if [[ $deleted_files != 0 ]] || [[ $deleted_dirs != 0 ]]; then #if files/directories were deleted from current backup folder
		let "backup_dirs_cleaned=$backup_dirs_cleaned+1"; #increment number of cleaned up backup directories
	    else
		let "backup_dirs_not_cleaned=$backup_dirs_not_cleaned+1"; #increment number of backup directories where no items were deleted
	    fi
	else
	    rm "$mfd"; #remove mfd.txt
	    let "backup_dirs_cleaned=$backup_dirs_cleaned+1"; #increment number of cleaned up backup directories
	fi
	let "total_mfd_items=$total_mfd_items+$mfd_items"; #update total number of m.f.d. items
    fi
done < "$backuplist";
# last screen of the active cleanup operations (purpose is a final update of the number of cleaned/not cleaned up backup directories)
clear;
echo 'Removing items...';
echo; 
echo "Total backup directories: $backup_dirs_total"; 
echo "Cleaned up backup directories: $backup_dirs_cleaned"; 
echo "Backup directories - no cleanup needed: $backup_dirs_not_cleaned";
echo; 
echo; 
echo 'Cleanup finished!';
# post-cleanup operations, final output
clear;
echo >> "$temp_operations_log"; 
echo `$dat` '-> cleanup finished' >> "$temp_operations_log"; #active cleanup operations finished 
echo >> "$temp_operations_log"; 
echo 'Summary of cleanup operations: ' | tee -a "$temp_operations_log";  #summary of cleanup operations
echo "-> total number of files/directories marked for deletion in all backup folders: $total_mfd_items" | tee -a "$temp_operations_log";
echo "-> total number of deleted files: $total_deleted_files" | tee -a "$temp_operations_log";
echo "-> total number of deleted directories: $total_deleted_dirs" | tee -a "$temp_operations_log";
echo "-> total number of directories that could not be deleted (not empty): $total_mfd_dirs" | tee -a "$temp_operations_log";
echo "-> total number of items that could not be found: $total_not_found" | tee -a "$temp_operations_log";
echo "-> total number of backup directories: $backup_dirs_total" | tee -a "$temp_operations_log"; 
echo "-> cleaned up backup directories: $backup_dirs_cleaned" | tee -a "$temp_operations_log"; 
echo "-> backup directories where no cleanup was needed: $backup_dirs_not_cleaned" | tee -a "$temp_operations_log"; 
echo;
echo 'Cleanup operations finished'; 
echo | tee -a "$temp_operations_log"; 
echo `$dat` '-> all operations completed' >> "$temp_operations_log"; #all cleanup operations are finished
mv "$temp_operations_log" "$operations_log"; #temp_operations_log.txt renamed operations_log.txt
rm "$temp"; #remove temp.txt
rm "$temp1"; #remove temp1.txt
exit 0; #end of script
