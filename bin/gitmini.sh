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
        ticket="$1"
        # If the current ticket is not the same as the one provided, start the provided ticket
        if [[ "$ticket" != "$current_ticket" ]]; then
            start "$1"
        fi
    else
        if [ -z "$current_ticket" ]; then
            # Start a ticket if none is started
            start_eco
            echo -e "${BLUE}GitMini${NC} | No ticket started yet, creating one..."
            end_eco
            start "$1"
        fi
        ticket="$(get_current_ticket)"
    fi
    update "$ticket"
    start_eco
    echo -e "${GREEN}GitMini | Work on \"$ticket\" published successfully.${NC}"
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
        echo "${RED}GitMini | No ticket created with the name \"$ticket\".${NC}"
        end_eco
        exit 1
    fi

    # Revert the commit
    git revert --no-commit "$commit_hash" &>/dev/null

    # Check for conflicts after reverting
    check_conflicts

    # Add all changes to the staging area
    git add . &>/dev/null

    # Create a revert commit with the ticket name
    git commit -m "revert of $ticket" && git push &>/dev/null 
    start_eco
    echo -e "${GREEN}GitMini | Unpublishing of \"$ticket\" completed successfully.${NC}"
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
    echo "Uploading your changes..."
    end_eco
    git add -A &>/dev/null
    git commit -m "${1:-$current_ticket-WIP}" &>/dev/null
    git push --set-upstream origin &>/dev/null
    # Switch to the master branch and merge changes from the ticket branch with a single commit
    git checkout "$master_name" &>/dev/null
    git merge "$ticket" --squash --no-commit &>/dev/null
    git commit -m "${1:-$current_ticket-WIP}" &>/dev/null
    # Push changes to the master branch
    git push &>/dev/null
    start_eco
    echo -e "${GREEN}GitMini | Project updated with \"$ticket\" successfully.${NC}"
    end_eco
}

# Function: start
#
# Start working on a new ticket by creating a new branch with the specified name.
# If no name is provided, a default ticket name is generated.
#
# Usage: start [ticket_name]

start() {
    if [[ ! -d .git ]]; then &>/dev/null
        start_eco
        echo -e "${BLUE}GitMini${NC} | Repository not found. Initializing a new one..."
        end_eco
        git init &>/dev/null
        #make first repo commit
        #create readme
        echo "#Created with GitMini" >> README.md
        git add -A &>/dev/null
        git commit -m "first commit" &>/dev/null
    fi

    git add -A &>/dev/null # mark fixed conflicts as resolved

    ticket=${1:-"WIP-$(date +%d-%m-%Y-%H-%M-%S)"} 
    # Replace spaces with dashes in the ticket name
    ticket=${ticket// /-}
    existing_current_ticket=$(get_current_ticket)
    # if another ticket is in progress, pause it
    
    if [[ -n "$existing_current_ticket" && "$ticket" != "$existing_current_ticket" ]]; then
        start_eco
        echo -e "${BLUE}GitMini${NC} | You are already working on \"$existing_current_ticket\". Pausing it now..."
        end_eco
        pause "$existing_current_ticket"
    fi
    # create a new branch for the ticket
    if git show-ref --quiet --verify refs/heads/"$ticket"; then
        git checkout "$ticket" &>/dev/null
    else
        git checkout -b "$ticket" &>/dev/null
    fi

    # update codebase
    refresh
    start_eco
    echo -e "${GREEN}GitMini | Work on \"$ticket\" started successfully.${NC}"
    end_eco
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
        echo -e "${RED}GitMini | You didn't start any ticket.${NC}"
        end_eco
        exit 1
    fi
    git add -A &>/dev/null
    git commit -m "$current_ticket paused" &>/dev/null
        
    # Switch to the master branch
    git checkout "$master_name" &>/dev/null
    start_eco
    echo -e "${GREEN}GitMini | Work on \"$current_ticket\" paused successfully.${NC}"
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

    # Check if $master_name has new code
    commit_count=$(git rev-list HEAD..origin/"$master_name" --count 2>/dev/null | tr -d '[:space:]')
    if [[ "$commit_count" =~ ^[0-9]+$ ]]; then
        if [ "$commit_count" -gt 0 ]; then
            start_eco
            echo -e "${BLUE}GitMini${NC} | Downloading team changes..."
            end_eco
            # Switch to the master branch and pull updates
            git checkout "$master_name" &>/dev/null && git pull &>/dev/null
            # Switch back to the current ticket branch
            git checkout "$current_ticket" &>/dev/null
            # Merge changes from master into the current ticket branch
            git merge "$master_name" --no-commit &>/dev/null
            git add -A &>/dev/null
            git commit -m "$current_ticket update with other tickets" &>/dev/null
        fi
    fi
    start_eco
    echo -e "${BLUE}GitMini | Code has been refreshed!${NC}"
    end_eco
    check_conflicts
    
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


start_eco() {
    echo "========================================"
    echo
}
end_eco() {
    echo -e "\n========================================"
}
# Function: check_conflicts
#
# Check if there are any merge conflicts in the current ticket branch.
# If conflicts are found, display the conflicting files and prompt the user to fix them.
#
# Usage: check_conflicts

check_conflicts() {
    conflict_files=$(git grep -l -Ee '<<<<<<<.*(\|\||====|>>>>>>>)')
    if [[ -n $conflict_files ]]; then
        echo -e "${ORANGE}Please fix conflicts in the following files:${NC}"
        echo 
        echo "$conflict_files"
        echo
        read -rp "After testing everything again, press Enter to continue..."

        # Check for conflicts again after testing
        conflict_files=$(git grep -l -Ee '<<<<<<<.*(\|\||====|>>>>>>>)')
        if [[ -n $conflict_files ]]; then
            echo -e "${RED}There are still conflicts! Please try again.${NC}"
            echo
            check_conflicts
        else
            echo -e "${GREEN}Conflicts resolved successfully.${NC}"
            git add -A &>/dev/null
        fi
    fi
}

# Function: install
#
# Install GitMini by setting up global aliases for the exposed commands.
#
# Usage: install

install() {
  commands=("publish" "unpublish" "start" "refresh" "current" "pause")

  for cmd in "${commands[@]}"; do
    git config --global "alias.$cmd" "!$0 $cmd"
  done

echo -e "\033[0;32mGitMini installed successfully.${NC}"
}

# Invoke the appropriate function based on the command
if [[ $# -eq 0 ]]; then
  install
else
  "$@"
fi


#Developed by Andrea Futuri <3