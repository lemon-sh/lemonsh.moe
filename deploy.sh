#!/bin/bash
set -euo pipefail

gx() {
    echo -e "\033[0;32m* \033[0;36m$@\033[0m"
}

gx building website...
opwd="$PWD"
zola build

gx checking out \'gh-pages\' branch to /tmp...
rm -rf /tmp/lemondeploy
git worktree add /tmp/lemondeploy gh-pages

gx copying website to \'gh-pages\' branch...
cd /tmp/lemondeploy
rm -rf *
mv "$opwd/public/*" .

gx pushing \'gh-pages\'...
git add .
git commit -m "deploy $(date '+%Y%M%d %H%M%S')"
git push origin gh-pages

gx removing local \'gh-pages\' copy...
cd $opwd
git worktree remove /tmp/lemondeploy

gx done!