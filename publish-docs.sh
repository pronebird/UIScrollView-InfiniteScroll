#!/bin/sh

jazzy \
  --clean \
  --objc \
  --sdk iphoneos \
  --theme fullwidth \
  --author 'Andrei Mihailov' \
  --author_url http://codeispoetry.ru/ \
  --github_url https://github.com/pronebird/UIScrollView-InfiniteScroll \
  --github-file-prefix https://github.com/pronebird/UIScrollView-InfiniteScroll/tree/1.0.0 \
  --module-version 1.0.0 \
  --umbrella-header Classes/UIScrollView+InfiniteScroll.h \
  --framework-root Classes \
  --module UIScrollView_InfiniteScroll

git add docs && git commit -m "Update docs subtree commit"
git push origin `git subtree split --prefix docs master`:gh-pages --force
git reset --soft HEAD~1
git rm -rf docs
