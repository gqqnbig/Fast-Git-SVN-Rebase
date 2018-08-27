git config --local gc.auto 0

git checkout trunk
git pull origin trunk
git checkout master
git pull origin master

if [ "$(git rev-list -1 trunk)" != "$(git rev-list -1 git-svn)" ]; then
	>&2 echo "trunk doesn't align with git-svn!"
	exit 1
fi

git svn rebase
git svn dcommit --add-author-from

git checkout trunk

git merge master

git checkout master

git push --force-with-lease=master  origin master trunk
if [ $? -ne 0 ]; then
	>&2 echo "Do you have the rewind permission on $(git remote get-url origin)?"
	exit 2
fi

git gc --auto
