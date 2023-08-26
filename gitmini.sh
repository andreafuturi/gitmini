#!/bin/sh

# COLORS FOR OUTPUT
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

APPLICATION_NAME="GitMini"

# Function: get_master_name
#
# Retrieve the name of the default branch (e.g., master, main, or default) in the Git repository.
# If no default branch is found, create a new "master" branch.
#
# Usage: get_master_name

get_master_name() {
    if git remote show origin >/dev/null 2>&1; then
        default_branch="$(git remote show origin | awk '/HEAD branch/ {print $NF}')"
        echo "$default_branch"
    else
        # Check if local master branch exists
        if git show-ref --quiet --verify refs/heads/master; then
            echo "master"
            return
        fi

        # Check if local main branch exists
        if git show-ref --quiet --verify refs/heads/main; then
            echo "main"
            return
        fi

        # Check if local default branch exists (Git versions >= 2.28)
        if git show-ref --quiet --verify refs/heads/default; then
            echo "default"
            return
        fi
        git checkout -b master >/dev/null 2>&1
        echo "master"
    fi
}

#save master name as global var
master_name="$(get_master_name)"

# Function: publish
#
# Publish the changes made in the current or specified ticket branch.
# If no ticket is specified, use the current ticket in progress.
# If the specified ticket is different from the current ticket, start the specified ticket.
#
# Usage: publish [ticket_name]

publish() {
    current_ticket="${1:-$(get_current_ticket)}"
    ticket="$(echo "$1" | tr ' ' '-')"
    # Get ticket name if provided; otherwise, use the current ticket
    if [ -n "$1" ]; then
        # If the current ticket is not the same as the one provided, start the provided ticket
        #if provided ticket doesn't correspond to existing branch name didn't exist print Creating one...
        if ! git show-ref --quiet --verify refs/heads/"$ticket"; then
            start_eco
            printf "${BLUE}%s${NC} | Creating ticket on the fly...\n" "$APPLICATION_NAME"
            end_eco
        fi
        if [ "$ticket" != "$current_ticket" ]; then
            start_eco
            printf "${BLUE}%s${NC} | Pausing %s and resuming %s work...\n" "$APPLICATION_NAME" "$current_ticket" "$ticket"
            end_eco
        fi
        start "$ticket"
    else
        if [ -z "$current_ticket" ]; then
            # Start a ticket if none is started and no ticket name is provided
            start_eco
            printf "${BLUE}%s${NC} | Creating ticket on the fly...\n" "$APPLICATION_NAME"
            end_eco
            start "$ticket"
        fi
        ticket="$(get_current_ticket)"
    fi
    update "${ticket} published on ${master_name}" >/dev/null 2>&1
    start_eco
    printf "${BLUE}%s${NC} | ${GREEN}Work on \"%s\" published successfully.${NC}\n" "$APPLICATION_NAME" "$ticket"
    end_eco
}

# Function: unpublish
#
# Revert the changes made in the specified ticket and unpublish it.
# If no ticket is specified, unpublish the current ticket.
#
# Usage: unpublish [ticket_name]

unpublish() {
    # Safely update your local repository
    refresh

    current_ticket="$(get_current_ticket)"
    if [ -z "$1" ] && [ -z "$current_ticket" ]; then
        ticket="$(git log -1 --pretty=%B)"
    else
        ticket="${1:-$current_ticket}"
    fi

    git checkout "$master_name" >/dev/null

    # Find the commit with the matching ticket name
    commit_hash="$(git log --grep="$ticket" --pretty=format:%H -n 1)"

    if [ -z "$commit_hash" ]; then
        start_eco
        printf "${BLUE}%s${NC} | ${RED}No ticket created with the name \"%s\".${NC}" "$APPLICATION_NAME" "$ticket"
        end_eco
        exit 1
    fi

    # Revert the commit
    git revert --no-commit "$commit_hash" >/dev/null 2>&1

    # Check for conflicts after reverting
    check_conflicts
    git add -A >/dev/null 2>&1

    # Create a revert commit with the ticket name
    git commit -m "revert of $ticket" && git push >/dev/null 2>&1
    start_eco
    printf "${BLUE}%s${NC} | ${GREEN}Unpublishing of \"%s\" completed successfully.${NC}\n" "$APPLICATION_NAME" "$ticket"
    end_eco
}

# Function: start
#
# Start working on a new ticket by creating a new branch with the specified name.
# If no name is provided, a default ticket name is generated.
#
# Usage: start [ticket_name]

start() {
    init_userinfo
    if [ ! -d .git ]; then
        start_eco
        printf "${BLUE}%s${NC} | Repository not found. Initializing a new one...\n" "$APPLICATION_NAME"
        end_eco
        git init >/dev/null 2>&1
        #make first repo commit
        #create readme
        echo "#Created with $APPLICATION_NAME" >>README.md
        git add -A >/dev/null 2>&1
        git commit -m "first commit" >/dev/null 2>&1
        master_name="$(get_master_name)" #update master name
    fi

    ticket="${1:-WIP-$(date +%d-%m-%Y-%H-%M-%S)}"
    # Replace spaces with dashes in the ticket name
    ticket="$(echo "$ticket" | sed 's/ /-/g')"
    existing_current_ticket="$(get_current_ticket)"
    # if another ticket is in progress, pause it
    if [ "$ticket" = "$existing_current_ticket" ]; then
        start_eco
        printf "${BLUE}%s${NC} | ${ORANGE}Work on \"%s\" %s already started.${NC}\n" "$APPLICATION_NAME" "$ticket" "$message_verb"
        end_eco
    else
        if [ -n "$existing_current_ticket" ] && [ "$ticket" != "$existing_current_ticket" ]; then
            pause "$existing_current_ticket"
        fi
        # create a new branch for the ticket
        if git show-ref --quiet --verify refs/heads/"$ticket"; then
            git checkout "$ticket" >/dev/null 2>&1
            message_verb="resumed"
        else
            git checkout -b "$ticket" >/dev/null 2>&1
            message_verb="started"
        fi
        # update codebase
        start_eco
        printf "${BLUE}%s${NC} | ${GREEN}Work on \"%s\" %s successfully.${NC}\n" "$APPLICATION_NAME" "$ticket" "$message_verb"
        end_eco
        # update codebase /may be better to be before creating the branch?
    fi
    refresh
}

# Function: pause
#
# Pause the work on the current ticket by commiting the changes and switching to the master branch.
# If no ticket is currently in progress, display an error message.
#
# Usage: pause [ticket_name]

pause() {
    current_ticket="${1:-$(get_current_ticket)}"
    if [ -z "$current_ticket" ]; then
        start_eco
        printf "${BLUE}%s${NC} | ${RED}You didn't start any ticket.${NC}\n" "$APPLICATION_NAME"
        end_eco
        exit 1
    fi
    git add -A >/dev/null 2>&1
    git commit -m "$current_ticket paused" >/dev/null 2>&1

    # Switch to the master branch
    git checkout "$master_name" >/dev/null 2>&1
    start_eco
    printf "${BLUE}%s${NC} | ${GREEN}Work on \"%s\" paused successfully.${NC}\n" "$APPLICATION_NAME" "$current_ticket"
    end_eco
}

# Function: update
#
# Update the current ticket branch with the changes made in the working directory.
# The updated changes are then merged with the master branch.
# Useful to give sneak previews to team members of a WIP.
#
# Usage: update "update message"

update() {
    refresh
    current_ticket="$(get_current_ticket)"
    start_eco
    printf "${BLUE}%s${NC} | Uploading your changes...\n" "$APPLICATION_NAME"
    end_eco
    git add -A >/dev/null 2>&1
    git commit -m "${1:-$current_ticket-WIP}" >/dev/null 2>&1
    git push --set-upstream origin >/dev/null 2>&1

    # Switch to the master branch and merge changes from the ticket branch with a single commit
    git checkout "$master_name" >/dev/null 2>&1
    git merge "$ticket" --squash --no-commit >/dev/null 2>&1
    check_conflicts
    git add -A >/dev/null
    git commit -m "${1:-$current_ticket-WIP}" >/dev/null 2>&1
    # Push changes to the master branch
    git push >/dev/null 2>&1

    # Check if the commit is present on the current branch
    commit_present_on_master=$(git log "$master_name" --oneline | grep -c "${1:-$current_ticket-WIP}")

    if [ "$commit_present_on_master" -eq 0 ]; then
        start_eco
        printf "${RED}%s$ | Error: Could not publish \"%s\". Please try again {NC}\n" "$APPLICATION_NAME" "$current_ticket"
        end_eco
        return 1
    fi

    start_eco
    printf "${BLUE}%s${NC} | ${GREEN}Project updated with \"%s\" successfully.${NC}\n" "$APPLICATION_NAME" "$ticket"
    end_eco
}
# Function: refresh
#
# Refresh the local repository by pulling changes from the current ticket branch and the master branch.
# The changes from the master branch are merged into the current ticket branch.
#
# Usage: refresh [interval_in_seconds]
refresh() {
    start_eco
    # Get the current ticket name
    current_ticket="$(get_current_ticket)"

    # Function to perform a single refresh
    perform_refresh() {
        # Check if there are any changes in the working tree
        if [ "$(git status --porcelain)" ]; then
            # Commit changes before pulling
            git add -A >/dev/null 2>&1
            git commit -m "${current_ticket:-temp-WIP-$(date +%s)}" >/dev/null 2>&1
            git push --set-upstream origin "$current_ticket" >/dev/null 2>&1
        fi

        # Pull updates from origin of the current ticket
        git pull >/dev/null 2>&1

        # Get the commit hash of your current branch's latest commit
        current_branch_commit="$(git rev-parse HEAD)"

        # Get the commit hash of the latest commit on the master branch
        master_commit="$(git rev-parse "$master_name")"

        if [ "$current_branch_commit" != "$master_commit" ]; then
            # Perform the merge only if it's needed
            start_eco
            printf "${BLUE}%s${NC} | Downloading team changes...\n" "$APPLICATION_NAME"
            end_eco
            # Merge changes from master into the current ticket branch
            git merge "$master_name" --no-commit >/dev/null 2>&1
            check_conflicts
            git add -A >/dev/null 2>&1
            git commit -m "$current_ticket update with other tickets" >/dev/null 2>&1
        fi

        start_eco
        printf "${BLUE}%s${NC} | Refreshing code...\n" "$APPLICATION_NAME"
        end_eco
    }

    if [ -z "$1" ]; then
        # If no parameter is provided, perform a single refresh
        perform_refresh
    else
        # If an interval is provided, run in a loop
        interval="$1"
        while true; do
            perform_refresh
            sleep "$interval"
        done
    fi
}

# Function: combine
#
# Combine multiple ticket branches into one branch.
# The changes from each ticket branch will be merged into the combined branch.
#
# Usage: combine [ticket_name_1] [ticket_name_2] ... [ticket_name_n]

#work in progress (not tested)

combine() {
    # Ensure that at least two ticket names are provided
    #default first ticket name should be the current one if only one ticket name is provided
    #otherwise combine the given tickets name normally
    if [ "$#" -lt 2 ]; then
        start_eco
        printf "${BLUE}%s${NC} | ${RED}Please provide at least two ticket names to combine.${NC}\n" "$APPLICATION_NAME"
        end_eco
        exit 1
    fi

    # Prompt the user for the new ticket name
    printf "Enter the name for the combined ticket: "
    read -r combined_branch
    combined_branch="$(echo "$combined_branch" | sed 's/ /-/g')"

    # Create the combined branch
    #pause current ticket if present
    pause
    git checkout -b "$combined_branch" >/dev/null 2>&1

    # Merge each ticket branch into the combined branch
    for ticket_name in "$@"; do
        if git show-ref --quiet --verify refs/heads/"$ticket_name"; then
            git merge "$ticket_name" --no-commit >/dev/null 2>&1
            check_conflicts
            git add -A >/dev/null 2>&1
            git commit -m "Merging $ticket_name into $combined_branch" >/dev/null 2>&1
        else
            start_eco
            printf "${BLUE}%s${NC} | ${RED}\"%s\" does not exist.${NC}\n" "$APPLICATION_NAME" "$ticket_name"
            end_eco
        fi
    done

    start_eco
    printf "${BLUE}%s${NC} | ${GREEN}Tickets merged into \"%s\" successfully.${NC}\n" "$APPLICATION_NAME" "$combined_branch"
    end_eco
}

# Function: delete
#
# Delete the specified ticket branches.
# Checks if the branches exist and are not the current branch before deleting.
#
# Usage: delete [ticket_name1] [ticket_name2] ... [ticket_name_n]

delete() {
    #in future we will have to check if ticket has been published before deleting otherwise ask confirmation (maybe unless an option is provided --force)
    for ticket in "$@"; do
        # Check if the ticket exists
        if git show-ref --quiet --verify refs/heads/"$ticket"; then
            # If the ticket is in progress, pause it before deleting
            if [ "$(get_current_ticket)" = "$ticket" ]; then
                pause "$ticket"
            fi
            git branch -D "$ticket" >/dev/null 2>&1
            start_eco
            printf "${BLUE}%s${NC} | ${GREEN}Ticket \"%s\" deleted successfully.${NC}\n" "$APPLICATION_NAME" "$ticket"
            end_eco
        else
            start_eco
            printf "${BLUE}%s${NC} | ${RED}\"%s\" does not exist.${NC}\n" "$APPLICATION_NAME" "$ticket"
            end_eco
        fi
    done
}

# Function: get_current_ticket
#
# Retrieve the name of the current ticket branch.
# If the current branch is the master branch, no ticket is in progress.
#
# Usage: get_current_ticket

get_current_ticket() {
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$branch" != "$master_name" ]; then
        echo "$branch"
    fi
}

# Function: current
#
# Display the name of the current ticket being worked on, if any.
#
# Usage: current

current() {
    current_ticket="$(get_current_ticket)"
    if [ -n "$current_ticket" ]; then
        start_eco
        printf "${BLUE}%s${NC} | You are currently working on ticket: ${BLUE}%s${NC}\n" "$APPLICATION_NAME" "$current_ticket"
        end_eco
    else
        start_eco
        printf "${BLUE}%s${NC} | You didn't start any ticket.\n" "$APPLICATION_NAME"
        printf "${BLUE}%s${NC} | Start a new one with git start <ticket_name> or run directly git publish <ticket_name>\n" "$APPLICATION_NAME"
        end_eco
    fi
}

# Function: check_conflicts
#
# Check if there are any merge conflicts in the current ticket branch.
# If conflicts are found, display the conflicting files and prompt the user to fix them.
#
# Usage: check_conflicts

# shellcheck disable=SC2120
check_conflicts() {
    # conflict_files="$(git grep -l -Ee '<<<<<<<.*(\|\||====|>>>>>>>)')"
    conflict_files="$(git diff --name-only --diff-filter=U)"
    if [ -n "$conflict_files" ]; then
        #if $1 is testing then don't show conflicts echo "conflicts found" else show conflicts
        if [ "$1" = "testing" ]; then
            echo "conflicts found"
        else
            show_conflicts
        fi
    fi
}

show_conflicts() {
    conflict_files="$(git diff --check)"
    start_eco
    printf "${BLUE}%s${NC} | ${ORANGE}Please fix conflicts in the following files:${NC}\n" "$APPLICATION_NAME"
    end_eco
    start_eco
    echo "$conflict_files"
    end_eco
    start_eco
    printf "After testing everything again, press Enter to continue..."
    read -r __
    end_eco
    # Check for conflicts again after testing
    #checks conflicts with more strategies
    conflict_files="$(git diff --check)"

    if [ -n "$conflict_files" ]; then
        start_eco
        printf "${BLUE}%s${NC} | ${RED}There are still conflicts! Please remember to save files try again.${NC}\n" "$APPLICATION_NAME"
        end_eco
        check_conflicts
    else
        start_eco
        printf "${BLUE}%s${NC} | ${GREEN}Conflicts resolved successfully.${NC}\n" "$APPLICATION_NAME"
        end_eco
        git add -A >/dev/null 2>&1
        git rebase --continue >/dev/null 2>&1
    fi
}

# Function: git_list
#
# List all available ticket branches in the repository.
# Excludes the master branch from the list.
#
# Usage: git list

list() {
    ticket_branches="$(git branch --list | grep -v "$master_name")"
    if [ -z "$ticket_branches" ]; then
        start_eco
        printf "${BLUE}%s${NC} | No tickets found. Create one with git start <ticket_name>\n" "$APPLICATION_NAME"
        end_eco
    else
        start_eco
        printf "${BLUE}%s${NC} | Available ticket branches:\n" "$APPLICATION_NAME"
        end_eco
        start_eco
        echo "$ticket_branches" | sed 's/^/  - /' # Add a prefix "-" to each branch name
        end_eco
    fi
}

# Function: rename
#
# Rename a ticket (branch and commits).
# If only one argument is provided, assume it's the new ticket name and use the current ticket as the old ticket name.
#
# Usage: git rename [current_ticket_name] new_ticket_name

rename() {
    current_ticket="$1"
    new_ticket="$2"

    # If only one argument is provided, assume it's the new ticket name and get the current ticket name
    if [ "$#" -eq 1 ]; then
        current_ticket="$(get_current_ticket)"
        new_ticket="$1"
    fi

    # Check if the current ticket branch exists
    if ! git show-ref --quiet --verify refs/heads/"$current_ticket"; then
        start_eco
        printf "${BLUE}%s${NC} | ${RED}Ticket \"%s\" does not exist.${NC}\n" "$APPLICATION_NAME" "$current_ticket"
        end_eco
        exit 1
    fi
    git branch -m "$current_ticket" "$new_ticket" >/dev/null 2>&1
    git checkout "$master_name" >/dev/null 2>&1
    git checkout "$new_ticket" >/dev/null 2>&1

    #Rename all commits with the new ticket name
    git filter-branch -f \
        --env-filter "GIT_COMMITTER_NAME='$(git config user.name)'; GIT_COMMITTER_EMAIL='$(git config user.email)'; GIT_AUTHOR_NAME='$(git config user.name)'; GIT_AUTHOR_EMAIL='$(git config user.email)';" \
        --msg-filter 'sed "s/'"$current_ticket"'/'"$new_ticket"'/g"' \
        HEAD >/dev/null 2>&1

    # Push the new branch to the remote repository
    git push origin --delete old-branch-name >/dev/null 2>&1
    git push --set-upstream origin "$new_ticket" >/dev/null 2>&1

    start_eco
    printf "${BLUE}%s${NC} | ${GREEN}Ticket \"%s\" renamed to \"%s\" successfully.${NC}\n" "$APPLICATION_NAME" "$current_ticket" "$new_ticket"
    end_eco
}

# Function init_userinfo
#
# Initialize the local git username and email if not set.
#
# Usage: init_userinfo

init_userinfo() {
    # Check if local git username is not set
    if [ -z "$(git config user.name)" ]; then
        # Check if global git username is set
        if [ -n "$(git config --global user.name)" ]; then
            # Use global git username
            git config user.name "$(git config --global user.name)"
        else
            # Prompt the user to enter their name
            printf "Enter your name: "
            read -r name
            # Set the local git username
            git config user.name "$name"
        fi
    fi

    # Check if local git email is not set
    if [ -z "$(git config user.email)" ]; then
        # Check if global git email is set
        if [ -n "$(git config --global user.email)" ]; then
            # Use global git email
            git config user.email "$(git config --global user.email)"
        else
            # Prompt the user to enter their email
            printf "Enter your email: "
            read -r email
            # Set the local git email
            git config user.email "$email"
        fi
    fi
}

#Text formatting functions
start_eco() {
    printf "========================================\n\n"
}
end_eco() {
    printf "\n========================================\n"
}

# Function: help
#
# Display the help message.
#
# Usage: help

help() {
    start_eco

    help_message=$(
        cat <<EOF
${BLUE}$APPLICATION_NAME${NC} | Usage: git <command> [ticket_name]
${BLUE}$APPLICATION_NAME${NC} | Commands:
 - ${BLUE}start${NC}: Start or resume work on a ticket and refresh codebase.
 - ${BLUE}publish${NC}: Publish the changes made in the current or specified ticket.
 - ${BLUE}unpublish${NC}: Revert the changes made in the current or specified ticket.

 - ${BLUE}rename${NC}: Rename a ticket (branch and commits).
 - ${BLUE}combine${NC}: Combine multiple ticket branches into one branch.

 - ${BLUE}list${NC}: List all tickets opened until now.
 - ${BLUE}current${NC}: Display the name of the current ticket being worked on.
 - ${BLUE}pause${NC}: Pause the work on the current ticket by commiting the changes and switching to the master branch.

 - ${BLUE}refresh${NC}: Refresh the local repository by downloading changes from the current ticket branch and the master branch.
 - ${BLUE}update${NC}: Update team members with your work even if not finished.
 - ${BLUE}delete${NC}: Delete the specified ticket.
EOF
    )
    echo "$help_message"

    end_eco

    # printf "${BLUE}%s${NC} | For more information, visit\n" "$APPLICATION_NAME"
}

# Invoke the appropriate function based on the command
if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$2" = "--help" ]; then
    help
else
    "$@"
fi
