#!/bin/bash

# Programs needed:
#   realpath
#   dirname
#   basename
#   stat

# Errors code:
# 1 - Invalid option
# 2 - Invalid command
# 3 - File don't exist
# 4 - No file passed

home_dir=$(echo ~)
saver_directory="$home_dir/linux-home"
control_file="$saver_directory/.control_file"

function printHelpMessage {
    echo "Usage: $0 COMMAND files_path"
    echo "Commands:"
    echo -e "\tadd: Adds the files_path into the track of backup directory"
    echo -e "\tupdate: Updates the files_path that are inside backup directory"
    echo -e "\tdelete: Deletes the files_path that are inside backup directory"
    echo -e "\tlist: Lists all files inside the backup directory"
    echo -e "\ttrack: Checks if the files_path are tracked"
}

function get_script_location {
    #Get the location of the script
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        echo $DIR
}

source "$(get_script_location)/home-saver-functions.sh"

sub_command=$1

need_add="no"
need_update="no"
need_delete="no"
while getopts ":h" opt; do
    case $opt in
        h)
            printHelpMessage
            exit 0
            ;;

        \?)
            echo -e "Error: Invalid option" >&2
            printHelpMessage
            exit 1
            ;;
        :)
            echo -e "Error: -$OPTARG requires an argument" >&2
            printHelpMessage
            exit 1
            ;;
    esac
done

# Check if the arguments are valids
invalid_arguments $@
ret=$?
if [[ $ret -ne 0 ]]; then
    exit $ret
fi

# Creates a temporary directory
tmp_directory=/tmp/home-saver_$PPID/
mkdir -p $tmp_directory

if [[ $sub_command == "add" ]]; then

    for file_path in "${@:2}"; do
        add_file "$file_path"
    done

elif [[ $sub_command == "update" ]]; then

    for file_path in "${@:2}"; do
        update_file "$file_path"
    done

elif [[ $sub_command == "delete" ]]; then

    for file_path in "${@:2}"; do
        delete_file "$file_path"
    done

elif [[ $sub_command == "track" ]]; then

    for file_path in "${@:2}"; do
        ret=$(file_tracked "$file_path")
        if [[ $ret -eq 1 ]]; then
            echo "File "$file_path" tracked"
        else
            echo "File "$file_path" untracked"
        fi
    done

elif [[ $sub_command == "list" ]]; then
    list_tracked_files

elif [[ $sub_command == "status" ]]; then
    
    tmp_file="$tmp_directory/status-exit"
    for file_path in $(list_tracked_files); do
        f_status=$(file_status $file_path)
        echo "$file_path $f_status" >> "$tmp_file"
    done

    column -t "$tmp_file"

else
    echo "Invalid command" >&2
    printHelpMessage
    rm -r $tmp_directory
    exit 2
fi

rm -r $tmp_directory
exit 0
