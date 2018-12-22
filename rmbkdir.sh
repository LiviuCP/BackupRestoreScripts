#!/bin/bash
# This script will remove all backup folders created before the last full backup
#                  ---prompt for parameters file check ---
param='/root/brcsparam'; #path of the parameters file
clear;
echo "Please check file $param to determine if all parameters are set up correctly"; #prompt user for check
echo 'Enter ok when done or any other key combination (including ENTER) to exit script'; # ok - check is done; any other combination/ENTER - exit script
echo; 
read data_input;
clear;
if [[ $data_input != 'ok' ]]; then #if a string different from 'ok' was entered
    echo 'Script aborted'; #end of script
    echo; 
    exit 2;
fi
#
#                  _____________Local variables________________________________________________
# 
central_backup_dir=`sed '1q;d' "$param"`; #reading the path of the central backup folder from the first line of the parameters file 
old_backuplist=$central_backup_dir/old_backuplist; #old_backuplist.txt 
erase_errors=$central_backup_dir/erase_errors; #erase_errors.txt
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
if [[ ! -d "$central_backup_dir" ]]; then #if central backup folder does not exist
    clear; 
    echo "Central backup directory does not exist or the path $central_backup_dir is invalid";
    echo 'Script aborted'; #error message, end of script
    echo; 
    exit 1;
fi
if [[ ! -e "$old_backuplist" ]]; then #if file old_backuplist.txt (containing the paths of all backup directories created before the last full backup and still not erased) does not exist
    echo 'Maximum one full backup has been performed'; #error message, end of script
    echo 'No backup directories to be erased';
    echo 'Script aborted'; 
    echo; 
    exit 5;
fi
if [[ ! -s "$old_backuplist" ]]; then #if old_backuplist.txt is empty
    echo 'All backup directories created before last full backup have already been removed'; #error message, end of script
    echo 'No backup directories to be erased';
    echo 'Script aborted'; 
    echo; 
    exit 5;
fi
#
> "$erase_errors"; #create erase_errors.txt as empty file or empty it if already existing
#
total_dirs=$(lcount "$old_backuplist"); #total number of directories created before last full backup (to be erased)
let "erased_dirs=0"; #erased directories 
let "errors=0"; #directories that cannot be erased
let "remaining_dirs=$total_dirs"; #directories left to be erased
echo 'Erasing backup directories...'; 
echo; 
echo "Total number of backup directories to be deleted: $total_dirs"; #erase operation - first screen
echo "Erased backup directories: $erased_dirs";
echo "Backup directories that could not be erased: $errors"; 
echo "Directories left to erase: $remaining_dirs"; 
echo; 
while read -r path; do #read name of current backup directory to be erased
    path=$central_backup_dir/$path; #get absolute path
    echo "Current backup directory to be removed: $path";
    echo; 
    if [[ -d "$path" ]]; then #check if the directory exists. If yes: 
	echo 'Removing directory...'; 
	rm -r "$path"; #remove directory
	echo 'DONE'; #erase confirmation
	let "erased_dirs=$erased_dirs+1"; #increment number of erased directories
    else
	echo "Backup directory $path does not exist"; #error message
	echo $path >> "$erase_errors"; #add backup directory path to erase_errors.txt
	let "errors=$errors+1"; #increment erase errors 
    fi
    let "remaining_dirs=$remaining_dirs-1"; #decrement number of directories left to be erased
    clear;
    echo 'Erasing backup directories...'; 
    echo; 
    echo "Total number of backup directories to be deleted: $total_dirs"; #screen update
    echo "Erased backup directories: $erased_dirs";
    echo "Backup directories that could not be erased: $errors";
    echo "Directories left to erase: $remaining_dirs";
    echo; 
done < "$old_backuplist"; 
#
clear;
if [[ -s "$erase_errors" ]]; then #if errors occurred
    echo "Some backup directories could not be deleted. For details see $erase_errors"; #not all backup directories created before last full backup could be deleted
else
    rm "$erase_errors"; #remove erase_errors.txt 
    echo 'All backup directories created before last full backup were successfully deleted'; #removal success confirmation
fi
echo; 
> "$old_backuplist"; #empty old_backuplist.txt
echo "Content removed from $old_backuplist"; #and confirm once done
echo; 
echo 'End of script';
echo;
exit 0; #script ended
