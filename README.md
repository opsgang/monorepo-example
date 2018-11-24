# Monorepo example

This repository demonstrates a monorepo build-publish pipeline with
projects in different languages and dependencies.

## Usage

- Each `package.json` has to have `publish` and `deploy`.

- Because `build` is traditionally used just to build a project
and not necessary make it available for external use, hence
the `publish`. This stage should take care of making available
artefacts to other packages, such as pushing Docker images
to the container registry, pushing Lambda functions to S3,
etc.

- Lerna supports a technique called _hoisting_.  This means
it symlinks node modules directories into each the package,
reducing the waste of space.  Altough this is a good idea
for local development, it makes building packages in a
container. (During the `docker build` it is not possible to
`COPY` artefacts into the container outside the build
directory.)
 

## Notes

- `$HOME/.npm` is mounted, because it is a cache directory
for NPM.  _At the moment the containers inside the main
build container requires root privileges, because it is not
sure whether all the containers' build user has a regular
user that has the same user id and is a member of the `docker`
user group._

- The `node_modules` in the root of the monorepo contains all the
dependencies of every package, so be mindful when you introduce
a new dependency.

- If you use a different language other than Node.js, then
you need to explicitly manage your dependencies for that
specific package.

- If a dependency package is not a Node.js package but it is
in the monorepo, you should still create a package.json in the
package's root directory and refer to it from the dependants,
so Lerna will know this and triggers the builds and manages
the version numbers accordingly.

## TODO

- Introduce opsgang/lib for checking required variables
