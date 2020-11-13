
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

require 'fileutils'

# This library handles some elementary operation on a local datalad
# repository, mosly used when that repo is a cache for a DataladDataProvider.
#
#   handler = DataladRepository.new('/path/to/repo') # 'repo' might not yet exist
class DataladRepository

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_reader :install_path

  # The only object state is the path where the datalad repo is installed
  def initialize(install_path)
    @install_path = Pathname.new(install_path)
  end

  # Checks the URL with curl and makes sure we can connect to it.
  # Max timeout: 20 seconds
  def self.remote_reachable?(url)
    cmd_string = "curl --head -f --connect-timeout 20 #{url.bash_escape} > /dev/null 2> /dev/null"
    system(cmd_string)
  rescue
    false
  end

  # Given a url, will install the remote datalad repo under the install_path.
  # Normally only needed to be done once.
  def install_from_url!(url)
    parent   = install_path.parent
    basename = install_path.basename.to_s
    retcode = run_datalad_commands(parent,
      "
        datalad install -s #{url} #{basename.bash_escape} >/dev/null 2>&1 || exit 41
        cd #{basename.bash_escape}                                        || exit 42
        git pull                                          >/dev/null      || exit 42
      "
    )
    cb_error "Could not run datalad install."                                 if retcode == 41
    cb_error "Could not update datalad dataset."                              if retcode == 42
    cb_error "Error occured when running datalad script: retcode=#{retcode}"  if retcode > 0
    true
  end

  # Given an installed repo, will install any subcomponent (directory or
  # file) underneath it.
  def install_r!(subpath)
    retcode  = run_datalad_commands(install_path,
      "
        datalad install -r #{subpath.to_s.bash_escape} >/dev/null 2>&1 || exit 41
      "
    )
    cb_error "Could not run datalad install subpath command."                if retcode == 41
    cb_error "Error occured when running datalad script: retcode=#{retcode}" if retcode > 0
    true
  end

  # Given a subcomponent that has been installed, will get the actual content.
  # Applied to a subdirectory, is always recursive.
  def get!(subpath)
    fulldest = install_path + subpath
    parent   = fulldest.parent
    basename = fulldest.basename
    retcode  = run_datalad_commands(parent,
      "
        datalad get #{basename.to_s.bash_escape} >/dev/null 2>&1 || exit 41
      "
    )
    cb_error "Could not run datalad get command."                            if retcode == 41
    cb_error "Error occured when running datalad script: retcode=#{retcode}" if retcode > 0
    true
  end

  # Given a subpath that has been installed and the data file gotten with get!(),
  # will run the git-annex 'uninit' command to transform all symbolic links into
  # their real files. Destructive on the datalad repo, but can still be done several times
  # without harm.
  def uninit!(subpath)
    # Alright, this is really stupid but "git-annex uninit" requires
    # that it be run with its cwd set to the git top level. So we need
    # to go up the hierarchy and find .git and rewrite 'subpath' to contain
    # just the components down from there. Messy
    fulldest             = install_path + subpath # /inst1/inst2/subpath1/subpath2, subpath2 might be a file or directory
    git_top, rel_subpath = search_parent_git(fulldest)
    cb_error "Could not find .git repo within dataset" if git_top.to_s.size < install_path.to_s.size

    retcode  = run_datalad_commands(git_top,
      "
        git-annex uninit #{rel_subpath.to_s.bash_escape} >/dev/null 2>&1
        test $? -gt 1 && exit 41
        true
      "
    )
    cb_error "Could not run git-annex uninit command."                       if retcode == 41
    cb_error "Error occured when running datalad script: retcode=#{retcode}" if retcode > 0
    true
  end

  # Search a file structure up until .git is found; returns
  # the path to the parent of .git and the components below
  # that were in the argument 'path'. E.g. given
  #
  #   /data/something/cbrain/BrainPortal/app/models/user.rb
  #
  # where the .git is under 'cbrain', the method would return
  #
  #   [ "/data/something/cbrain", "BrainPortal/app/models/user.rb" ]
  def search_parent_git(path)
    git_top       = Pathname.new(path)
    short_subpath = Pathname.new('.')
    while git_top.to_s.size > 1
      break if (git_top + ".git").exist? #  /inst1/inst2/subpath1/subpath2/.git (subpath2 might be a file)
      short_subpath = git_top.basename + short_subpath
      git_top = git_top.parent # move up
    end
    [ git_top, short_subpath ]
  end

  # Runs both get! and uninit!
  def get_and_uninit!(subpath)
    self.get!(subpath) && self.uninit!(subpath)
  end

  ####################################################################
  # Listing files
  ####################################################################

  # This method scans a local directory containing a datalad subset
  # and returns small objects for each entries in it, with
  # three components: :name, :size_in_bytes, and :type .
  # Since a datalad subset is a git annex structure it will
  # query information using git-annex when a symlink is found
  # and then pretend that it is a normal file.
  def list_contents_from_dataset(subpath, recursive=false) #:nodoc:

    cb_error "Subpath must be relative" unless Pathname.new(subpath).relative?

    fulldest = install_path + subpath
    if File.directory?(fulldest)
      glob_string = recursive ? "#{fulldest}/**/*": "#{fulldest}/*"
    else
      glob_string = fulldest # the file itself and nothing more
    end

    dllist = []
    Dir.glob(glob_string) do |fname|
      bname = File.basename(fname)                      # abc.txt
      dname = File.dirname(fname)                       # /path/dataladroot/subpath/subdir/abc.txt
      name  = fname.sub("#{fulldest}","").sub(/^\//,"") # subdir/abc.txt
      name  = bname if name.blank? # when we have just a file

      next if bname == "." || bname == ".." || bname == ".datalad" || bname =~ /^\.git/

      # get metadata that you can only get from git-annex
      stat = File.lstat(fname)
      type = stat.symlink? ? :symlink : stat.ftype.to_sym rescue nil
      size = 0
      size = stat.size.to_i if type.to_sym == :file

      if type == :symlink
        ## This seems the most stable way to get this stuff, go to the directory and git annex info it there
        git_annex_json_text = IO.popen("cd #{dname.bash_escape}; git annex info #{bname.bash_escape} --fast --json --bytes") { |fh| fh.read }
        git_annex_json = JSON.parse(git_annex_json_text) rescue {}
        type = :gitannexlink               if git_annex_json.has_key?("key")
        size = git_annex_json['size'].to_i if git_annex_json.has_key?("size")
      end

      dllist << {:name => name, :size_in_bytes => size, :type => type}
    end

    dllist
  end

  ####################################################################
  # Internal methods
  ####################################################################

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
  #
  # This may seem excessive but datalad in singularity is very brittle.
  def run_datalad_commands(indir, commands) #:nodoc:
    indir    = Pathname.new(indir).realdirpath.to_s # make full; last component may not exist
    bindpath = install_path.parent.to_s
    system("
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

