#!/usr/bin/env bash

# COLORS FOR OUTPUT
BLUE='\033[0;34m'
NC='\033[0m' # No Color
ORANGE='\033[0;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'

# Function: get_master_name
#
# Retrieve the name of the default branch (e.g., master, main, or default) in the Git repository.
# If no default branch is found, create a new "master" branch.
#
# Usage: get_master_name

get_master_name() {
  if git remote show origin >/dev/null 2>&1; then
    default_branch=$(git remote show origin | awk '/HEAD branch/ {print $NF}')
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
    git checkout -b master &>/dev/null
    echo "master"
  fi
}

#save master name as global var
master_name=$(get_master_name)

# Function: publish
#
# Publish the changes made in the current or specified ticket branch.
# If no ticket is specified, use the current ticket in progress.
# If the specified ticket is different from the current ticket, start the specified ticket.
#
# Usage: publish [ticket_name]

publish() {
    current_ticket=${1:-$(get_current_ticket)}

    # Get ticket name if provided; otherwise, use the current ticket
    if [[ -n "$1" ]]; then
        ticket=$(echo "$1" | tr ' ' '-')
        # If the current ticket is not the same as the one provided, start the provided ticket
        #if provided ticket doesn't correspond to existing branch name didn't exist print Creating one...
        if ! git show-ref --quiet --verify refs/heads/"$ticket"; then
            start_eco
            echo -e "${BLUE}GitMini${NC} | Creating ticket on the fly..."
            end_eco
        fi
        if [[ "$ticket" != "$current_ticket" ]]; then
            start_eco
            echo -e "${BLUE}GitMini${NC} | Pausing ${current_ticket} and resuming ${ticket} work..."
            end_eco
        fi
        start "$1"
    else
        if [ -z "$current_ticket" ]; then
            # Start a ticket if none is started and no ticket name is provided
            start_eco
            echo -e "${BLUE}GitMini${NC} | Creating ticket on the fly..."
            end_eco
            start "$1"
        fi
        ticket="$(get_current_ticket)"
    fi
    update "$ticket" &>/dev/null
    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Work on \"$ticket\" published successfully.${NC}"
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

    current_ticket=$(get_current_ticket)
    if [[ -z "$1" && -z "$current_ticket" ]]; then
        ticket="$(git log -1 --pretty=%B)"
    else
        ticket=${1:-$current_ticket}
    fi

    git checkout "$master_name" &>/dev/null

    # Find the commit with the matching ticket name
    commit_hash=$(git log --grep="$ticket" --pretty=format:%H -n 1)

    if [[ -z $commit_hash ]]; then
        start_eco
        echo "${BLUE}GitMini${NC} | ${RED}No ticket created with the name \"$ticket\".${NC}"
        end_eco
        exit 1
    fi

    # Revert the commit
    git revert --no-commit "$commit_hash" &>/dev/null

    # Check for conflicts after reverting
    check_conflicts
    git add -A &>/dev/null

    # Create a revert commit with the ticket name
    git commit -m "revert of $ticket" && git push &>/dev/null
    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Unpublishing of \"$ticket\" completed successfully.${NC}"
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
    if [[ ! -d .git ]]; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | Repository not found. Initializing a new one..."
        end_eco
        git init &>/dev/null
        #make first repo commit
        #create readme
        echo "#Created with GitMini" >> README.md
        git add -A &>/dev/null
        git commit -m "first commit" &>/dev/null
        master_name=$(get_master_name) #update master name
    fi

    ticket=${1:-"WIP-$(date +%d-%m-%Y-%H-%M-%S)"}
    # Replace spaces with dashes in the ticket name
    ticket=${ticket// /-}
    existing_current_ticket=$(get_current_ticket)
    # if another ticket is in progress, pause it
    if [[ "$ticket" == "$existing_current_ticket" ]]; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | ${ORANGE}Work on \"$ticket\" $message_verb already started.${NC}"
        end_eco
    else
        if [[ -n "$existing_current_ticket" && "$ticket" != "$existing_current_ticket" ]]; then
            pause "$existing_current_ticket"
        fi
        # create a new branch for the ticket
        if git show-ref --quiet --verify refs/heads/"$ticket"; then
            git checkout "$ticket" &>/dev/null
            message_verb="resumed"
        else
            git checkout -b "$ticket" &>/dev/null
            message_verb="started"
        fi
        # update codebase
        start_eco
        echo -e "${BLUE}GitMini${NC} | ${GREEN}Work on \"$ticket\" \"$message_verb\" successfully.${NC}"
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
    current_ticket=${1:-$(get_current_ticket)}
    if [ -z "$current_ticket" ]; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | ${RED}You didn't start any ticket.${NC}"
        end_eco
        exit 1
    fi
    git add -A &>/dev/null
    git commit -m "$current_ticket paused" &>/dev/null

    # Switch to the master branch
    git checkout "$master_name" &>/dev/null
    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Work on \"$current_ticket\" paused successfully.${NC}"
    end_eco
}

# Function: update
#
# Update the current ticket branch with the changes made in the working directory.
# The updated changes are then merged with the master branch.
#
# Usage: update [ticket_name]

update() {
    refresh
    current_ticket=$(get_current_ticket)
    start_eco
    echo -e "${BLUE}GitMini${NC} | Uploading your changes..."
    end_eco
    git add -A &>/dev/null
    git commit -m "${1:-$current_ticket-WIP}" &>/dev/null
    git push --set-upstream origin &>/dev/null
    # Switch to the master branch and merge changes from the ticket branch with a single commit
    git checkout "$master_name" &>/dev/null
    git merge "$ticket" --squash --no-commit &>/dev/null
    check_conflicts
    git add -A &>/dev/null
    git commit -m "${1:-$current_ticket-WIP}" &>/dev/null
    # Push changes to the master branch
    git push &>/dev/null
    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Project updated with \"$ticket\" successfully.${NC}"
    end_eco
}




# Function: refresh
#
# Refresh the local repository by pulling changes from the current ticket branch and the master branch.
# The changes from the master branch are merged into the current ticket branch.
#
# Usage: refresh
refresh() {
    # Get the current ticket name
    current_ticket=$(get_current_ticket)

    # Check if there are any changes in the working tree
    if [[ $(git status --porcelain) ]]; then
        # Commit changes before pulling
        git add -A &>/dev/null
        git commit -m "${current_ticket:-temp-WIP-$(date +%s)}" &>/dev/null
        git push --set-upstream origin "$current_ticket" &>/dev/null
    fi

    # Pull updates from origin of the current ticket
    git pull &>/dev/null

    # Get the commit hash of your current branch's latest commit
    current_branch_commit=$(git rev-parse HEAD)

    # Get the commit hash of the latest commit on the master branch
    master_commit=$(git rev-parse "$master_name")

    if [ "$current_branch_commit" != "$master_commit" ]; then
        # Perform the merge only if it's needed
        start_eco
        echo -e "${BLUE}GitMini${NC} | Downloading team changes..."
        end_eco
        # Switch to the master branch and pull updates
        git checkout "$master_name" &>/dev/null && git pull &>/dev/null
        # Switch back to the current ticket branch
        git checkout "$current_ticket" &>/dev/null
        # Merge changes from master into the current ticket branch
        git merge "$master_name" --no-commit &>/dev/null
        check_conflicts
        git add -A &>/dev/null
        git commit -m "$current_ticket update with other tickets" &>/dev/null
    fi

    start_eco
    echo -e "${BLUE}GitMini${NC} | Refreshing code..."
    end_eco
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
        echo -e "${BLUE}GitMini${NC} | ${RED}Please provide at least two ticket names to combine.${NC}"
        end_eco
        exit 1
    fi

    # Prompt the user for the new ticket name
    read -rp "Enter the name for the combined ticket: " combined_branch
    combined_branch=${combined_branch// /-}

    # Create the combined branch
    #pause current ticket if present
    pause
    git checkout -b "$combined_branch" &>/dev/null

    # Merge each ticket branch into the combined branch
    for ticket_name in "$@"; do
        if git show-ref --quiet --verify refs/heads/"$ticket_name"; then
            git merge "$ticket_name" --no-commit &>/dev/null
            check_conflicts
            git add -A &>/dev/null
            git commit -m "Merging $ticket_name into $combined_branch" &>/dev/null
        else
            start_eco
            echo -e "${BLUE}GitMini${NC} | ${RED}\"$ticket_name\" does not exist.${NC}"
            end_eco
        fi
    done

    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Tickets merged into \"$combined_branch\" successfully.${NC}"
    end_eco
}

# Function: git_delete
#
# Delete the specified branch.
# Checks if the branch exists and is not the current branch before deleting.
#
# Usage: git_delete branch_name

delete() {
    ticket=${1:-$(get_current_ticket)}

    # Check if the ticket exists
    if ! git show-ref --quiet --verify refs/heads/"$ticket"; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | ${RED}Ticket \"$ticket\" does not exist.${NC}"
        end_eco
        exit 1
    fi

    pause "$ticket"

    # Delete the branch
    git branch -d "$ticket" &>/dev/null

    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Ticket \"$ticket\" deleted successfully.${NC}"
    end_eco
}

# Function: get_current_ticket
#
# Retrieve the name of the current ticket branch.
# If the current branch is the master branch, no ticket is in progress.
#
# Usage: get_current_ticket

get_current_ticket() {
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$branch" != "$master_name" ]]; then
        echo "$branch"
    fi
}

# Function: current
#
# Display the name of the current ticket being worked on, if any.
#
# Usage: current

current() {
    current_ticket=$(get_current_ticket)
    if [[ -n "$current_ticket" ]]; then
            start_eco
            echo -e "${BLUE}GitMini${NC} | You are currently working on ticket: ${BLUE}$current_ticket${NC}"
            end_eco
    else
        start_eco
        echo -e "${BLUE}GitMini${NC} | You didn't start any ticket."
        echo -e "${BLUE}GitMini${NC} | Start a new one with git start <ticket_name> or run directly git publish <ticket_name>"
        end_eco
    fi
}

# Function: check_conflicts
#
# Check if there are any merge conflicts in the current ticket branch.
# If conflicts are found, display the conflicting files and prompt the user to fix them.
#
# Usage: check_conflicts

check_conflicts() {
    # conflict_files=$(git grep -l -Ee '<<<<<<<.*(\|\||====|>>>>>>>)')
    conflict_files=$(git diff --name-only --diff-filter=U)
    if [[ -n $conflict_files ]]; then
        #if $1 is testing then don't show conflicts echo "conflicts found" else show conflicts
        if [[ "$1" == "testing" ]]; then
            echo "conflicts found"
        else
            show_conflicts
        fi
    fi
}

show_conflicts() {
    conflict_files=$(git diff --check)
     start_eco
        echo -e "${BLUE}GitMini${NC} | ${ORANGE}Please fix conflicts in the following files:${NC}"
        end_eco
        start_eco
        echo "$conflict_files"
        end_eco
        start_eco
        read -rp "After testing everything again, press Enter to continue..."
        end_eco
        # Check for conflicts again after testing
        #checks conflicts with more strategies
        conflict_files=$(git diff --check)


        if [[ -n $conflict_files ]]; then
            start_eco
            echo -e "${BLUE}GitMini${NC} | ${RED}There are still conflicts! Please remember to save files try again.${NC}"
            end_eco
            check_conflicts
        else
            start_eco
            echo -e "${BLUE}GitMini${NC} | ${GREEN}Conflicts resolved successfully.${NC}"
            end_eco
            git add -A &>/dev/null
        fi
}

# Function: git_list
#
# List all available ticket branches in the repository.
# Excludes the master branch from the list.
#
# Usage: git list

list() {
   ticket_branches=$(git branch --list | grep -v $master_name)
    if [ -z "$ticket_branches" ]; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | No ticket branches found."
        end_eco
    else
        start_eco
        echo -e "${BLUE}GitMini${NC} | Available ticket branches:"
        end_eco
        start_eco
        echo "$ticket_branches" | sed 's/^/  - /'  # Add a prefix "-" to each branch name
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
        current_ticket=$(get_current_ticket)
        new_ticket="$1"
    fi

    # Check if the current ticket branch exists
    if ! git show-ref --quiet --verify refs/heads/"$current_ticket"; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | ${RED}Ticket \"$current_ticket\" does not exist.${NC}"
        end_eco
        exit 1
    fi
    git branch -m "$current_ticket" "$new_ticket" &>/dev/null
    git checkout "$master_name" &>/dev/null
    git checkout "$new_ticket" &>/dev/null

    #Rename all commits with the new ticket name
    git filter-branch -f --env-filter "GIT_COMMITTER_NAME='$(git config user.name)'; GIT_COMMITTER_EMAIL='$(git config user.email)'; GIT_AUTHOR_NAME='$(git config user.name)'; GIT_AUTHOR_EMAIL='$(git config user.email)';" --msg-filter 'sed "s/'"$current_ticket"'/'"$new_ticket"'/g"' HEAD &>/dev/null

    # Push the new branch to the remote repository
    git push origin --delete old-branch-name &>/dev/null
    git push --set-upstream origin "$new_ticket" &>/dev/null

    start_eco
    echo -e "${BLUE}GitMini${NC} | ${GREEN}Ticket \"$current_ticket\" renamed to \"$new_ticket\" successfully.${NC}"
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
            read -rp "Enter your name: " name
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
            read -rp "Enter your email: " email
            # Set the local git email
            git config user.email "$email"
        fi
    fi
}

#Text formatting functions
start_eco() {
    echo "========================================"
    echo
}
end_eco() {
    echo -e "\n========================================"
}
# Function: help
#
# Display the help message.
#
# Usage: help

help() {
    start_eco
    echo -e "${BLUE}GitMini${NC} | Usage: git <command> [ticket_name]"
    echo -e "${BLUE}GitMini${NC} | Commands:"
    echo -e " - ${BLUE}start${NC}: Start or resume work on a ticket and refresh codebase."
    echo -e " - ${BLUE}publish${NC}: Publish the changes made in the current or specified ticket."
    echo -e " - ${BLUE}unpublish${NC}: Revert the changes made in the current or specified ticket."
    echo
    echo -e " - ${BLUE}rename${NC}: Rename a ticket (branch and commits)."
    echo -e " - ${BLUE}combine${NC}: Combine multiple ticket branches into one branch."
    echo
    echo -e " - ${BLUE}list${NC}: List all tickets opened until now."
    echo -e " - ${BLUE}current${NC}: Display the name of the current ticket being worked on."
    echo -e " - ${BLUE}pause${NC}: Pause the work on the current ticket by commiting the changes and switching to the master branch."
    echo
    echo -e " - ${BLUE}refresh${NC}: Refresh the local repository by downloading changes from the current ticket branch and the master branch."
    echo -e " - ${BLUE}update${NC}: Update team members with your work even if not finished."
    echo -e " - ${BLUE}delete${NC}: Delete the specified ticket."

    end_eco

    # echo -e "${BLUE}GitMini${NC} | For more information, visit
}

# Function: install
#
# Install GitMini by setting up global aliases for the exposed commands.
#
# Usage: install

install() {
  commands=("publish" "unpublish" "start" "refresh" "current" "pause" "combine" "update" "list" "rename" "delete")

  for cmd in "${commands[@]}"; do
    git config --global "alias.$cmd" "!$0 $cmd"
  done

echo -e "\033[0;32mGitMini installed successfully.${NC}"
}

# Invoke the appropriate function based on the command or install GitMini
if [[ $# -eq 0 ]]; then
  install
else
  "$@"
fi

