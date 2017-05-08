#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

SOURCE_BRANCH="master"
TARGET_BRANCH="master"

function doCompile {
  make clean
  make test
}

# Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if [ "$TRAVIS_PULL_REQUEST" != "false" -o "$TRAVIS_BRANCH" != "$SOURCE_BRANCH" ]; then
    echo "Skipping deploy; just doing a build."
    doCompile
    exit 0
fi

# Save some useful information
REPO=`git config remote.origin.url`
SSH_REPO=${REPO/https:\/\/github.com\//git@github.com:}
SHA=`git rev-parse --verify HEAD`

# Clone the existing gh-pages for this repo into out/
# Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deply)
git clone $REPO out
cd out
git checkout $TARGET_BRANCH || git checkout --orphan $TARGET_BRANCH
git submodule init
git submodule update

# Run our compile script
doCompile

# Now let's go have some fun with the cloned repo
git config user.name "Travis CI"
git config user.email "$COMMIT_AUTHOR_EMAIL"

# don't fail here
set +e
# Check if there's anything to commit
git add -A -f *.exchange
git diff --exit-code >/dev/null
diff_code=$?
git diff --cached --exit-code >/dev/null
diff_cached_code=$?
if [ ${diff_code} -ne 0 ] || [ ${diff_cached_code} -ne 0 ]; then
    set -e
    git commit -m "Automated push of blueprint exchange strings: ${SHA}"

    # Get the deploy key by using Travis's stored variables to decrypt travis_deploy.enc
    ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
    ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
    ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
    ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
    openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in ../travis_deploy.enc -out ../deploy_key -d
    chmod 600 ../deploy_key
    eval `ssh-agent -s`
    ssh-add ../deploy_key

    # Now that we're all set up, we can push.
    git push $SSH_REPO $TARGET_BRANCH
fi
