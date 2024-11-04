
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# This model re-implements the specific functions needed to
# support a datalad repo connected to an EBRAINS dataset.
#
# See the superclass for the real information about the methods
# overridden here.
class EbrainsDataladRepository < DataladRepository

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessor :access_token # jwt

  # The object states are the path where the datalad repo is installed,
  # and the EBRAINS access token.
  def initialize(install_path, access_token)
    @install_path = Pathname.new(install_path)
    @access_token = access_token
  end

  # Given a url, will install the remote datalad repo under the install_path.
  # Normally only needed to be done once.
  # If tagname is provided, a "git checkout" will be performed on that tag
  # or branch.
  #
  # This particular implementation uses the EBRAINS extensions of datalad
  # to clone the repo.
  def install_from_url!(url, tagname=nil)
    parent   = install_path.parent
    basename = install_path.basename.to_s
    tagname  = tagname.presence || "" # need empty string in bash commands
    retcode = run_datalad_commands(parent,
      "
        datalad ebrains-clone -s #{url} #{basename.bash_escape} >/dev/null 2>&1 || exit 41
        cd #{basename.bash_escape}                                        || exit 42
        if test -n #{tagname.bash_escape} ; then
          git checkout -b cb_#{tagname.bash_escape} #{tagname.bash_escape} >/dev/null || exit 43
        else
          git pull                                        >/dev/null      || exit 42
        fi
      "
    )
    cb_error "Could not run datalad ebrains-clone."                           if retcode == 41
    cb_error "Could not update datalad dataset."                              if retcode == 42
    cb_error "Could not checkout version #{tagname} of datalad dataset."      if retcode == 43
    cb_error "Error occured when running datalad script: retcode=#{retcode}"  if retcode > 0
    true
  end

  private

  # Runs one or more bash +commands+ from within the directory +indir+.
  # The directory will be created as needed. The commands are
  # likely going to invoke the "datalad" command, which can sometimes
  # be implemented as a singularity container, so we make sure to
  # set up the proper environment to maximize the chances of this working.
  #
  # We have to make sure that:
  # 1) the pwd is set to the parent of where the datalad command will create files
  # 2) we provide a FULL path for the destination too (this must be true in +commands+ too)
  # 3) we HOPE the singularity setup has 'overlay' support to mount the
  #    datalad root (install_path) too using the SINGULARITY_BINDPATH environment variable.
  # 4) we set the EBRAINS access token in an environment variable
  #
  # This may seem excessive but datalad in singularity is very brittle.
  def run_datalad_commands(indir, commands) #:nodoc:
    indir    = Pathname.new(indir).realdirpath.to_s # make full; last component may not exist
    token    = self.access_token
    bindpath = install_path.parent.to_s
    # Note: we export the token twice so that everything works whether or not
    # datalad is deployed containerized or bare-metal
    system("
            export KG_AUTH_TOKEN=#{token.bash_escape}
            export APPTAINERENV_KG_AUTH_TOKEN=#{token.bash_escape}
            export SINGULARITY_BINDPATH=#{bindpath.bash_escape}
            mkdir -p #{indir.bash_escape} || exit 31
            cd       #{indir.bash_escape} || exit 32
            #{commands}
           ")
    retcode = $?.exitstatus
    cb_error "Could not mkdir '#{indir}'" if retcode == 31
    cb_error "Could not chdir '#{indir}'" if retcode == 32
    retcode
  end

end

