git checkout master
git pull origin master

git checkout unsync

git svn dcommit

git checkout master

git merge unsync

git checkout unsync

git push --force-with-lease=unsync  origin master unsync
