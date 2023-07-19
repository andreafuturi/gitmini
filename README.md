# GitMini: Less git, more productivity.

<img src="https://i.imgur.com/g9YTtMF.png" alt="git meme" width="300px" height="auto">

GitMini is a powerful tool that simplify the way you use Git.
It revolves around the concept of tickets, which are commonly used to organize and track work progress in Software Development.

GitMini doesn't replace Git; it enhances it by automating repetitive tasks, allowing you to focus on what truly matters: writing code.

## Usage

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

Requirements: Git must be installed

1. Open a terminal or command prompt.
2. Run the following command to install GitMini:

```bash
npm install gitmini -g
```

That's it! You can now use the new commands in your repositories.
And you can also use them with only 2 letters: `gm` which stands for GitMini.

## Examples:

### Minimal Approach

1. Make edits to files in the repository
2. Publish your changes with a default ticket name:

```bash
gm publish
```

3. Something went wrong? Revert your last publish

```bash
gm unpublish
```

### Normal Approach

1. Start a new ticket

```bash
git start "work on the new login page"
```

2. Make edits to files in the repository and than publish them with

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
