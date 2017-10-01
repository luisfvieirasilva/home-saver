#!/bin/bash

# Add a new file
function add_file {

    local file_path="$1"
    local home_dir=$(echo ~)

    local relative_file_path="$(realpath --relative-to="$home_dir" "$file_path")"
    local relative_file_dir="$(dirname "$relative_file_path")"
    local relative_file_name="$(basename "$relative_file_path")"

    file_tracked "$file_path" > /dev/null
    local ret=$?
    if [[ $ret == "1" ]]; then
        echo "File already tracked: $file_path"
        return
    fi

    echo "Adding file $file_path"

    # Create directory
    mkdir -p "$saver_directory/$relative_file_dir"
    # Copy the file
    cp "$file_path" "$saver_directory/$relative_file_path"

    # Save the modification inside control file
    echo "file_path:$relative_file_path" >> "$control_file"

}

# Check if a file already is being tracked
# Return 0 if the file isn't track
# return 1 otherwise
function file_tracked {

    local file_path="$1"
    local home_dir=$(echo ~)
    local relative_file_path
    relative_file_path="$(realpath --relative-to="$home_dir" "$file_path")"
    local regex_form=$(echo "$relative_file_path" | sed 's/\//\\\//g')
    regex_form=$(echo "$regex_form" | sed 's/\./\\./g')
    regex_form=$(echo "$regex_form" | sed 's/\[/\\[/g')
    regex_form=$(echo "$regex_form" | sed 's/\]/\\]/g')
    regex_form=$(echo "$regex_form" | sed 's/\-/\\-/g')
    grep_result=$(grep "^file_path:$regex_form" "$control_file" | wc -l)

    # If the file is't track
    if [[ $grep_result -eq 0 ]]; then
        echo "0"
        return 0
    else
        echo "1"
        return 1
    fi

}

# Update a tracked file
function update_file {

    local file_path="$1"
    local home_dir=$(echo ~)

    file_tracked "$file_path" > /dev/null
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        echo "File isn't track: $file_path."
        return
    fi

    local relative_file_path="$(realpath --relative-to="$home_dir" "$file_path")"

    diff "$file_path" "$saver_directory/$relative_file_path" > /dev/null
    local diff_res=$?

    # If needs to update
    if [[ $diff_res -eq 1 ]]; then

        echo "Updating $file_path"

        # Copy the file
        cp "$file_path" "$saver_directory/$relative_file_path"

    else

        echo "File already updated: $file_path"

    fi

}

function delete_file {

    echo "$@"
    local file_path="$1"
    local home_dir=$(echo ~)

    local relative_file_path="$(realpath --relative-to="$home_dir" "$file_path")"
    local relative_file_dir="$(dirname "$relative_file_path")"
    local file_name="$(basename "$relative_file_path")"
    local regex_form=$(echo "$relative_file_path" | sed 's/\//\\\//g')
    regex_form=$(echo "$regex_form" | sed 's/\./\\./g')
    regex_form=$(echo "$regex_form" | sed 's/\[/\\[/g')
    regex_form=$(echo "$regex_form" | sed 's/\]/\\]/g')
    regex_form=$(echo "$regex_form" | sed 's/\-/\\-/g')

    file_tracked "$file_path" > /dev/null
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        echo "File isn't track: $file_path"
        return
    fi

    echo "Untracking file $file_path"

    initial_diretory=$(pwd)
    cd "$saver_directory/$relative_file_dir"

    # Remove file
    rm "$file_name"
    # Remove file from control_file
    sed "/^file_path:$regex_form/ d" "$control_file" > .linux-tmp
    mv .linux-tmp "$control_file"

    # If already at saver_directory root, just return
    if [[ "$(pwd)" == "$saver_directory" ]]; then
        cd "$initial_diretory"
        return
    fi

    # Delete all unnecessary directories
    number_of_files=$(ls | wc -l)
    while [[ "$(pwd)" != "$saver_directory" ]] && [[ "$number_of_files" -eq 0 ]]; do
        directory_name="$(basename "$(pwd)")"
        cd ..
        number_of_files=$(ls | grep -v $directory_name | wc -l)
    done
    
    # Confirm directory deletion
    if [[ ! -z $directory_name ]]; then

        directory_name="$(realpath "$directory_name")"
        read -r -p "Confirm deletion of $directory_name directory [y/N]" response
        case $response in
            [yY][eE][sS]|[yY])
                rm -r $directory_name
                echo "Directory $directory_name deleted"
                ;;
            *)
                echo "Deletion canceled"
                ;;
        esac

    fi

    # Goes back to original directory
    cd $initial_diretory
    
}

# List all tracked files
function list_tracked_files {

    grep "file_path" "$control_file" | cut -d ":" -f 2- | sort

}

# Get all files passed
function all_files {

    for i in $(seq 1 $#); do
        eval file_path=\$$i
        echo $file_path
    done

}

function check_if_exists {

    files_paths=${@}
    for file_path in $files_paths; do
        # If the file doesn't exist
        if [[ ! -e "$file_path" ]]; then
            echo "Error: File $file_path doesn't exist" >&2
            return 0
        fi
    done

    return 1

}

function invalid_arguments {

    sub_command=$1
    local need_check_files="no"
    if [[ "$sub_command" != "list" ]]; then
        need_check_files="yes"
    fi

    if [[ $need_check_files == "yes" ]]; then
        if [[ $# -le 1 ]]; then
            echo "Error: At least one file needed" >&2
            return 4
        fi
        files_paths=${@:2}
        check_if_exists $files_paths
        ret=$?
        if [[ $ret -eq 0 ]]; then
            return 3
        fi
    fi 

    return 0

}

