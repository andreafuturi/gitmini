#!/usr/bin/env bash
#make ticket name with dashes

publish() {
    #if no remote is provided, tell user how to configure it
    # if [[ -z $(git remote) ]]; then
    #     echo "No remote repository found. Please configure one using:"
    #     echo "git remote add origin <remote repository URL>"
    #     exit 1
    # fi

    #get ticket name if provided otherwise use current ticket
    if [[ -n "$1" ]]; then
        ticket="$1"
        #if current ticket is not the same as the one provided, start the provided ticket
        if [[ "$ticket" != "$(get_current_ticket)" ]]; then
            start "$ticket"
        fi
    else
        if [[ ! -f .git/current-ticket ]]; then
        #start a ticket if none is started
            echo "You did not start a ticket yet, creating one for you..."
            start "$1"
        fi
        ticket=$(get_current_ticket)
    fi

    git add -A #mark fixed conflicts as resolved (should be done in refresh?)

    refresh
    #double_check_conflicts

    #commit and push
    git add -A
    git commit -m "$ticket"
    git push  &>/dev/null && finish_ticket && echo "Work on \"$ticket\" published successfully."

    #finish work on current ticket
    
}

unpublish() {
    # Safely update your local repository
    git update

    # Get the commit hash or reference associated with the ticket
    ticket=${1:-$(get_current_ticket)}

    # Find the commit with the matching ticket name
    commit_hash=$(git log --grep="$ticket" --pretty=format:%H -n 1)

    if [[ -z $commit_hash ]]; then
        echo "No ticket created with the name \"$ticket\"."
        exit 1
    fi

    # Revert the commit
    git revert --no-commit "$commit_hash"

    # Check for conflicts after reverting
    conflict_files=$(grep -r '<<<<<<<|=======|>>>>>>>' .)
    if [[ -n $conflict_files ]]; then
        echo "Please fix conflicts in the following files after reverting:"
        echo "$conflict_files"
        exit 1
    fi

    # Add all changes to the staging area
    git add .

    # Create a revert commit with the ticket name
    git commit -m "revert of $ticket"

    # Push the changes to the remote repository
    git push

    echo "Unpublishing of \"$ticket\" completed successfully."
}


start() {
    if [[ ! -d .git ]]; then
        echo "Git repository not found. Initializing a new repository..."
        git init
    fi

    git add -A #mark fixed conflicts as resolved

    #if no ticket name is provided, use the next ticket number
    ticket=${1:-"WIP-$(get_next_ticket_number)"}
    # Replace spaces with dashes in the ticket name
    ticket=${ticket// /-}


    #if another ticket is in progress, pause it (stash it)
    if [ -f .git/current-ticket ]; then
        existing_current_ticket=$(get_current_ticket)
        if [ "$ticket" != "$existing_current_ticket" ]; then
            pause "$existing_current_ticket"
        fi
    fi

    #resume any work in progress of that ticket
    stash_ref=$(git stash list | grep -w "$1" | cut -d "{" -f2 | cut -d "}" -f1)
    git stash apply stash@{$stash_ref} &>/dev/null
    git stash drop stash@{$stash_ref} &>/dev/null


    #update codebase
    refresh

    #update current ticket value
    echo "$ticket" > .git/current-ticket
    echo "Work on \"$ticket\" started successfully."

}

pause() {
    current_ticket=${1:-$(get_current_ticket)}
    git stash push -m "$current_ticket" &>/dev/null
    echo "Work on \"$current_ticket\" paused successfully."
    finish_ticket
}

refresh() {
    #get current ticket name if started otherwise use temp name for stash
    current_ticket=${get_current_ticket:-"temp-WIP-$(date +%s)"}

    #stash before pulling
    git stash push -m "$current_ticket" -u &>/dev/null
    git pull &>/dev/null

    #apply and than delete stash after pulling
    stash_ref=$(git stash list | grep -w "$current_ticket" | cut -d "{" -f2 | cut -d "}" -f1)
    git stash apply stash@{$stash_ref} &>/dev/null
    git stash drop stash@{$stash_ref} &>/dev/null

    check_conflicts
}

current() {
    if [ -f .git/current-ticket ]; then
        echo "You are currently working on: $(get_current_ticket)"
    else
        echo "You are not currently working on anything."
    fi
}
check_conflicts() {
    unresolved_files=$(git diff --name-only --diff-filter=U)
    if [[ -n $unresolved_files ]]; then
        echo "BEFORE DOING ANYTHING ELSE, FIX CONFLICTS IN THE FOLLOWING FILES:"
        echo "$unresolved_files"
        exit 1
    fi
}

double_check_conflicts() {
    conflict_files=$(grep -r '<<<<<<<|=======|>>>>>>>' .)
    if [[ -n $conflict_files ]]; then
        echo "Please fix conflicts in the following files and try again:"
        echo "$conflict_files"
        exit 1
    fi
}

get_current_ticket() {
    ticket=$(cat .git/current-ticket)
    echo $ticket
}

get_next_ticket_number() {
    last_ticket_number=0
    if [ -f .git/last-ticket-number ]; then
        last_ticket_number=$(cat .git/last-ticket-number)
    fi
    next_ticket_number=$((last_ticket_number + 1))

    echo "$next_ticket_number" > .git/last-ticket-number

    echo "$next_ticket_number"
}

finish_ticket() {
    #finish work on current ticket
     rm -f .git/current-ticket 2>/dev/null &>/dev/null
}

# Invoke the appropriate function based on the command
"$@"


#publish
#show files that will be published + ai description that tries to tell you what you are about to publish
#ask for confirmation (makemsure you test your code before publishing)
#git update send update to remote even if there are no changes 

#git undo to remove current changes when not yet published (not permantely deleted, you can still recover them with git redo)
#git reload, pause every ticket, with -f should reset repository to server version
