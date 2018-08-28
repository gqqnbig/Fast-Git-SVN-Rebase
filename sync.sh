git config --local gc.auto 0

git checkout trunk
git pull origin trunk
git checkout master
git pull --ff-only origin master
if [ $? -ne 0 ]; then
	>&2 echo -e "\e[31mBranch master diverges from origin/master. Please fix manully.\e[0m"
	>&2 echo -e "\e[31mYou may want to reset master to orgin/master.\e[0m"
	exit 4
fi

if [ "$(git rev-list -1 trunk)" != "$(git rev-list -1 git-svn)" ]; then
	>&2 echo -e "\e[93mtrunk doesn't align with git-svn!\e[0m"

	if git merge-base --is-ancestor git-svn trunk; then
		echo "git-svn is ancestor of trunk. Reset to git-svn."
		# current branch is master, so I can directly move the pointer of trunk.
		git branch -f trunk git-svn || exit 1
		git push --force-with-lease origin trunk || exit 1
	else
		>&2 echo "git-svn is not ancestor of trunk."
		exit 1
	fi
fi

git svn rebase || exit 1
git svn dcommit --add-author-from || exit 1

git checkout trunk

git merge master

git checkout master

git push --force-with-lease=master  origin master trunk
if [ $? -ne 0 ]; then
	>&2 echo "Do you have the rewind permission on $(git remote get-url origin)?"
	exit 2
fi

git gc --auto
