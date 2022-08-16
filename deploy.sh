#!/bin/bash
set -euo pipefail

opwd="$PWD"
zola build
git worktree add /tmp/lemondeploy gh-pages
cd /tmp/lemondeploy
git checkout --orphan tmp-gh-pages
rm -rf *
mv "$opwd"/public/* .
git add -A
git commit -m "deploy github pages"
git branch -D gh-pages
git branch -m gh-pages
git push -f origin gh-pages
cd $opwd
git worktree remove /tmp/lemondeploy
git push origin master
