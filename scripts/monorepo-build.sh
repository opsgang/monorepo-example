#!/usr/bin/env bash
# vim: et sr sw=2 ts=2 smartindent:

##
# This file orchestrates the mono repo build process
##

set -e
. ../.env

docker_build_runner() {
  local command=$@
  docker run --rm -v "$HOME/.npm:/home/node/.npm" -v  --user=$UID:$GID "$(pwd):/code" -w /code $DOCKER_NODE_IMAGE_TAG "$command"
}

# Create the Docker config file if it doesn't exist, otherwise Docker will create it as a directory.
touch ~/.docker/config.json

# Get the packages that have changed and save them for use later when building and triggering builds
changed_packages=$(echo "{$(docker_build_runner lerna changed --json --loglevel=silent | jq -c -r 'map(.name) | join(",")'),}")

echo "DEBUG changed_packages"
echo ${changed_packages}

if [ ${changed_packages} = "{,}" ] || [ ${changed_packages} = "{}" ] || [ ${changed_packages} = {} ]
then
  echo "No packages were changed, nothing to build…"
  exit 0
fi

# Bump all the versions in the monorepo for omega build, handles master and PR builds...at the moment we are doing this before we mount the files into the build container.
if [ "${GIT_BRANCH}" = "${MASTER_BRANCH}" ]
then
  echo ">>> Master version bump"
  git reset origin/${GIT_BRANCH} --hard

  git config user.email "${GIT_BOT_EMAIL}"
  git config user.name "${GIT_BOT_USERNAME}"
  git config --global push.default simple
  docker_build_runner npm run version:master
else
  echo ">>> Non-master version bump"
  docker_build_runner npm run version:pr
fi

if [ "${GIT_BRANCH}" = "${MASTER_BRANCH}" ]
then
  echo ">>> Master git publish"
  GIT_URL=$(echo ${GIT_URL} | sed -e 's/^https:\/\///g')
  git push https://${GITHUB_USER}:${GITHUB_PASS}@${GIT_URL}
  git push https://${GITHUB_USER}:${GITHUB_PASS}@${GIT_URL} --tags
else
  echo ">>> Non-master git push"
  echo "PR build changes, e.g. CHANGELOG.md are not pushed to origin."
fi

# Build and publish the packages that have changed...at the moment these use a build command that needs to be in each packages package.json.
docker run --rm \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    --mount type=bind,source=$(which docker),target=$(which docker) \
    -v "${HOME}/.docker/config.json:/root/.docker/config.json" \
    -v "${HOME}/.npm:/root/.npm" \
    -v "$(pwd):/code" \
    -w "/code" \
    -e BUILD_NUMBER=${BUILD_NUMBER} \
    -e GIT_BRANCH=${GIT_BRANCH} \
    -e MASTER_BRANCH=${MASTER_BRANCH} \
    $DOCKER_NODE_IMAGE_TAG \
    /bin/bash -c \
    "export NODE_ENV=development && npm install && npm run bootstrap && \
    lerna run --scope=${changed_packages} --include-filtered-dependencies publish && \
    lerna run --scope=${changed_packages} --include-filtered-dependencies deploy"
