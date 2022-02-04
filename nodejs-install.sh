#!/bin/bash
#
# The author has placed this work in the Public Domain, thereby relinquishing all
# copyrights. Everyone is free to use, modify, republish, sell or give away this
# work without prior consent from anybody.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHOR(S) OR CONTRIBUTOR(S)
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
# THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Bryan Nielsen (2019, 2020, 2022)
# https://github.com/bnielsen1965

# default parameters
NODE_DIST_WEB_PATH="https://nodejs.org/dist"
NODE_UNOFFICIAL_WEB_PATH="https://unofficial-builds.nodejs.org/download/release"
NODE_SELECTED_WEB_PATH=""
INSTALL_PATH="/usr/lib/nodejs"
BIN_PATH="/usr/bin"
USER_COMMAND="install" # default command to run
NODE_VERSION="latest" # default nodejs version

PACKAGE=`basename $0`

# display usage help
function Usage()
{
cat <<-ENDOFMESSAGE
$PACKAGE - Install a specific nodejs version from ${NODE_DIST_WEB_PATH} or optionally ${NODE_UNOFFICIAL_WEB_PATH}.
  Run as root to install, uninstall or switch to a specific versions of nodejs.

$PACKAGE [command] [options]
  arguments:
  command - the command to execute, i|install (default), u|uninstall

  options:
  -h, --help  Show brief help.
  -u, --unofficial  Use the unofficial build releases.
  -v, --version NODE_VERSION  Specify the version to install, i.e. 4.4.7
ENDOFMESSAGE
  exit
}


# die with message
function Die()
{
  echo "$*" >&2
  echo "Use -h option to display help." >&2
  exit 1
}


# process command line arguments into values to use
function ProcessArguments() {
  NODE_SELECTED_WEB_PATH="$NODE_DIST_WEB_PATH"

  # separate options from arguments
  while [ $# -gt 0 ]
  do
    opt=$1
    shift
    case ${opt} in
      -u|--unofficial)
      NODE_SELECTED_WEB_PATH="$NODE_UNOFFICIAL_WEB_PATH"
      ;;
      -v|--version)
      if [ $# -eq 0 -o "${1:0:1}" = "-" ]; then
        Die "The ${opt} option requires an version number, i.e. -v 4.4.7."
      fi
      export NODE_VERSION="$1"
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
  local searchVersion="$1"
  local searchArch="$2"
  local filename=""
  local version=""
  local platform=""
  local architecture=""
  local regex="node-v([0-9]+\.[0-9]+\.[0-9]+)-([^-]+)-([^.]+)\."
  local content=$(wget $NODE_WEB_PATH -q -O -)
  local wgetreturn=$?
  if [[ $wgetreturn -ne 0 ]]; then
    Die "Failed to wget available versions from $NODE_WEB_PATH"
  fi
  while read -r line; do
    if [[ $line =~ $regex ]]; then
      # check line for match with search parameters
      if [ "$searchVersion" == "${BASH_REMATCH[2]}" ] && [ "$searchArch" == "${BASH_REMATCH[3]}" ]; then
        filename="$line"
        version="${BASH_REMATCH[1]}"
        platform="${BASH_REMATCH[2]}"
        architecture="${BASH_REMATCH[3]}"
      fi
    fi
  done < <(echo "$content" | grep -o "node-v[^>]*\.gz")
  if [[ -z "$filename" ]]; then
    Die "Failed to locate a version at $NODE_WEB_PATH for $NODE_PLATFORM $NODE_ARCHITECTURE."
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
    aarch64) echo "arm64";;
    *) echo "$arch";;
  esac)
}


# build environment
function BuildEnvironment()
{
  export NODE_WEB_PATH="${NODE_SELECTED_WEB_PATH}/v${NODE_VERSION}/"
  export NODE_ARCHITECTURE="$(PackageArchitecture)"
  export NODE_PLATFORM="linux" # TODO dynamically determine os type
}


# check that user is root
function IsRoot() {
  if [ ! $( id -u ) -eq 0 ]; then
    Die "$0 Must be run as root."
  fi
}


# check if system uses alternatives
function UsingAlternatives() {
  command -v update-alternatives
  if [ $? -eq 0 ]; then
    true
  else
    false
  fi
}


# install nodejs
function InstallNodeJS()
{
  IsRoot
  # get version details in array (filename version platform architecture)
  local version=($(VersionAvailable "$NODE_PLATFORM" "$NODE_ARCHITECTURE"))
  if [[ -z "$version" ]]; then exit 1; fi
  local node_version="${version[1]}" # may differ if search was in "latest"
  local node_file="${version[0]}"
  local node_install_dir=$(VersionPath $node_version)
  local node_download_path="${NODE_SELECTED_WEB_PATH}/v${NODE_VERSION}/${node_file}"

  mkdir -p "$INSTALL_PATH"
  cd $INSTALL_PATH

  # get node package if not installed
  if [ ! -d $node_install_dir ]; then
    wget "$node_download_path" -O "$node_file"
    local wgetreturn=$?
    if [[ $wgetreturn -ne 0 ]]; then
      Die "Download $node_download_path failed"
    fi
    # extract
    tar xf "$node_file"
    # remove tar
    rm -f "$node_file"
  fi
  if [ $(UsingAlternatives) ]; then
    InstallAlternatives "$INSTALL_PATH/$node_install_dir" "$node_version"
  else
    InstallSymlinks "$INSTALL_PATH/$node_install_dir"
  fi
  echo "Install complete."
}


# install in alternatives
function InstallAlternatives()
{
  local node_install_path=$1;
  local node_version=$2
  local priority=`echo $node_version | sed 's/[\.v]//g'`
  update-alternatives --install /usr/bin/node node "$node_install_path/bin/node" "$priority"
  update-alternatives --set node "$node_install_path/bin/node"
  update-alternatives --install /usr/bin/npm npm "$node_install_path/bin/npm" "${priority}"
  update-alternatives --set npm "$node_install_path/bin/npm"
  if [ -f "$node_install_path/bin/npx" ]; then
    update-alternatives --install /usr/bin/npx npx "$node_install_path/bin/npx" "${priority}"
    update-alternatives --set npx "$node_install_path/bin/npx"
  fi
}


# install as symlink
function InstallSymlinks()
{
  local node_install_path=$1;
  ln -sf "$node_install_path/bin/node" "$BIN_PATH/node"
  ln -sf "$node_install_path/bin/npm" "$BIN_PATH/npm"
  if [ -f "$node_install_path/bin/npx" ]; then
    ln -sf "$node_install_path/bin/npx" "$BIN_PATH/npx"
  fi
}


# uninstall nodejs
function UninstallNodeJS()
{
  IsRoot
  cd $INSTALL_PATH
  local node_install_dir=$(VersionPath $NODE_VERSION)
  local node_install_path="$INSTALL_PATH/$node_install_dir"
  if [ ! -d "$node_install_path" ]; then Die "This version of nodejs is not installed. ($node_install_path)"; fi
  if [ $(UsingAlternatives) ]; then
    RemoveAlternative "$node_install_path"
    rm -r ${node_install_path}
  else
    rm -r ${node_install_path}
    RemoveSymlinks
  fi
  echo "Uninstall complete."
}


# remove from alternatives
function RemoveAlternative()
{
  if [ $(UsingAlternatives) ]; then
    local node_install_path=$1
    update-alternatives --remove node "$node_install_path/bin/node"
    update-alternatives --remove npm "$node_install_path/bin/npm"
    if [ -f "$node_install_path/bin/npx" ]; then
      update-alternatives --remove npx "$node_install_path/bin/npx"
    fi
    true
  else
    false
  fi
}


# update symlinks to latest version or remove
function UpdateSymlink()
{
  local latest=$(LatestInstalledVersion)
  if [ -n "$latest" ]; then
    local node_install_dir=$(VersionPath $latest)
    local node_install_path="$INSTALL_PATH/$node_install_dir"
    InstallSymlinks "$node_install_path"
  fi
}


# remove symlinks
function RemoveSymlinks()
{
  rm -f "$BIN_PATH/node"
  rm -f "$BIN_PATH/npm"
  rm -f "$BIN_PATH/npx"
  $(command -v node)
  if [ $? -ne 0 ]; then
    UpdateSymlink
  fi
}


# convert version string to version path string
function VersionPath()
{
  echo "node-v${1}-${NODE_PLATFORM}-${NODE_ARCHITECTURE}"
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
