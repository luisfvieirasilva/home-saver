#!/bin/bash

# Programs needed:
#   realpath
#   dirname
#   basename
#   stat

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
    echo "Options:"
    echo -e "\t-XXX: "
}

source "home-saver-functions.sh"

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
            echo -e "${Red}Invalid option.${NC}" >&2
            printHelpMessage
            exit 1
            ;;
        :)
            echo -e "${Red}-$OPTARG requires an argument.${NC}" >&2
            printHelpMessage
            exit 1
            ;;
    esac
done

home_dir=$(echo ~)

if [[ $sub_command == "add" ]]; then
    for file_path in $(all_files $@); do
        add_file "$file_path"
    done

elif [[ $sub_command == "update" ]]; then
    for file_path in $(all_files $@); do
        update_file "$file_path"
    done

elif [[ $sub_command == "delete" ]]; then
    for file_path in $(all_files $@); do
        delete_file "$file_path"
    done

elif [[ $sub_command == "track" ]]; then
    for file_path in $(all_files $@); do
        ret=$(file_tracked "$file_path")
        if [[ $ret -eq 1 ]]; then
            echo "File "$file_path" tracked"
        else
            echo "File "$file_path" untracked"
        fi
    done

elif [[ $sub_command == "list" ]]; then
    list_files

else
    echo "Invalid command"
    printHelpMessage
    exit 2
fi
