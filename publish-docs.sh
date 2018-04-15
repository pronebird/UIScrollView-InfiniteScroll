#!/bin/sh

jazzy --config .jazzy.yml

git add docs && git commit -m "Update docs subtree commit"
git push origin `git subtree split --prefix docs master`:gh-pages --force
git reset --soft HEAD~1
git rm -rf docs
