# GitMini: Less git, more productivity.

<img src="https://i.imgur.com/g9YTtMF.png" alt="git meme" width="300px" height="auto">

GitMini is a powerful tool that simplify the way you use Git.
It revolves around the concept of tickets, which are commonly used to organize and track work progress in Software Development.

GitMini doesn't replace Git; it enhances it by automating repetitive tasks, allowing you to focus on what truly matters: writing code.
It provides a simple set of commands that are intuitive also for people new to Version Control.

No more: "Hint: You have divergent branches and need to specify how to reconcile them."

No more: "CONFLICT (content): Merge conflict in <file>
Automatic merge failed; fix conflicts and then commit the result."
Just a simple and intuitive interface


<img src="https://i.imgur.com/vTsgtog.png" alt="git meme" width="600px" height="auto">

## Usage

The main command in GitMini is `git publish`, which simplifies the process of publishing code changes. Use it after working on the repo like this:

```bash
git publish "Ticket name/number"
```

When executed, the git publish command automates the following actions:

- Safely updates your local repository while keeping your changes
- Prompts you to resolve any possible conflicts before going on.
- Creates a branch using specified ticket name `git checkout -B "Ticket name/number"`
- Add all files to staging, do a commit
- Bring your changes to the master branch

Soon, an option to create a merge request instead of directly pushing to the master branch will be added.

The idea is to create `git review which will make the ticket reviewable by other team members before publishing.

```bash
git unpublish "Ticket name/number"
```

When executed, the git unpublish command automates the following actions:

- Safely refresh your local repository while keeping your changes
- Prompts you to resolve any conflicts before going on.
- Reverts the commit on master of the ticket you want to unpublish
- Commits the changes `git commit -m "revert of {ticket-name}"`
- Pushes your changes to repository's server so other people can get your revert `git push`

This will not delete the branch of your ticket, in order to remove it completely see git delete
Ticket name is optional but must be unique if used. If you use `git publish` default ticket name will be "WIP-{timestamp}".
This will make GitMini even simpler but consider that it is strongly recommended to give meaningfuls names to every code publish.
GitMini works also offline, you don't need to set remote orgin, it will work by creating normal commits and branches in the background.

### Optional Commands

```bash
git start "Ticket name/number"
```

The git start command starts or resumes work done in a ticket. It performs the following actions:

- Initialize the repository if not yet done with `git init`
- Ask you for name or email if not set or use global ones if already set
- Retrieves updates from remote origin to ensure you are working on an up-to-date codebase using `git refresh`
- Prompts you to resolve any possible conflicts.
- Create a branch named as your ticket (name defaults to "WIP {timestamp}" when no specified)

```bash
git rename "old_ticket_name/number" "new_ticket_name/number"
```

Rename a ticket, its branch, and commits from the old ticket name to the new ticket name. Useful for updating ticket names to better reflect content or for other reasons. Please communicate changes with the team to avoid confusion. If you use it with only one paramerter it will rename the current ticket to the provided one.

```bash
git combine <ticket_name_1> <ticket_name_2> ...
```

The git combine command allows you to combine multiple ticket branches into one branch. This is useful when you have work spread over multiples ticket by accident or when you completed work on several related tickets and want to merge them into a single ticket before publishing.

```bash
git list
```

The git list command lists all the tickets that have been opened until now. It provides a way to quickly view the tickets you have worked on or are currently working on (the one marked with \*).

```bash
git current
```

Returns the name of the current ticket you're working on, in case your forgot. Makes sense only if you use git start.

```bash
git update "Message to team members"
```

The git update command allows you to update team members with your work, even if it is not yet finished. It bring the changes to the master and pushes to the remote repository so other team members can start receiving your progress.
It is useful when doing important changes that we want other members to get without finishing our ticket

It works only on current ticket and accepts an update message as parameter (defaults to ticket name)

```bash
git delete "Ticket name/number"
```

The git delete command deletes the specified ticket. This will remove the ticket branch and its associated commits from your local repository. Note that this action cannot be undone, so use it with caution.
To completely delete the work done on this ticket you have to run git unpublish "ticket name" as well.

```bash
git refresh
```

Refresh your code with latest updates from server while keeping your work undisturbed.
It is used internally everytime we start or publish a ticket. It automates the following tasks:

- Temporary saves any changes you have going by committing them
- Brings any new update from server
- Prompts you to fix any possible conflicts

In the future it will be possible to run refresh every n seconds to be always updated and receive conflicts as soon as possible.

```bash
git pause
```

Pause your current work and see the code as it was without your changes (resume it with git start "ticket name")

```bash
gitmini help
```

Shows all the commands with descriptions

## Install:

Requirements: Git must be installed

1. Open a terminal and run the following command:

```bash
npm install gitmini -g
```
or if needed 

```bash
sudo npm install gitmini -g
```
or download and launch gitmini.sh in the terminal (do not delete it after installed)

That's it! You can now use the new commands in your repositories.
And you can also use them with only 2 letters: `gitmini` or `gm`.

## Examples:

### Minimal Approach

1. Make edits to files in the repository
2. Publish your changes with a default ticket name:

```bash
git publish
```

3. Something went wrong? Revert your last publish

```bash
git unpublish
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

## Contributions

Contributions to GitMini are welcome! If you have any suggestions, bug reports, or feature requests, please create an issue or submit a pull request.

## License

This project is licensed under the MIT License.
