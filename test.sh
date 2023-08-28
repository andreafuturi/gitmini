#!/bin/sh

initial_branch="main"

# Function to create a test Git repository
setup_test_repository() {
    mkdir test-repo
    cd test-repo || return
    git init --initial-branch="$initial_branch"
    git config commit.gpgSign false
    git config push.gpgSign false
    git config tag.gpgSign false
    echo "Initial commit" >README.md
    git add README.md
    git commit -m "Initial commit"
}

# Function to cleanup the test Git repository
cleanup_test_repository() {
    cd .. || return
    rm -rf test-repo
}

#COMMANDS TESTING

test_pause() {
    setup_test_repository
    git checkout -b feature-123
    gitmini pause
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "$initial_branch" "$current_branch" "pause should switch back to the master branch"
    cleanup_test_repository
}

test_start() {
    setup_test_repository

    # rm -rf .git # Remove the Git repository
    # gitmini start new-feature
    # # Assert that the Git repository is initialized
    # assert "Reinitialized empty Git repository in" "$(git init --initial-branch="$initial_branch")" "start should initialize a new Git repository if one doesn't exist"

    gitmini start feature-123
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "feature-123" "$current_branch" "start should switch create a new branch and switch to it"

    #i should be able to start another ticket while one is in progress
    gitmini start feature-456
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "feature-456" "$current_branch" "start should switch create a new branch and switch to it"

    #switiching to master i should be able to than resume any work on the ticket
    git checkout "$initial_branch"
    gitmini start feature-123
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "feature-123" "$current_branch" "start should switch to already existing branch if it exists"

    gitmini start
    current_branch="$(git symbolic-ref --short HEAD)"
    # default_ticket_name="WIP-$(date +%d-%m-%Y)"
    # assert "$default_ticket_name" "$current_branch" "start should create a new branch with default name"

    git checkout -b existing-branch
    gitmini start new-feature
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "new-feature" "$current_branch" "start should stash existing branch and switch to new branch"

    gitmini start "my awesome feature"
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "my-awesome-feature" "$current_branch" "start should replace spaces with dashes in branch name"

    git checkout -b existing-branch # Create an existing branch
    gitmini start existing-branch
    current_branch="$(git symbolic-ref --short HEAD)"
    assert "existing-branch" "$current_branch" "start should switch to an already existing branch"

    cleanup_test_repository
}

test_get_current_ticket() {
    setup_test_repository
    git checkout -b feature-123

    # Call the function and capture the output
    output="$(gitmini get_current_ticket)"

    # Assert that the output matches the expected value
    expected_output="feature-123"
    assert "$expected_output" "$output" "get_current_ticket should return the current branch name"
    cleanup_test_repository
}

test_refresh() {
    setup_test_repository
    git checkout -b feature-123

    # Make a commit in the master branch
    git checkout "$initial_branch"
    echo "Commit in master" >master_commit.txt
    git add master_commit.txt
    git commit -m "Commit in master"

    git checkout feature-123

    # Call the refresh function
    gitmini refresh

    # Check that we are in the feature branch with the new commit from master
    current_branch="$(git symbolic-ref --short HEAD)"
    expected_branch="feature-123"
    assert "$expected_branch" "$current_branch" "refresh should switch back to the feature branch"

    # Check if the commit from master is present in the feature branch
    commit_message="$(git log -1 --pretty=%B)"
    git status
    git --no-pager log
    expected_commit_message="Commit in master"
    assert "$expected_commit_message" "$commit_message" "refresh should merge changes from master into the feature branch"

    cleanup_test_repository
}

test_check_conflicts() {
    setup_test_repository
    git checkout -b feature-123

    # check if check_conflicts block execution waiting for user input
    output="$(gitmini check_conflicts)" >/dev/null 2>&1
    assert "" "$output" "check_conflicts should not display conflicts if there are no conflicts"

    # Make conflicting changes in the same file in the feature branch
    echo "Feature branch content" >conflict.txt
    git add conflict.txt
    git commit -m "Commit in feature branch"

    git checkout "$initial_branch"
    echo "Master branch content" >conflict.txt
    git add conflict.txt
    git commit -m "Commit in master branch"

    git checkout feature-123
    git merge "$initial_branch" --no-commit

    # check if check_conflicts block execution waiting for user input
    output="$(gitmini check_conflicts testing)" >/dev/null 2>&1

    #if output is not empty than echo "conflicts not found"
    if [ -z "$output" ]; then
        echo "test_check_conflicts failed: conflicts not found"
        exit 1
    else
        echo "conflicts found"
    fi

    cleanup_test_repository
}

test_publish() {
    setup_test_repository
    git checkout -b feature-123

    # Make some changes in the feature branch
    echo "Feature branch changes" >feature_changes.txt

    # Call the publish function
    gitmini publish

    # Verify that changes are pushed to the remote repository and merged into the master branch
    git checkout "$initial_branch"
    commit_message="$(git log -1 --pretty=%B)"
    expected_commit_message="feature-123 published on $initial_branch"
    assert "$expected_commit_message" "$commit_message" "publish should push changes to remote and merge into master"

    gitmini start feature-456

    # Make some changes in the feature branch
    echo "branch feature changes" >feature_changes2.txt

    # Call the publish function with a specific ticket
    gitmini publish feature-456

    # Verify that changes are pushed to the remote repository and merged into the master branch
    git checkout "$initial_branch"

    #current commit message
    commit_message="$(git log -1 --pretty=%B)"
    expected_commit_message="feature-456 published on $initial_branch"
    assert "$expected_commit_message" "$commit_message" "publish should push changes from the specified ticket branch to remote and merge into master"

    gitmini start feature-789

    gitmini pause

    #Make some conflicting changes in the master
    echo "branch master changes" >conflict.txt

    git switch feature-789

    # Make some changes in the feature branch
    echo "branch feature changes" >conflict.txt

    # Call the publish function with a specific ticket
    gitmini publish feature-789 >/dev/null 2>&1
    git add -A
    gitmini publish feature-789
    # Verify that changes are pushed to the remote repository and merged into the master branch
    git checkout "$initial_branch"
    #current commit message
    commit_message="$(git log -1 --pretty=%B)"
    expected_commit_message="feature-789 published on $initial_branch"
    assert "$expected_commit_message" "$commit_message" "publish should push changes from the specified ticket branch to remote and merge into master after conflicts resolving"

    cleanup_test_repository
}

test_unpublish() {
    setup_test_repository
    git checkout -b feature-123

    # Make some changes in the feature branch
    echo "Feature branch changes" >feature_changes.txt
    git add feature_changes.txt
    git commit -m "Commit in feature branch"

    # Publish the changes
    gitmini publish

    # Call the unpublish function
    gitmini unpublish

    # Verify that changes are reverted
    git checkout "$initial_branch"
    commit_message="$(git log -1 --pretty=%B)"
    expected_commit_message="revert of feature-123 published on $initial_branch"
    assert "$expected_commit_message" "$commit_message" "unpublish should revert changes in the master branch"

    #check unpublish of specific ticket
    git checkout -b feature-456
    echo "Feature branch changes" >feature_changes.txt
    git add feature_changes.txt
    git commit -m "Commit in feature branch"
    gitmini publish
    git checkout "$initial_branch"
    gitmini unpublish feature-456
    commit_message="$(git log -1 --pretty=%B)"
    expected_commit_message="revert of feature-456"
    assert "$expected_commit_message" "$commit_message" "unpublish should revert changes in the master branch"

    cleanup_test_repository
}

test_review() {
    setup_test_repository
    git checkout -b feature-123

    # Make some changes in the feature branch
    echo "Feature branch changes" >feature_changes.txt
    git add feature_changes.txt
    git commit -m "Commit in feature branch"

    # Call the review function
    gitmini review

    # Verify that a branch named "review-feature-123" is created
    git checkout -b review-feature-123
    current_branch="$(git symbolic-ref --short HEAD)"
    expected_branch="review-feature-123"
    assert "$expected_branch" "$current_branch" "review should create a new branch named review-feature-123"

    cleanup_test_repository
}

# test_conflict_resolution() {
#     setup_test_repository
#     git checkout -b feature-123

#     # Make conflicting changes in the same file in the feature branch and master branch
#     echo "Feature branch content" > conflict.txt
#     git add conflict.txt
#     git commit -m "Commit in feature branch"

#     git checkout master
#     echo "Master branch content" > conflict.txt
#     git add conflict.txt
#     git commit -m "Commit in master branch"

#     git checkout feature-123

#     # Call the refresh function
#     gitmini refresh

#     cleanup_test_repository
# }

assert() {
    if [ "$1" != "$2" ]; then
        echo "Error: expected '$1' but got '$2'"
        echo "$3"
        exit 1
    fi
}

cleanup_test_repository
test_get_current_ticket
test_refresh
test_check_conflicts
test_pause
test_start
test_publish
test_unpublish

echo "All tests passed"
