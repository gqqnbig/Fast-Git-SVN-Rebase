git checkout trunk
git pull origin trunk master

if [ "$(git rev-list -1 trunk)" != "$(git rev-list -1 git-svn)" ]; then
	>&2 echo "trunk doesn't align with git-svn!"
	exit
fi

git checkout master

git svn dcommit --add-author-from

git checkout trunk

git merge master

git checkout master

git push --force-with-lease=master  origin master trunk
