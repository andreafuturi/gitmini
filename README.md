# GitMini: Less git, more work done.


<img src="https://i.imgur.com/g9YTtMF.png" alt="git meme" width="300px" height="auto">

GitMini is a minimal collection of intuitive git aliases that make developers' workflow much easier.
Its main purpose is to automate different tasks in Git, allowing developers to focus on coding rather than managing their repositories. GitMini doesn't replace Git or remove any of its functionalities; it just provides a simplified way to interact with it. 

It works independently of branches, meaning you can use it in any branch, although it is primarily tested and intended for use on the master branch.

GitMini revolves around the concept of Tickets, which are commonly used to organize and track work progress in Software Development.



## Usage

The commands in GitMini are intuitively named, even for users unfamiliar with Git or version control in general.

The main command in GitMini is `git publish`, which simplifies the process of publishing code changes. Use it after working on the repo like this:

```bash
git publish "Ticket name/number"
```

When executed, the git publish command automates the following actions:
  - Safely updates your local repository
  - Prompts you to resolve any conflicts before going on, if present.
  - Adds all changes to the staging area using `git add .`
  - Commits the changes using specified ticket name `git commit -m "Ticket name/number"`
  - Pushes your changes to repository's server so other people can get your changes with `git push`

(Soon, an option to create a merge request instead of directly pushing to the master branch will be added.)



```bash
git unpublish "Ticket name/number"
```
When executed, the git unpublish command automates the following actions:
- Safely refresh your local repository
- Prompts you to resolve any conflicts before going on, if present.
- Reverts the commit of the ticket you want to unpublish
- Asks you to fix conflicts if they're present
- Adds all changes to the staging area using `git add .`
- Commits the changes using specified ticket name (defaults to current ticket) `git commit -m "revert of {last-ticket-name}"`
- Pushes your changes to repository's server so other people can get your revert `git push`

Ticket name is optional but must be unique if used. If you use `git publish` default ticket name will be "WIP-{timestamp}".
This will make GitMini even simpler but consider that it is strongly recommended to give meaningfuls names to every code publish.
GitMini works also offline you don't need to set remote orgin, it will work with normal commits in the background.
  
### Optional Commands

```bash
git start "Ticket name/number"
```



The git start command begins work on a new ticket. It performs the following actions:
  - Initialize the repository if not yet done with `git init`
  - Retrieves updates from remote origin to ensure you are working on an up-to-date codebase using `git refresh`
  - Prompts you to resolve any conflicts, if present.
  - Prepare name of ticket as commit message when publishing with git publish (usefult for a future jira integration, name defaults to "WIP {timestamp}" when no specified)

```bash
git refresh
```

Refresh your code with latest updates from server while keeping your work undisturbed.
It is used internally everytime we start or publish a ticket. It automates the following tasks:
  - Temporary saves any changes you have going on with `git stash`
  - gets an update from server with `git pull`
  - Prompts you to fix conflicts, if present
  - Applies your changes again `git stash pop`

In the future it will be possible to run refresh every n seconds to be always updated and receive conflicts as soon as possible.

```bash
git pause
```
Pause your current work and see the code as it was without your changes (resume it with git start "ticket name")

```bash
git current
```
Returns the name of the current ticket you're working on, in case your forgot. Makes sense only if you use git start.


## Install: 

Requirements: git must be installed

1. Open a terminal or command prompt.
2. Run the following command to install the package:
```bash
npm install gitmini -g
```
That's it! You have added the aliases to your Git configuration. You can now use these commands in your repositories.
And you can also use them with only 2 letters: `gm` which of corse stands for GitMini.

## Examples: 


### Minimal Approach
Edit files in repository and then
```bash
gm publish
```

Something went wrong? Revert any ticket at any moment with

```bash
gm unpublish "Ticket name/number"
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
git publish feature-1
git publish feature-2
```


