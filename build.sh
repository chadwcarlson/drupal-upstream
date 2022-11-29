#!/usr/bin/env bash

########################################################################################################################
# 
# Building a Drupal 8 template from scratch.
#
########################################################################################################################
# Variables

UPSTREAM_TAG=8.9.20

UPSTREAM_REPO="https://github.com/drupal/recommended-project.git"

UPDATE_BRANCH="platformify"
UPDATE_TMP_DIR="stage"

TEMPLATE_REPO="https://github.com/platformsh-templates/drupal8.git"
TEMPLATE_DEFAULT_BRANCH="main"

DEFAULT_INSTALL_DEST=".platform/optional"

GENERATE_SCRIPT_DEST=".platform/files"
DIFF_FILENAME="$GENERATE_SCRIPT_DEST/recipe.platformify.diff"
GENERATE_DIR="my-project"
GENERATE_DEFAULT_BRANCH="main"
GENERATE_SCRIPT="$GENERATE_SCRIPT_DEST/recipe.generate"
GENERATE_TEST_SCRIPT="$GENERATE_SCRIPT_DEST/test.generate"
PLATFORMIFY_TEST_SCRIPT="$GENERATE_SCRIPT_DEST/test.platformify"
########################################################################################################################
# Setup from the upstream.

mkdir build
cd build

# Upstream.
git init
git remote add project $UPSTREAM_REPO
git fetch --all --depth=2
git fetch --all --tags
git pull project $UPSTREAM_TAG
########################################################################################################################
# Making Platformify changes.

git checkout -b $UPDATE_BRANCH

# Files - creating a usable platformify.diff file.
git clone $TEMPLATE_REPO $UPDATE_TMP_DIR

# 1. Required.
# TODO: config generation?
mkdir -p .platform && cp $UPDATE_TMP_DIR/.platform/routes.yaml .platform/routes.yaml
mkdir -p .platform && cp $UPDATE_TMP_DIR/.platform/services.yaml .platform/services.yaml

# cp $UPDATE_TMP_DIR/.platform.app.yaml .platform.app.yaml
cp ../.platform.app.yaml .platform.app.yaml

# TODO: check for existing, then append existing settings.php file.
mkdir -p web/sites/default && cp $UPDATE_TMP_DIR/web/sites/default/settings.php web/sites/default/settings.php
mkdir -p web/sites/default && cp $UPDATE_TMP_DIR/web/sites/default/settings.platformsh.php web/sites/default/settings.platformsh.php
# TODO: common .environment definition with overrides for a particular template? I.e. service credentials, etc.
cp $UPDATE_TMP_DIR/.environment .environment
mkdir -p drush && cp $UPDATE_TMP_DIR/drush/platformsh_generate_drush_yml.php drush/platformsh_generate_drush_yml.php

# 2. Optional files, placed in a default directory for the purpose of platformify.diff generation.
mkdir $DEFAULT_INSTALL_DEST
mkdir -p $DEFAULT_INSTALL_DEST/config/sync && cp $UPDATE_TMP_DIR/config/sync/.gitkeep $DEFAULT_INSTALL_DEST/config/sync/.gitkeep
cp $UPDATE_TMP_DIR/README.md $DEFAULT_INSTALL_DEST/README.md 
cp $UPDATE_TMP_DIR/.gitignore $DEFAULT_INSTALL_DEST/.gitignore
cp $UPDATE_TMP_DIR/.blackfire.yml $DEFAULT_INSTALL_DEST/.blackfire.yml

# Cleanup.
rm -rf $UPDATE_TMP_DIR

# Commit.
git add .
git commit -m "Commit Platformify files with default optional install destination."

# Create diff file.
mkdir $GENERATE_SCRIPT_DEST
git diff $UPSTREAM_TAG $UPDATE_BRANCH > $DIFF_FILENAME
git add $DIFF_FILENAME
git commit -m "Update platformify diff file."

# Return files to root for template generation.
cp -R $DEFAULT_INSTALL_DEST/. .
rm -rf $DEFAULT_INSTALL_DEST

# Composer.json changes
#   a) Allow plugins.
composer config -g allow-plugins.composer/installers true --no-plugins
composer config allow-plugins.composer/installers true --no-plugins
composer config allow-plugins.drupal/core-composer-scaffold true --no-plugins
composer config allow-plugins.drupal/console-extend-plugin true --no-plugins
composer config allow-plugins.drupal/core-project-message true --no-plugins
composer config allow-plugins.cweagans/composer-patches true --no-plugins
#   b) Dependencies.
composer install
composer require drupal/redis:^1.5 --prefer-dist --no-interaction
composer require drush/drush:^10.6 --prefer-dist --no-interaction
composer require platformsh/config-reader --prefer-dist --no-interaction

# Update.
composer update
########################################################################################################################
# Additional non-Platformify changes.

# Create-project enablement.
composer config name 'platformsh/drupal8'
composer config description 'This template builds Drupal 8 for Platform.sh based the Drupal Recommended Composer project.'

# Add a generate script, which acts as one test for platformify.
printf "########################################################################################################################

# Init.
mkdir $GENERATE_DIR && cd $GENERATE_DIR
git init

# Upstream.
git checkout -b $UPSTREAM_TAG
git remote add project $UPSTREAM_REPO
git fetch --all --depth=2
git fetch --all --tags
git pull project $UPSTREAM_TAG

# Mock user repo.
git branch -m $GENERATE_DEFAULT_BRANCH

########################################################################################################################
# Platformify steps.

# 0. Setup
git checkout -b $UPDATE_BRANCH

# 1. Composer changes. 
#   a) Allow plugins.
composer config -g allow-plugins.composer/installers true --no-plugins
composer config allow-plugins.composer/installers true --no-plugins
composer config allow-plugins.drupal/core-composer-scaffold true --no-plugins
composer config allow-plugins.drupal/console-extend-plugin true --no-plugins
composer config allow-plugins.drupal/core-project-message true --no-plugins
composer config allow-plugins.cweagans/composer-patches true --no-plugins

#   b) Dependencies. 
composer install
composer require drupal/redis:^1.5 --prefer-dist --no-interaction
composer require drush/drush:^10.6 --prefer-dist --no-interaction
composer require platformsh/config-reader --prefer-dist --no-interaction

# 2. Apply required file patches.
# git apply ../build/$DIFF_FILENAME --ignore-whitespace --quiet
curl -fs https://raw.githubusercontent.com/chadwcarlson/drupal-upstream/$TEMPLATE_DEFAULT_BRANCH/$DIFF_FILENAME | git apply --ignore-whitespace --quiet

# 3. Move optional files back to root during full template generation.
cp -R $DEFAULT_INSTALL_DEST/. .
rm -rf $DEFAULT_INSTALL_DEST

# Commit changes.
git add .
git commit -m 'Initialize template.'

# Merge the revisions.
git checkout $GENERATE_DEFAULT_BRANCH
git merge $UPDATE_BRANCH
" > $GENERATE_SCRIPT
chmod +x $GENERATE_SCRIPT

# Add a generate test.
printf "curl -fs https://raw.githubusercontent.com/chadwcarlson/drupal-upstream/$TEMPLATE_DEFAULT_BRANCH/$GENERATE_SCRIPT | bash
" > $GENERATE_TEST_SCRIPT
chmod +x $GENERATE_TEST_SCRIPT

# Add a Platformify test script
printf "########################################################################################################################
# Example project.

# Init a starting project for testing.
composer create-project drupal/recommended-project:^$UPSTREAM_TAG $GENERATE_DIR --no-install

# Git.
cd $GENERATE_DIR
git init
git branch -m $GENERATE_DEFAULT_BRANCH
git add .
git commit -m 'Sample init project.' 
git checkout -b $UPDATE_BRANCH
########################################################################################################################
# Platformify steps.

# 1. Required files.
curl -fs https://raw.githubusercontent.com/chadwcarlson/drupal-upstream/$TEMPLATE_DEFAULT_BRANCH/$DIFF_FILENAME | git apply --ignore-whitespace --quiet

# 2. Composer changes. 
#   a) Allow plugins.
composer config -g allow-plugins.composer/installers true --no-plugins
composer config allow-plugins.composer/installers true --no-plugins
composer config allow-plugins.drupal/core-composer-scaffold true --no-plugins
composer config allow-plugins.drupal/console-extend-plugin true --no-plugins
composer config allow-plugins.drupal/core-project-message true --no-plugins
composer config allow-plugins.cweagans/composer-patches true --no-plugins

#   b) Dependencies. 
composer install
composer require drupal/redis:^1.5 --prefer-dist --no-interaction
composer require drush/drush:^10.6 --prefer-dist --no-interaction
composer require platformsh/config-reader --prefer-dist --no-interaction
" > $PLATFORMIFY_TEST_SCRIPT
chmod +x $PLATFORMIFY_TEST_SCRIPT

# Track changes.
echo $(date) > .updated_on
echo $UPSTREAM_TAG > .upstream_version

# Commit all changes.
git add .
git commit -m "Scheduled updates."


########################################################################################################################
# For now, push to https://github.com/chadwcarlson/drupal-upstream so we can test.
TEST_REPO_DEFAULT_BRANCH="main"
TEST_REPO_GIT="https://github.com/chadwcarlson/drupal-upstream.git"

cp ../build.sh .
echo $(php --version) > built_with.txt

git add .
git commit -m "Copy generating build script."


git checkout $TEST_REPO_DEFAULT_BRANCH
git merge $UPDATE_BRANCH
git remote add origin $TEST_REPO_GIT
git push origin $TEST_REPO_DEFAULT_BRANCH -f
