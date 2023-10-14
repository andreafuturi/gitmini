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
            print_banner "Creating ticket on the fly..."
        fi
        if [ "$ticket" != "$current_ticket" ]; then
            print_banner "Pausing $current_ticket and resuming $ticket work..."
        fi
        start "$ticket"
    else
        if [ -z "$current_ticket" ]; then
            # Start a ticket if none is started and no ticket name is provided
            print_banner "Publishing ticket on the fly..."
            # Directly push changes to the master branch
            refresh
            git add -A >/dev/null 2>&1
            git commit -m "WIP-$(date +%d-%m-%Y-%H-%M-%S)}" >/dev/null 2>&1
            git push >/dev/null 2>&1
            print_banner "Changes published successfully." "$GREEN"
            return
        fi

        ticket="$(get_current_ticket)"
    fi

    # Check if the ticket name starts with "review-"
    if [ "${ticket#review-}" != "$ticket" ]; then

        update "${ticket#review-} published on ${master_name}"
        # Delete the original ticket branch
        delete "$current_ticket" >/dev/null 2>&1
        print_banner "Work on \"${ticket#review-}\" published successfully." "$GREEN"

    else
        # Check if a review-ticket branch exists for the ticket
        review_branch="review-$ticket"
        if git show-ref --quiet --verify refs/heads/"$review_branch"; then
            # Switch to the review branch
            git checkout "$review_branch" >/dev/null 2>&1
            # Publish the review-ticket branch instead of the ticket branch
            update "${ticket#review-} published on ${master_name}"
        else
            update "${ticket} published on ${master_name}"
        fi
        print_banner "Work on \"$ticket\" published successfully." "$GREEN"

    fi
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
        print_banner "No ticket created with the name \"$ticket\"." "$RED"
        exit 1
    fi

    # Revert the commit
    git revert --no-commit "$commit_hash" >/dev/null 2>&1

    # Check for conflicts after reverting
    check_conflicts
    git add -A >/dev/null 2>&1

    # Create a revert commit with the ticket name
    git commit -m "revert of $ticket" && git push >/dev/null 2>&1
    print_banner "Unpublishing of \"$ticket\" completed successfully." "$GREEN"

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
        print_banner "Repository not found. Initializing a new one..."
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
        print_banner "Work on \"$ticket\" $message_verb already started." "$ORANGE"

    else
        if [ -n "$existing_current_ticket" ] && [ "$ticket" != "$existing_current_ticket" ]; then
            pause "$existing_current_ticket"
        fi
        # check if a review branch exists for the ticket
        review_branch="review-$ticket"
        if git show-ref --quiet --verify refs/heads/"$review_branch"; then
            # checkout to the review branch if it exists
            git checkout "$review_branch" >/dev/null 2>&1
            message_verb="resumed"
        else
            # create a new branch for the ticket
            if git show-ref --quiet --verify refs/heads/"$ticket"; then
                git checkout "$ticket" >/dev/null 2>&1
                #resume any work in progress of that ticket
                stash_ref=$(git stash list | grep -w "$1" | cut -d "{" -f2 | cut -d "}" -f1)
                git stash apply stash@\{"$stash_ref"\} >/dev/null 2>&1
                git stash drop stash@\{"$stash_ref"\} >/dev/null 2>&1
                message_verb="resumed"
            else
                git checkout -b "$ticket" >/dev/null 2>&1
                message_verb="started"
            fi
        fi
        # update codebase
        print_banner "Work on \"$ticket\" $message_verb successfully." "$GREEN"

        # update codebase /may be better to be before creating the branch?
    fi
    refresh
}

# Function: review
#
# Create or switch to a review branch for the specified ticket or the current ticket if not provided.
#
# Usage: review [ticket_name]

review() {
    refresh
    ticket="${1:-$(get_current_ticket)}"
    if [ -z "$ticket" ]; then
        # List all existing review branches
        list_review_branches
        return
    fi
    start "$ticket"
    review_branch="review-$ticket"

    # Check if the review branch already exists
    if git show-ref --quiet --verify refs/heads/"$review_branch"; then
        # Switch to the existing review branch
        git checkout "$review_branch" >/dev/null 2>&1

        #commit that revert all commits that are not yet in master
        git revert -n "$master_name".."$review_branch"
        git add . && git commit -m "clean branch to see edits"

        #reverts the revert commit and show all edits in the working tree
        git revert HEAD -n

        print_banner "You're reviewing \"$ticket\"."

    else
        # Create a new review branch based on the master branch
        git checkout -b "$review_branch" "$master_name" >/dev/null 2>&1
        git cherry-pick -n "$ticket" >/dev/null 2>&1
        git add . >/dev/null 2>&1
        git commit -m "$ticket changes" >/dev/null 2>&1
        git push --set-upstream origin "$review_branch" >/dev/null 2>&1

        print_banner "\"$ticket\" is now ready for team review."
        # Switch back to the main branch
        pause "$ticket"

    fi
}

# Function: list_review_branches
#
# List all existing review branches.

list_review_branches() {
    review_branches="$(git branch --list | grep "review-" | sed 's/^..//' | sed 's/review-//')" # Remove the "review-" prefix
    if [ -z "$review_branches" ]; then
        print_banner "Nothing needs to be reviewed."

    else
        print_banner "Work in wait of review:"
        echo "$review_branches" | sed 's/^/  - /' | print_banner
    fi
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
        print_banner "You didn't start any ticket." "$RED"
        exit 1
    fi

    #Stash changes before switching to the master branch with branch name
    git stash push -m "$current_ticket" -u >/dev/null 2>&1

    # Switch to the master branch
    git checkout "$master_name" >/dev/null 2>&1
    print_banner "Work on \"$current_ticket\" paused successfully." "$GREEN"
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

    git add -A >/dev/null 2>&1
    git commit -m "${1:-$current_ticket-WIP}" >/dev/null 2>&1
    git push --set-upstream origin >/dev/null 2>&1

    # Switch to the master branch and merge changes from the ticket branch with a single commit
    git checkout "$master_name" >/dev/null 2>&1
    git pull >/dev/null 2>&1
    # make sure we are on master, otherwise don't publish anything

    git merge "$ticket" --squash --no-commit -Xignore-all-space >/dev/null 2>&1
    check_conflicts
    git add -A >/dev/null
    git commit -m "${1:-$current_ticket-WIP}" >/dev/null 2>&1
    # Push changes to the master branch
    git push >/dev/null 2>&1

    # Check if the commit is present on the master branch
    commit_present_on_master=$(git log "$master_name" --oneline | grep -c "${1:-$current_ticket-WIP}")

    # Check if the commit is present on the master branch
    commit_present_on_remote_master=$(git log origin/"$master_name" --oneline | grep -c "${1:-$current_ticket-WIP}")
    if [ "$commit_present_on_master" -eq 0 ]; then
        print_banner "Error: Could not publish \"$current_ticket\". Please try again" "$RED"
        exit 1
    fi

    #this should be done only if a origin exists

    if [ "$commit_present_on_remote_master" -eq 0 ]; then
        print_banner "Error: Could not update server with \"$current_ticket\". Please check your connection" "$RED"
        exit 1
    fi

    print_banner "Project updated with \"$ticket\" successfully." "$GREEN"

}

# Function: refresh
#
# Refresh the local repository by pulling changes from the current ticket branch and the master branch.
# The changes from the master branch are merged into the current ticket branch.
#
# Usage: refresh [interval_in_seconds]

# shellcheck disable=SC2120
refresh() {
    print_banner "Code Refreshed" "$BLUE"

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
            print_banner "Downloading Team Changes"
            # Merge changes from master into the current ticket branch
            git merge "$master_name" --no-commit -Xignore-all-space >/dev/null 2>&1
            check_conflicts
            git add -A >/dev/null 2>&1
            git commit -m "$current_ticket update with other tickets" >/dev/null 2>&1
        fi
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
    # Default first ticket name should be the current one if only one ticket name is provided,
    # otherwise combine the given ticket names normally
    if [ "$#" -lt 2 ]; then
        print_banner "Please provide at least two ticket names to combine." "$RED"
        exit 1
    fi

    # Prompt the user for the new ticket name
    printf "Enter the name for the combined ticket: "
    read -r combined_branch
    combined_branch="$(echo "$combined_branch" | sed 's/ /-/g')"

    # Create the combined branch
    # Pause current ticket if present
    pause
    git checkout -b "$combined_branch" >/dev/null 2>&1

    # Merge each ticket branch into the combined branch
    for ticket_name in "$@"; do
        if git show-ref --quiet --verify refs/heads/"$ticket_name"; then
            git merge "$ticket_name" --no-commit -Xignore-all-space >/dev/null 2>&1
            check_conflicts
            git add -A >/dev/null 2>&1
            git commit -m "Merging $ticket_name into $combined_branch" >/dev/null 2>&1
        else
            print_banner "\"$ticket_name\" does not exist." "$RED"
        fi
    done

    print_banner "Tickets merged into \"$combined_branch\" successfully." "$GREEN"
}

# Function: delete
#
# Delete the specified ticket branches.
# Checks if the branches exist and are not the current branch before deleting.
#
# Usage: delete [ticket_name1] [ticket_name2] ... [ticket_name_n]

delete() {
    for ticket in "$@"; do
        # Check if the ticket exists
        if git show-ref --quiet --verify refs/heads/"$ticket"; then
            # If the ticket is in progress, pause it before deleting
            if [ "$(get_current_ticket)" = "$ticket" ]; then
                pause "$ticket"
            fi
            git branch -D "$ticket" >/dev/null 2>&1
            print_banner "Ticket \"$ticket\" deleted successfully." "$GREEN"
        else
            print_banner "\"$ticket\" does not exist." "$RED"
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
        print_banner "You are currently working on ticket: $current_ticket"
    else
        print_banner "You didn't start any ticket. 

Start a new one with git start <ticket_name> or run directly git publish <ticket_name>"
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
    print_banner "Please fix conflicts in the following files:" "$ORANGE"
    echo "$conflict_files"
    print_banner "After testing everything again, press Enter to continue..." "$ORANGE"
    read -r __

    # Check for conflicts again after testing
    # Checks conflicts with more strategies
    conflict_files="$(git diff --check)"

    if [ -n "$conflict_files" ]; then
        print_banner "There are still conflicts! Please remember to save files and try again." "$RED"
        check_conflicts
    else
        print_banner "Conflicts resolved successfully." "$GREEN"
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
        print_banner "No tickets found. Create one with git start <ticket_name>"
    else
        print_banner "Available ticket branches:"
        echo "$ticket_branches" | sed 's/^/  - /' # Add a prefix "-" to each branch name
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
        printf "========================================\n\n"
        printf "${BLUE}%s${NC} | ${RED}Ticket \"%s\" does not exist.${NC}\n" "$APPLICATION_NAME" "$current_ticket"
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

    printf "========================================\n\n"
    printf "${BLUE}%s${NC} | ${GREEN}Ticket \"%s\" renamed to \"%s\" successfully.${NC}\n" "$APPLICATION_NAME" "$current_ticket" "$new_ticket"
    printf "\n========================================\n"
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

#Text formatting function
print_banner() {
    message="$1"
    color="$2"
    printf "========================================\n\n"
    printf "${BLUE}%s${NC} | ${color}%s${NC} \n" "$APPLICATION_NAME" "$message"
    printf "\n========================================\n"
}

# Function: help
#
# Display the help message.
#
# Usage: help

help() {
    printf "========================================\n\n"

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

    printf "\n========================================\n"

    # printf "${BLUE}%s${NC} | For more information, visit\n" "$APPLICATION_NAME"
}

# Invoke the appropriate function based on the command
if [ "$#" -eq 0 ] || [ "$1" = "-h" ] || [ "$2" = "--help" ]; then
    help
else
    "$@"
fi
