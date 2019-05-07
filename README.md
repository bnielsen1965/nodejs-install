# nodejs-install.sh

A BASH script used to maintain multiple NodeJS version installs on \*nix systems.


## multiple versions

Multiple versions of NodeJS will be maintained in the installation path which defaults
to /usr/lib/nodejs/. Each version is saved in a sub-directory based on the path created
when the installation tar file is extracted.


## auto download

When running the install command the install path is first checked to see if the
requested version is already available. If the requested version is not available
in the install path then a fresh tar file id downloaded from the nodejs.org site
and extracted to the install path.


## alternatives or symlinks

After installation the script will configure alternatives if used by the host system
or symlinks in /usr/bin otherwise. The node and npm commands will be immediately
available after the install command completes.


## version switching

The install command can be used to switch between versions that have been installed.
If a version is already installed then the download and extract are skipped but the
alternatives or symlinks will be updated to the requested version.


# usage

Run the BASH script from the command line...
> ./nodejs-install.sh [command] [options]

Commands include *install* or *uninstall* with install being the default command if
no command is provided when running the script.


## install

The install command will install the specified version of NodeJS or the latest version
if not specified and it will configure alternatives or symlinks to make the node and
npm commands available.

> sudo ./nodejs-install.sh install -v 10.15.3

When multiple versions are installed the install command can be used to switch between
versions. The install command will skip the download if it finds the package version
is already installed but it will proceed with configuring alternatives or symlinks.


## uninstall

Use the uninstall command to remove a specific version of NodeJS.

> sudo ./nodejs-install.sh uninstall -v 4.4.7

The configuration of alternatives or symlinks will attempt to switch to the latest
installed version or if no installed versions remain then the alternatives or symlinks
will be removed.
