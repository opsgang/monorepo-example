#!/usr/bin/env bash
# vim: et sr sw=2 ts=2 smartindent:

set -x
. ../../scripts/monorepo-nodejs-lib.sh

setenv() {
  if [ "${GIT_BRANCH}" = "${MASTER_BRANCH}" ]
  then
    export DOCKER_CONTAINER_REGISTRY=${DOCKER_CONTAINER_REGISTRY:-"940731442544.dkr.ecr.eu-west-1.amazonaws.com/monorepo-example-go"}
  else
    export DOCKER_CONTAINER_REGISTRY==${DOCKER_CONTAINER_REGISTRY:-"940731442544.dkr.ecr.eu-west-1.amazonaws.com/monorepo-example-pr"}
  fi
}



##
# Updates the dependencies' version numbers.
#
# Lerna bumps the main version, but does not touch the dependencies.
##
update_version() {
  local node_example_version_tag=$1
  local node_example_component_version_tag=$2

  node -e "const f = './package.json'; const packageJson = require(f); const fs = require('fs'); \
  fs.writeFileSync(f, JSON.stringify({ \
    ...packageJson, \
    version: '${node_example_version_tag}', \
    dependencies: { \
      ...packageJson.dependencies, \
      '${COMPANY_PACKAGE_PREFIX}/monorepo-node-example-component': '${node_example_component_version_tag}', \
    }, \
  }, null, 2));"
}

##
# Installs local dependencies, such as Component Library.
##
install_local_dependencies() {
  component_version_tag=$1

  local atless_company_package_prefix=$(echo ${COMPANY_PACKAGE_PREFIX} | sed -e 's/^@\/\///')
  create_npmrc

  # Try if the package is available on the local filesystem.
  component_npm_file="../monorepo-example-node-component/${COMPANY_PACKAGE_PREFIX}-monorepo-example-node-component-$component_version_tag.tgz"
  if [ -f $component_npm_file ]; then
    npm install $component_npm_file
  else
    # The file is locally not available, so it is assumed
    # it has been built and pushed to the repository.
    npm install ${COMPANY_PACKAGE_PREFIX}/nuk-component-library@$component_library_version_tag
  fi
}

build() {
  export COMPONENT_LIBRARY_VERSION_TAG=$(jq -r ".version" ../nuk-ge-sun-web-component-library/package.json)

  if [ "${GIT_BRANCH}" = "${MASTER_BRANCH}" ]
  then
    export HELIOS_VERSION_TAG=$(jq -r ".version" ./package.json)
    export HELIOS_DOCKER_TAG=${ecr_repo}:${HELIOS_VERSION_TAG}
    echo ">>> Master build ${HELIOS_VERSION_TAG}"
  else
    current_helios_tag=$(jq -r ".version" ./package.json)
    if [ "$current_helios_tag" == *"${GIT_BRANCH}"* ]; then
      export HELIOS_VERSION_TAG=$current_helios_tag
    else
      export HELIOS_VERSION_TAG="$current_helios_tag-${GIT_BRANCH}"
    fi

    export HELIOS_DOCKER_TAG=${ecr_repo}:${GIT_BRANCH}

    echo ">>> Non-master build ${HELIOS_VERSION_TAG}"
    update_version $HELIOS_VERSION_TAG $COMPONENT_LIBRARY_VERSION_TAG
  fi

  install_local_dependencies $COMPONENT_LIBRARY_VERSION_TAG

  eval $(aws ecr get-login --no-include-email --region ${ECR_REGION})
  export HELIOS_HISTORIC_IMAGE_VERSION=$(aws ecr list-images --region ${ECR_REGION} --registry-id 940731442544 --repository-name nu-sun-helios | jq -r '.imageIds | .[] | .imageTag | select(. != null)' | sort -r | head -n 1)

  docker build \
    --rm \
    --build-arg HELIOS_HISTORIC_IMAGE_VERSION=${HELIOS_HISTORIC_IMAGE_VERSION} \
    --build-arg COMPONENT_LIBRARY_VERSION_TAG=${COMPONENT_LIBRARY_VERSION_TAG} \
    --build-arg GIT_BRANCH=${GIT_BRANCH} \
    --build-arg MASTER_BRANCH=${MASTER_BRANCH} \
    -t ${HELIOS_DOCKER_TAG} \
    -f monorepo-example-node.dockerfile \
    .
  docker push ${HELIOS_DOCKER_TAG}
}

(
  setenv
  build
)
