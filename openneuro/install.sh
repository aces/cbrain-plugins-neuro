#!/bin/bash

# Install/uninstall script for OpenNeuro support within a CBRAIN portal.

function usage {
  cat <<USAGE

This is an installer script for adding OpenNeuro functionality
to a CBRAIN BrainPortal application.

Usage:

  $0 install
or
  $0 uninstall

This script mostly creates three (3) symbolic links in the BrainPortal's
installation, and adds a few lines the the Rails 'routes.rb' file.
Updating the 'cbrain-plugins-neuro' codebase will then automatically
also update the added OpenNeuro functionality.

For reference, the links created are:

  In CBRAIN BrainPortal                     -> In this plugin repo
  --------------------------------------------------------------------
  app/models/open_neuro.rb                  -> app/models/open_neuro.rb
  app/controllers/open_neuro_controller.rb  -> app/controllers/open_neuro_controller.rb
  app/views/open_neuro                      -> app/views/open_neuro

This script needs to be run from the folder where it is installed,
and will automatically find the root of the BrainPortal application
(usually two level up) and the basename of the plugins repo.
USAGE
  exit 2
}

# Validate mode install vs uninstall
mode="$1"
if test "X$mode" != "Xinstall" -a "X$mode" != "Xuninstall" ; then
  usage
fi

# Find paths to files and directories and validate all is OK

# 1)
# /path/to/.../BrainPortal/cbrain_plugins/cbrain-plugins-neuro/openneuro/install.sh
where_i_am=$(readlink -f ${BASH_SOURCE[0]})  # full path of this script here

# 2)
# /path/to/.../BrainPortal/cbrain_plugins/cbrain-plugins-neuro/openneuro
plugins_on_dir=$(dirname "$where_i_am")

# 3)
# /path/to/.../BrainPortal/cbrain_plugins/cbrain-plugins-neuro
plugins_dir=$(dirname "$plugins_on_dir")
plugins_basename=$(basename "$plugins_dir")

# 4)
# /path/to/.../BrainPortal
brainportal_dir=$(dirname $(dirname "$plugins_dir"))

# Validate a bunch of stuff just to be sure
function testdir {
   if ! test -d "$1" ; then
     echo "Local installation error: expected to find directory '$1': $2" 1>&2
     exit 1 # exit from program entirely
   fi
}
function testfile {
   if ! test -f "$1" ; then
     echo "Local installation error: expected to find file '$1': $2" 1>&2
     exit 1 # exit from program entirely
   fi
}

# Test that we can truly find the stuff we expect in this repo here
testdir  "$plugins_dir/openneuro"               "(in plugins repo)"
testdir  "$plugins_on_dir/app/controllers"      "(in plugins repo)"
testdir  "$plugins_on_dir/app/models"           "(in plugins repo)"
testdir  "$plugins_on_dir/app/views"            "(in plugins repo)"
testdir  "$plugins_on_dir/app/views/open_neuro" "(in plugins repo)"
testdir  "$plugins_on_dir/config"               "(in plugins repo)"

testfile "$plugins_on_dir/app/controllers/open_neuro_controller.rb" "(in plugins repo)"
testfile "$plugins_on_dir/config/openneuro_routes.rb"               "(in plugins repo)"

# Bunch of stuff that normally are part of a BrainPortal
testdir  "$brainportal_dir/app/controllers" "(in BrainPortal Rails application)"
testdir  "$brainportal_dir/app/models"      "(in BrainPortal Rails application)"
testdir  "$brainportal_dir/app/views"       "(in BrainPortal Rails application)"
testdir  "$brainportal_dir/test_api"        "(in BrainPortal Rails application)"
testdir  "$brainportal_dir/user_keys"       "(in BrainPortal Rails application)"
testdir  "$brainportal_dir/cbrain_plugins"  "(in BrainPortal Rails application)"

# Test again the path back into where the plugins is supposed to be deployed
testdir  "$brainportal_dir/cbrain_plugins/$plugins_basename"  "(in BrainPortal Rails application)"

function process_symlink {
  mode="$1"
  target="$2"
  value="$3"
  if test -e "$target" -o -L "$target" ; then
    if test -L "$target" ; then
      echo "Removing existing symlink at $target"
      /bin/rm "$target"
    else
      echo "Error: something is in the way: $target"
      exit 2
    fi
  fi
  if test $mode = "install" ; then
    echo "Creating symlink:"
    echo "  '$target'"
    echo "    ->"
    echo "  '$value'"
    if ! /bin/ln -s "$value" "$target" ; then
       echo "Error: creating symlink '$target' -> '$value'"
       exit 2
    fi
  fi
}

# We create relative path so that if the BrainPortal application is moved around
# on the filesystem, the code will still work.

process_symlink $mode \
  "$brainportal_dir/app/controllers/open_neuro_controller.rb" \
  "../../cbrain_plugins/$plugins_basename/openneuro/app/controllers/open_neuro_controller.rb"

process_symlink $mode \
  "$brainportal_dir/app/models/open_neuro.rb" \
  "../../cbrain_plugins/$plugins_basename/openneuro/app/models/open_neuro.rb"

process_symlink $mode \
  "$brainportal_dir/app/views/open_neuro" \
  "../../cbrain_plugins/$plugins_basename/openneuro/app/views/open_neuro"

# Add or remove the "load" statement for the new OpenNeuro routes
route_file="$brainportal_dir/config/routes.rb"
tmpclean="/tmp/clean_routes.$$"

# Remove old 'load' line
if grep '^load.*openneuro_routes' "$route_file" >/dev/null ; then
  echo "Removing existing 'load' line for openneuro routes in:"
  echo "  '$route_file'"
  grep -v '^load.*openneuro_routes' < "$route_file" > $tmpclean
  if ! test -f $tmpclean -o ! -s $tmpclean ; then
    echo "Something went wrong in creating the tmp file $tmpclean to hold the cleaned up routes file."
    exit 2
  fi
  /bin/cp $tmpclean "$route_file" || exit 2
  /bin/rm -f $tmpclean
fi

# Add the 'load' line. We add also a blank line just before in case
# the existing route file doesn't have a final new line character.
if test "$mode" = "install" ; then
  echo "Installing 'load' line for openneuro routes at the bottom of:"
  echo "  '$route_file'"
  cat <<RUBY_LOAD >> "$route_file"

load "#{Rails.root}/cbrain_plugins/$plugins_basename/openneuro/config/openneuro_routes.rb"
RUBY_LOAD
fi

echo ""
if test "$mode" = "install" ; then
  echo "Success! OpenNeuro support fully configurated"
else
  echo "Success! OpenNeuro support fully UNconfigurated"
fi
