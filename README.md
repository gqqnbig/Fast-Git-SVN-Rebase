# Git and SVN Two-way Synchronziation

## Setup
Clone LoansPQ2 Git repository. 

Create a local Windows account named git2svn. Make sure to log in to that account with user name `.\git2svn`. The accout must have this specific name because our SVN uses Windows authentication and Ben has set up an SVN account named git2svn on the SVN server. That the two names match allows SVN to show commit author correctly.

Copy `\\CYBERTRON\loanspq\git\authors.txt` to your local drive because the script runs under the git2svn local user account, and thus doesn't have access to CYBERTRON.

In the LoansPQ2 Git-SVN repository, set `svn.authorsfile` to the path of authors.txt.

Switch user to git2svn, do necessary Git configuration, and make sure you can manully run sync.ps1 there.

Switch user back to your regular user. Create a task in Windows Task Scheduler. In Security options, use your regular user account, and <u>Run only when user is logged on</u>. Only run the script on weekdays becauser we assume no developers will come to work at weekends.

![Task Scheduler General tab](/docs/Task%20Scheduler%20General.png)

The synchronziation script doesn't require user input and outputs warnings and errors in case something is wrong. As the script is experimental, I don't recommend to use option <u>Run whether user is logged on or not</u> because it prevents Windows from showing the script window even if the user is logged on<sup>[1]</sup>.

In Actions tab, run the PowerShell script, and pass the password of git2svn. The <u>Start in</u> should be the path of the target Git-SVN repository.

![Task Scheduler Actions tab](/docs/Task%20Scheduler%20Actions.png)

In Conditions tab, you may check Start only if the following network connection is available.

## Disaster Recovery

The synchronziation script will read and share Git-SVN linking metadata to `\\cybertron\loanspq\git\svn metadata\LoansPQ2-Git-SVN`. Do not do anything funny to this folder. 

The script will keep 10 backups of the linking metadata and delete old ones. In case the backups are messed up, `git svn rebase` will reconstruct the metadata but it usually takes 1 to 2 days.


## References
[1] Microsoft. Task Security Context. Task Scheduler Help.
