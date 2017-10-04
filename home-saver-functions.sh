#!/bin/bash

# Add a new file
function add_file {

    local file_path="$1"
    local home_dir=$(echo ~)

    local relative_file_path="$(realpath --relative-to="$home_dir" \
        "$file_path")"
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

    local relative_file_path="$(realpath --relative-to="$home_dir" \
        "$file_path")"

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

# Update all tracked files
function update_all {

    local file_path="$1"
    local home_dir=$(echo ~)

    for file_path in $(list_tracked_files); do
        # Check file status
        f_status=$(file_status $file_path)

        if [[ "$f_status" == "modified" ]]; then
            update_file "$file_path"
        fi
    done

}

function delete_file {

    local file_path="$1"
    local home_dir=$(echo ~)

    local relative_file_path="$(realpath --relative-to="$home_dir" \
        "$file_path")"
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
    while [[ "$(pwd)" != "$saver_directory" ]] && \
        [[ "$number_of_files" -eq 0 ]]; do
        directory_name="$(basename "$(pwd)")"
        cd ..
        number_of_files=$(ls | grep -v $directory_name | wc -l)
    done
    
    # Confirm directory deletion
    if [[ ! -z $directory_name ]]; then

        directory_name="$(realpath "$directory_name")"
        read -r -p "Confirm deletion of $directory_name directory [Y/n]" \
            response
        case $response in
            [nN][oO]|[nN])
                echo "Deletion canceled"
                ;;
            *)
                rm -r $directory_name
                echo "Directory $directory_name deleted"
                ;;
        esac

    fi

    # Goes back to original directory
    cd $initial_diretory
    
}

# Delete from track directories all files that don't exist any more
function delete_deleted {

    local file_path="$1"
    local home_dir=$(echo ~)

    for file_path in $(list_tracked_files); do
        # Check file status
        f_status=$(file_status $file_path)

        if [[ "$f_status" == "doesn't_exist" ]]; then
            read -r -p "Confirm deletion of $file_path file [Y/n]" \
                response
            case $response in
                [nN][oO]|[nN])
                    echo "Deletion canceled"
                    ;;
                *)
                    delete_file "$file_path"
                    ;;
            esac
        fi
    done

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

# Check the status of a file
function file_status {

    local file_path="$1"
    local home_dir=$(echo ~)
    local relative_file_path="$(realpath --relative-to="$home_dir" \
        "$file_path")"

    file_tracked "$file_path" > /dev/null
    local ret=$?
    if [[ $ret -eq 0 ]]; then
        echo "doesn't_track"
        return
    fi

    if [[ ! -e "$file_path" ]]; then
        echo "doesn't_exist"
        return
    fi

    diff "$file_path" "$saver_directory/$relative_file_path" > /dev/null
    ret=$?
    if [[ $ret -eq 1 ]]; then
        echo "modified"
    else
        echo "updated"
    fi
    return

}

# List all tracked files
function list_tracked_files {

    local home_dir=$(echo ~)
    for file in $(grep "file_path" "$control_file" | cut -d ":" -f 2- | sort); do
        echo "$home_dir/$file"
    done

}

# Check if the arguments are valid files
function invalid_arguments {

    if [[ $# -eq 0 ]]; then
        echo "Error: At least one file needed" >&2
        return 4
    fi

    for file_path in $@; do

        # If the file doesn't exist
        if [[ ! -e "$file_path" ]]; then
            echo "Error: File $file_path doesn't exist" >&2
            return 3
        fi

    done

    return 0

}
