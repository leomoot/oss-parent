#!/usr/bin/env bash

set -e -u -o pipefail

#
# A script which checks out dependent projects and builds them against the
# current (installed) version of this project.
#
# XXX: This script currently makes a few assumptions. Consider generalizing
# further, so that this code can be employed more widely:
# - The `xmlstarlet` calls assume that the current project is a Maven parent
#   with a specific groupId and artifactId.
# - The script assumes that the parent project resides in the current directory
#   and has already been installed into the local Maven repository.
# - The list of dependent projects is hardcoded.
# - The script assumes that each dependent project has a unique name.
# - The script assumes that each dependent project can be build in exactly the
#   same way.
# - The script assumes that the Takari Maven Wrapper (`./mvnw`) has been
#   installed in the current working directory.
#

base_dir="${1:?Directory in which to clone dependents not specified}"

dependants='
  https://github.com/PicnicSupermarket/jolo.git
  https://github.com/PicnicSupermarket/reactive-support.git
'

# Reverts the Git repository located in the given directory to an "as new"
# state.
clean_project() {
  local project_dir="${1}"

  git -C "${project_dir}" clean -fdx
  git -C "${project_dir}" clean -fdX
  git -C "${project_dir}" checkout -- .
}

# Builds the Maven project in the given directory after updating its parent
# to the specified version.
build_project_with_parent_version() {
  local project_dir="${1}"
  local parent_version="${2}"

  xmlstarlet ed -L -P -N 'x=http://maven.apache.org/POM/4.0.0' \
    -u '//x:parent[
            x:groupId/text() = "tech.picnic" and
            x:artifactId/text() = "oss-parent"
        ]/x:version' \
    -v "${parent_version}" "${project_dir}/pom.xml"

  echo "Will build '${git_dir}' with the following modifications:"
  git -C "${project_dir}" diff

  ./mvnw -f "${project_dir}/pom.xml" clean install
}

# Determine the current parent version.
parent_version="$(
  xmlstarlet sel -T -N 'x=http://maven.apache.org/POM/4.0.0' \
    -t -m '/x:project' -v 'x:version' pom.xml
)"

# Build the latest version of each dependent project against the current parent
# version.
for git_url in $dependants; do
  last_path_segment="${git_url##*/}"
  git_dir="${base_dir}/${last_path_segment%%.git}"

  # Update the project if it has been cached prior; clone it otherwise.
  if [ -e "${git_dir}" ]; then
    clean_project "${git_dir}"
    git -C "${git_dir}" pull --rebase
  else 
    git -C "${base_dir}" clone --depth 1 "${git_url}"
  fi

  # Run the build.
  build_project_with_parent_version "${git_dir}" "${parent_version}"

  # Revert any modifications made. (As we may cache this directory.)
  clean_project "${git_dir}"
done
