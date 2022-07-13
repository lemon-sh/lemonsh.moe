#!/bin/bash
set -euo pipefail

gx() {
    echo -e "\033[0;32m* \033[0;36m$@\033[0m"
}

gx building website...
opwd="$PWD"
zola build

gx checking out \'gh-pages\' branch to /tmp...
git worktree add /tmp/lemondeploy gh-pages

gx copying website to \'gh-pages\' branch...
cd /tmp/lemondeploy
git checkout --orphan tmp-gh-pages
rm -rf *
mv "$opwd"/public/* .

gx pushing \'gh-pages\'...
git add -A
git commit -m "deploy github pages"
git branch -D gh-pages
git branch -m gh-pages
git push -f origin gh-pages

gx removing local \'gh-pages\' copy...
cd $opwd
git worktree remove /tmp/lemondeploy

gx pushing \'master\'...
git push origin master

gx done!