# GitMini: Less git, more work done.


Gitmini is a minimal set of git commands designed to simplify developers workflow. 
Its primary goal is to automate various aspects of Git, enabling developers to focus on writing code rather than managing their repositories. 
Gitmini revolves around the concept of tickets, which are commonly used to organize and track work progress in software development.


The commands in Gitmini are intuitively named, even for users unfamiliar with Git or version control in general.



## Usage


The main command in GitMini is `git publish`, which simplifies the process of publishing code changes. Use if after working on the repo like this:

```bash
git publish "Ticket name/number"
```

When executed, the git publish command automates the following actions:
  - Safely updates your local repository with `git update`
  - Asks you to fix conflicts if they're present
  - Adds all changes to the staging area using `git add .`
  - Commits the changes using specified ticket name (defaults to WIP-date) `git commit -m "WIP-date"`
  - Pushes your changes to repository's server so other people can get your changes `git push`

(Soon, an option to create a merge request instead of directly pushing to the master branch will be added.)

```bash
git unpublish "Ticket name/number"
```
When executed, the git publish command automates the following actions:
- Safely updates your local repository with `git update`
- Asks you to fix conflicts if they're present
- Reverts the commit of the ticket you want to unpublish
- Asks you fix conflicts if they're present
- Adds all changes to the staging area using `git add .`
- Commits the changes using specified ticket name (defaults to WIP-date) `git commit -m "revert of WIP-date"`
- Pushes your changes to repository's server so other people can get your revert `git push`

Git unpublish is still under work
  
### Optional Commands

```bash
git start "name of ticket"
```



The git start command begins work on a new ticket. It performs the following actions:
  - Retrieves updates from remote origin to ensure you are working on an up-to-date codebase using `git update`
  - Prompts you to resolve any conflicts, if present.
  - Prepare name of ticket as commit message when publishing with git publish (usefult for a future jira integration, name defaults to WIP-currentdate when no specified)

In case you forgot doing it, you can start working on a ticket after you edited some files. They will published when you git publish

```bash
git update
```



git update is used everytime we start or publish a ticket. It automates the following tasks:
  - Temporary saves any changes you have going on with `git stash`
  - gets an update from master so you work on up-to-date codebase with `git pull`
  - Prompts you to fix conflicts if present
  - Installs any package recently added to repositiory with `npm install` (this is only web devs, should be optional or in another complementar tool)
  - Applies your changes again `git stash pop`

In the future it will be possible to run update every n seconds to be always updated and receive conflicts as soon as possible.
```bash
git current
```
Returns the name of the current ticket you're working on, in case your forgot.


## Install: 
1. Open a terminal or command prompt.
2. Run the following command to open the Git configuration file in a text editor:
`git config --global --edit`
This command will open the global Git configuration file (~/.gitconfig) in your default text editor.
3. Copy and paste the aliases definitions (start, pause, update, publish, reload, current) at the end of the file.
4. Save the file and exit the text editor.

That's it! You have added the aliases to your Git configuration. You can now use these aliases in your Git commands.

## Aliases

```bash
[alias]
	start = "!f() { \
        git add . && \
        message=${1:-\"WIP $(date +%s)\"}; \
        if [ -f .git/commit-message ]; then \
            existing_message=$(cat .git/commit-message); \
            if [ \"$message\" != \"$existing_message\" ]; then \
				git pause \"$existing_message\"; \
			fi \
        fi; \
        echo \"$message\" > .git/commit-message; \
        echo \"Work on \"$message\" started successfully.\" && \
        git update \"$message\" ; \
    }; f"
	pause="!f() { \
    message=${1:-$(cat .git/commit-message 2>/dev/null)}; \
    git stash push -m \"$message\" &>/dev/null && \
    echo \"Work on \"$message\" paused successfully.\" && \
    git reload &>/dev/null; \
}; f"
    # if no changes are going on a simple pull should be faster
    # what if there are changes going on but there is also a stash with the same name? ideally apply both of them
    update = "!f() { \
        if [[ -z \"$1\" ]]; then \
            message=$(cat .git/commit-message 2>/dev/null); \
            message=${message:-\"WIP $(date +%s)\"}; \
        else \
            message=$1; \
        fi; \
        git stash push -m \"$message\" -u &>/dev/null; \
        git pull &>/dev/null; \
        stash_ref=$(git stash list | grep -w \"$message\" | cut -d \"{\" -f2 | cut -d \"}\" -f1); \
        git stash apply stash@{$stash_ref} &>/dev/null; \
        git stash drop stash@{$stash_ref} &>/dev/null; \
        unresolved_files=$(git diff --name-only --diff-filter=U); \
        if [[ -n $unresolved_files ]]; then \
            echo \"BEFORE DOING ANYTHING ELSE, FIX CONFLICTS IN THE FOLLOWING FILES:\"; \
            echo \"$unresolved_files\"; \
        fi; \
        commit_range=\"HEAD~$stash_ref..HEAD\"; \
        modified_files=$(git diff --name-only $commit_range); \
        if echo \"$modified_files\" | grep -q \"package.json\"; then \
            npm install; \
        fi; \
    }; \
    f"
	publish = "!f() { \
    git add . && \
    if [[ ! -f .git/commit-message ]]; then \
        echo \"You did not start a ticket yet, creating one for you...\"; \
        git start $1; \
    fi; \
    message=$(cat .git/commit-message); \
	git update \"$message\" && \
    if [[ -n $(git diff --name-only --diff-filter=U) ]]; then \
      echo \"Please fix conflicts and try againg.\"; \
      exit 1; \
    fi; \
    git add . && \
    git commit -m \"$message\" && \
	git push && \
	git reload &>/dev/null; \
  }; f"
reload = "!rm -f .git/commit-message 2>/dev/null && echo 'Commit message file successfully removed.'"
 current = "!f() { \
        if [ -f .git/commit-message ]; then \
            echo \"You are currently working on: $(cat .git/commit-message)\"; \
        else \
            echo \"You are not currently working on anything.\"; \
        fi; \
    }; f"
```

## Examples: 


### Minimal Approach
Edit files in repository and then
```bash
git publish ticket-45
```

 or
```bash
git start "work on the new login page"
```

Edit files in repository and then 
```bash
git publish
```


### Multitasking
```bash
git start feature-1
```
Do your work...

Blocked? Start a new ticket!

```bash
git start feature-2
```

More urgent ticket? Work on that!

```bash
git start bug-1
```

Do your work...
```bash
git publish
```
Go back to feature-1
```bash
git start feature-1
```
Go back to feature-2
```bash
git start feature-2
```
**Publish the remaining tickets when completed**
```bash
`git publish feature-1`
```

`git publish feature-2`




