#!/bin/bash
#
# The author has placed this work in the Public Domain, thereby relinquishing all
# copyrights. Everyone is free to use, modify, republish, sell or give away this
# work without prior consent from anybody.
#
# This documentation is provided on an “as is” basis, without warranty of any kind.
# Use at your own risk! Under no circumstances shall the author(s) or contributor(s)
# be liable for damages resulting directly or indirectly from the use or non-use
# of this documentation.
#

# default parameters
NODE_DIST_WEB_PATH="https://nodejs.org/dist"
INSTALL_PATH="/usr/lib/nodejs"
BIN_PATH="/usr/bin"
USER_COMMAND="install" # default command to run
NODE_VERSION="latest" # default nodejs version

PACKAGE=`basename $0`

# display usage help
function Usage()
{
cat <<-ENDOFMESSAGE
$PACKAGE - Install a specific nodejs version from ${NODE_DIST_WEB_PATH}.
  Run as root to install or uninstall specific versions of nodejs.

$PACKAGE [command] [options]
  arguments:
  command - the command to execute, i|install (default), u|uninstall

  options:
  -h, --help show brief help
  -v, --version NODE_VERSION the version to install, i.e. 4.4.7
NOTE: This command must be executed as root. The command will fail if the nodejs package is installed.
ENDOFMESSAGE
  exit
}


# die with message
function Die()
{
  echo "$* Use -h option to display help."
  exit 1
}


# process command line arguments into values to use
function ProcessArguments() {
  # separate options from arguments
  while [ $# -gt 0 ]
  do
    opt=$1
    shift
    case ${opt} in
      -v|--version)
      if [ $# -eq 0 -o "${1:0:1}" = "-" ]; then
        Die "The ${opt} option requires an version number, i.e. -v 4.4.7."
      fi
      export NODE_VERSION="v$1"
      shift
      ;;
      -h|--help)
      Usage;;
      *)
      if [ "${opt:0:1}" = "-" ]; then
        Die "${opt}: unknown option."
      fi
      ARGV+=(${opt});;
    esac
  done

  if [ ${#ARGV[@]} -gt 0 ]; then
    export USER_COMMAND="${ARGV[0]}"
  fi
}


# get the available version info from web page
function VersionAvailable()
{
  # Arguments: platform architecture
  local filename=""
  local version=""
  local platform=""
  local architecture=""
  local content=$(wget $NODE_WEB_PATH -q -O -)
  local regex="node-v([0-9]+\.[0-9]+\.[0-9]+)-([^-]+)-([^.]+)\."
  while read -r line; do
    if [[ $line =~ $regex ]]; then
      if [ "$1" == "${BASH_REMATCH[2]}" ] && [ "$2" == "${BASH_REMATCH[3]}" ]; then
      filename="$line"
      version="${BASH_REMATCH[1]}"
      platform="${BASH_REMATCH[2]}"
      architecture="${BASH_REMATCH[3]}"
      fi
    fi
  done < <(echo "$content" | grep -o "node-v[^>]*\.gz")
  if [ -z "$filename" ]; then
    Die "Failed to locate a version at $NODE_WEB_PATH for $NODE_PLATFORM $NODE_ARCHITECTURE. Try specifying a different version."
  fi
  echo "$filename $version $platform $architecture"
}


function LatestInstalledVersion()
{
  local version=""
  local regex=".*/node-v([0-9]+\.[0-9]+\.[0-9]+)-([^-]+)-([^./]+)"
  for file in $INSTALL_PATH/*; do
    if [[ $file =~ $regex ]]; then
      if [ -z $version ]; then
        version="${BASH_REMATCH[1]}"
      else
        compare_versions "$version" "${BASH_REMATCH[1]}"
        case $? in
          0)
          ;;
          1)
          ;;
          2)
          version="${BASH_REMATCH[1]}"
          ;;
          *)
          Die "Version compare returned unknown value $?"
          ;;
        esac
      fi
    fi
  done
  echo "$version"
}


compare_versions()
{
    local v1=( $(echo "$1" | tr '.' ' ') )
    local v2=( $(echo "$2" | tr '.' ' ') )
    local len="$((${#v1[*]} > ${#v2[*]} ? ${#v1[*]} : ${#v2[*]}))"
    for ((i=0; i<len; i++))
    do
        [ "${v1[i]:-0}" -gt "${v2[i]:-0}" ] && return 1
        [ "${v1[i]:-0}" -lt "${v2[i]:-0}" ] && return 2
    done
    return 0
}


# determine the package architecture that is needed
function PackageArchitecture()
{
  local arch=$(arch)
  echo $(case "$arch" in
    x86_64) echo "x64";;
    *) echo "$arch";;
  esac)
}


# build environment
function BuildEnvironment()
{
  export NODE_WEB_PATH="${NODE_DIST_WEB_PATH}/${NODE_VERSION}/"
  export NODE_ARCHITECTURE="$(PackageArchitecture)"
  export NODE_PLATFORM="linux" # TODO dynamically determine os type
}


# check that user is root
function IsRoot() {
  if [ ! $( id -u ) -eq 0 ]; then
    Die "$0 Must be run as root."
  fi
}


# install nodejs
function InstallNodeJS()
{
  IsRoot

  # get version details in array (filename version platform architecture)
  local version=($(VersionAvailable "$NODE_PLATFORM" "$NODE_ARCHITECTURE"))
  local node_version="${version[1]}" # may differ if search was in "latest"
  local node_file="${version[0]}"
  local node_install_dir="node-v${node_version}-${NODE_PLATFORM}-${NODE_ARCHITECTURE}"
  local node_download_path="${NODE_DIST_WEB_PATH}/${NODE_VERSION}/${node_file}"

  mkdir -p "$INSTALL_PATH"
  cd $INSTALL_PATH

  # get node package if not installed
  if [ ! -d $node_install_dir ]; then
    echo "$node_download_path"
    wget "$node_download_path" -O "$node_file"

    # extract
    tar xf "$node_file"

    # remove tar
    rm -f "$node_file"
  fi
  
  InstallAlternative "$INSTALL_PATH/$node_install_dir" "$node_version" || InstallSymlink "$INSTALL_PATH/$node_install_dir"

  echo "Install complete."
}


# install in alternatives
function InstallAlternative()
{
  command -v update-alternativesxx
  if [ $? -eq 0 ]; then
    local node_install_path=$1;
    local node_version=$2
    # install alternatives
    local priority=`echo $node_version | sed 's/[\.v]//g'`
    update-alternatives --install /usr/bin/node node "$node_install_path/bin/node" "$priority"
    update-alternatives --install /usr/bin/npm npm "$node_install_path/bin/npm" "${priority}"
    true
  else
    false
  fi
}


# install as symlink
function InstallSymlink()
{
  local node_install_path=$1;
  ln -sf "$node_install_path/bin/node" "$BIN_PATH/node"
  ln -sf "$node_install_path/bin/npm" "$BIN_PATH/npm"
}


# uninstall nodejs
function UninstallNodeJS()
{
  IsRoot

  cd $INSTALL_PATH
  local node_install_dir="node-${NODE_VERSION}-${NODE_PLATFORM}-${NODE_ARCHITECTURE}"
  local node_install_path="$INSTALL_PATH/$node_install_dir"
  if [ ! -d "$node_install_path" ]; then Die "This version of nodejs is not installed. ($node_install_path)"; fi

  RemoveAlternative "$node_install_path" || UpdateSymlink "$node_install_path"

  # remove install
  rm -r ${node_install_path};

  echo "Uninstall complete."
}


# remove from alternatives
function RemoveAlternative()
{
  command -v update-alternativesxx
  if [ $? -eq 0 ]; then
    local node_install_path=$1
    update-alternatives --remove node "$node_install_path/bin/node"
    update-alternatives --remove npm "$node_install_path/bin/npm"
    true
  else
    false
  fi
}


# update symlinks to latest version or remove
function UpdateSymlink()
{
  local latest=$(LatestInstalledVersion)
  if [ -z latest ]; then
    local node_install_path=$1;
    rm -f "$BIN_PATH/node"
    rm -f "$BIN_PATH/npm"
  else
    local node_install_dir="node-v${latest}-${NODE_PLATFORM}-${NODE_ARCHITECTURE}"
    local node_install_path="$INSTALL_PATH/$node_install_dir"
    InstallSymlink "$node_install_path"
  fi
}


# install as symlink
function RemoveSymlink()
{
  local node_install_path=$1;
  ln -sf "$BIN_PATH/node" "$node_install_path/bin/node"
  ln -sf "$BIN_PATH/npm" "$node_install_path/bin/npm"
}


# prepare to execute command
ProcessArguments $*
BuildEnvironment


# process command
case ${USER_COMMAND} in
  i|install)
  InstallNodeJS
  ;;
  u|uninstall)
  UninstallNodeJS
  ;;
  *)
  Die "${USER_COMMAND} is an unknown command."
  ;;
esac
