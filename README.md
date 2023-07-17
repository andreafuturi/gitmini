# GitMini: Less git, more work done.

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
  - Safely updates your local repository with `git update`
  - Prompts you to resolve any conflicts before going on, if present.
  - Adds all changes to the staging area using `git add .`
  - Commits the changes using specified ticket name (defaults to WIP-{timestamp}) `git commit -m WIP-{timestamp}`
  - Pushes your changes to repository's server so other people can get your changes with `git push`

(Soon, an option to create a merge request instead of directly pushing to the master branch will be added.)

```bash
git unpublish "Ticket name/number"
```
When executed, the git unpublish command automates the following actions:
- Safely updates your local repository with `git update`
- Prompts you to resolve any conflicts before going on, if present.
- Reverts the commit of the ticket you want to unpublish
- Asks you to fix conflicts if they're present
- Adds all changes to the staging area using `git add .`
- Commits the changes using specified ticket name (defaults to current ticket) `git commit -m "revert of WIP-{timestamp}"`
- Pushes your changes to repository's server so other people can get your revert `git push`

Git unpublish is still under work
  
### Optional Commands

```bash
git start "Ticket name/number"
```



The git start command begins work on a new ticket. It performs the following actions:
  - Initialize the repository if not yet done with `git init`
  - Retrieves updates from remote origin to ensure you are working on an up-to-date codebase using `git update`
  - Prompts you to resolve any conflicts, if present.
  - Prepare name of ticket as commit message when publishing with git publish (usefult for a future jira integration, name defaults to "WIP {timestamp}" when no specified)

In case you forgot doing it, you can start working on a ticket after you edited some files. They will published when you git publish

```bash
git update
```


In the future it will be possible to run update every n seconds to be always updated and receive conflicts as soon as possible.
Right now git update is used internally everytime we start or publish a ticket. It automates the following tasks:
  - Temporary saves any changes you have going on with `git stash`
  - gets an update from master so you work on up-to-date codebase with `git pull`
  - Prompts you to fix conflicts, if present
  - Installs any package recently added to repositiory with `npm install` (this is only web devs, should be optional or in another complementar tool)
  - Applies your changes again `git stash pop`


```bash
git current
```
Returns the name of the current ticket you're working on, in case your forgot.


## Install: 
1. Open a terminal or command prompt.
2. Run the following command to install the package:
`npm install gitmini -g`
That's it! You have added the aliases to your Git configuration. You can now use these aliases in your Git commands.
And you can also use them with only 2 letters: gm publish, gm unpusblish

## Examples: 


### Minimal Approach
Edit files in repository and then
```bash
gm publish
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




