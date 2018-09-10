# `git svn info` may hang up, so I have to use grep.
grep svn-remote .git/config >/dev/null
if [ $? -ne 0 ]; then
	>&2 echo -e "\e[31mThis is not a git-svn repository. You have to run \`git svn init ...\`.\e[0m"
	exit 5
fi

git config --local gc.auto 0

# The output of whoami may prefix with domain name.
# The EndsWith syntax is found at http://tldp.org/LDP/abs/html/comparison-ops.html
if [[ "$(whoami)" != *git2svn ]]; then
	>&2 echo -e "\e[93mThe current user is not git2svn, all commits from Git will be committed as $(whoami) to SVN!\e[0m"
	# https://www.gnu.org/software/bash/manual/html_node/ANSI_002dC-Quoting.html
	# Words of the form $'string' are treated specially. The word expands to string, with backslash-escaped characters replaced as specified by the ANSI C standard. Backslash escape sequences, if present, are decoded as follows...
	read -p $'I will continue in 5 seconds or you press any key to continue immediately.\n' -t 5 -n 1 -s
fi

# update trunk 
git checkout trunk
git pull origin trunk

# update master 
git checkout master
git pull --ff-only origin master

if [ $? -ne 0 ]; then
	>&2 echo -e "\e[31mBranch master diverges from origin/master. Please fix manully.\e[0m"
	>&2 echo -e "\e[31mYou may want to reset master to orgin/master.\e[0m"
	read -n 1 -s -r -p "Press any key to continue"
	exit 4
fi

#sanity check to make sure trunk aligns with git-svn label 
if [ "$(git rev-list -1 trunk)" != "$(git rev-list -1 git-svn)" ]; then
	>&2 echo -e "\e[93mtrunk doesn't align with git-svn!\e[0m"

	if git merge-base --is-ancestor git-svn trunk; then
		echo "git-svn is behind of trunk. Reset trunk to git-svn."
		# current branch is master, so I can directly move the pointer of trunk.
		git branch -f trunk git-svn || exit 1
		git push --force-with-lease origin trunk || exit 1
	elif git merge-base --is-ancestor trunk git-svn; then
		echo "git-svn is ahead of trunk. Reset trunk to git-svn."
		# current branch is master, so I can directly move the pointer of trunk.
		git branch -f trunk git-svn || exit 1
		git push --force-with-lease origin trunk || exit 1
	else
		>&2 echo "git-svn is not ancestor of trunk."
		read -n 1 -s -r -p "Press any key to continue"
		exit 1
	fi
fi

# pull changes from SVN to GIT
git svn rebase --use-log-author
if [ $? -ne 0 ]; then
	read -n 1 -s -r -p $'\e[31mSee above error.\e[0m Press any key to continue'
	exit 3
fi

# push changes from git to svn
git svn dcommit --add-author-from --use-log-author 
if [ $? -ne 0 ]; then
	read -n 1 -s -r -p $'\e[31mSee above error.\e[0m Press any key to continue'
	exit 4
fi

# align trunk to master (fast forward) 
git checkout trunk
git merge master

# push trunk and master back to origin;  the force with lease is to handle 
# the new svn metadata (from synching hash of svn revision) and force git to take change
git checkout master
git push --force-with-lease=master  origin master trunk

# error checkin
if [ $? -ne 0 ]; then
	>&2 echo "Do you have the rewind permission on $(git remote get-url origin)?"
	read -n 1 -s -r -p "Press any key to continue"
	exit 2
fi

git gc --auto
