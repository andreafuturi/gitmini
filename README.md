# GitMini: Less git, more work done.


Gitmini is a minimal set of git commands designed to simplify developers' workflows and make their lives much easier. 
Its primary goal is to automate various aspects of Git, enabling developers to focus on writing code rather than managing their repositories. 
Gitmini revolves around the concept of tickets, which are commonly used in software development to organize and track work.


The commands in Gitmini are intuitively named, even for users unfamiliar with Git or version control in general.



## Usage


The main command in GitMini is `git publish`, which simplifies the process of publishing code changes. Use the following syntax to execute the command:


`git publish`


When executed, the git publish command automates the following actions:
  - Safely updates your local repository with `git update`
  - Asks you to fix conflicts if they're present
  - Adds all changes to the staging area using `git add .`
  - Commits the changes using specified ticket name (defaults to WIP-date) `git commit -m "WIP-date"`
  - Pushes your changes to repository's server so other people can get your changes `git push`

(Soon, an option to create a merge request instead of directly pushing to the master branch will be added.)



### Optional Commands


`git start "name of ticket"`




The git start command begins work on a new ticket. It performs the following actions:
  - Retrieves updates from remote origin to ensure you are working on an up-to-date codebase using `git update`
  - Prompts you to resolve any conflicts, if present.
  - Prepare name of ticket as commit message when publishing with git publish (usefult for a future jira integration, name defaults to WIP-currentdate when no specified)


`git update`




git update is used everytime we start or publish a ticket. It automates the following tasks:
  - Temporary save any changes you have going on with `git stash`
  - get an update from master so you work on up-to-date codebase with `git pull`
  - Prompt you to fix conflicts if present
  - Install any package recently added to repositiory with `npm install`
  - Apply your changes again `git stash pop`

In the future it will be possible to run update every n seconds to be always updated and receive conflicts as soon as possible.



## Examples: 


### Minimal Approach

`git publish ticket-45`

 or

`git start "work on the new login page"
git publish`


### Multitasking

`git start feature-1`
Do your work...
...
Blocked? Start a new ticket!

`git start feature-2`

More urgent ticket? Work on that!

`git start bug-1`
Do your work...
`git publish`

Go back to feature-1
`git start feature-1`

Go back to feature-2
`git start feature-2`

Publish them
`git publish feature-1`
`git publish feature-2`




