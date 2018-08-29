# Git and SVN Two-way Synchronziation

## Setup
Ask Qiqi to get a copy of LoansPQ2 Git-SVN repository. This repository has special linkings to the SVN repository, created by `git svn clone` command. An alternative way is to reconstruct Git-SVN linkings from the LoansPQ2 Git repository, which may take one or two days.

Create a local Windows account named git2svn. Make user to log in to that account using a user name like QIQIGWRK2\git2svn. The accout must have this specific name because our SVN uses Windows authentication and Ben has set up an SVN account named git2svn on the SVN server. That the two names match allows SVN to show commit author correctly.

Copy `\\CYBERTRON\loanspq\git\authors.txt` to your local drive because the script runs under the git2svn local user account, and thus doesn't have access to CYBERTRON.

In the LoansPQ2 Git-SVN repository, set `svn.authorsfile` to the path of authors.txt.

Switch user to git2svn, do necessary Git configuration, and make sure you can manully run sync.sh there.

Switch user back to your regular user. Create a task in Windows Task Scheduler. In Security options, use your regular user account, and <u>Run only when user is logged on</u>.

<img src="/raw/Tools/GitToSvn.git/master/docs!Task%20Scheduler%20General.png" alt="Task Scheduler General tab" width="80%"/>

The synchronziation script doesn't require user input and outputs warnings and errors in case something is wrong. As the script is experimental, I don't recommend to use option <u>Run whether user is logged on or not</u> because it prevents Windows from showing the script window even if the user is logged on<sup>[1]</sup>.

In Actions tab, run the PowerShell script, and pass the password of git2svn.

![Task Scheduler Actions tab](/docs/Task%20Scheduler%20Actions.png)

In Conditions tab, you may check Start only if the following network connection is available.


## References
[1] Microsoft. Task Security Context. Task Scheduler Help.
