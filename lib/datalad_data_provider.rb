
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

class DataladDataProvider < SshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  DATALAD_PREFIX = "http://datasets.datalad.org"

  def self.pretty_category_name #:nodoc:
    "Datalad.ORG"
  end

  def is_browsable?(by_user = nil) #:nodoc:
    true
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def content_storage_shared_between_users? #:nodoc:
    true
  end

  def is_fast_syncing? #:nodoc:
    false
  end

  def provider_full_path(userfile) #:nodoc:
    datalad_relative_path(userfile) + userfile.name
  end

  def impl_is_alive? #:nodoc:
    true
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    src         = provider_full_path(userfile)
    dest        = cache_full_path(userfile)
    parent      = dest.parent
    url_src     = Pathname.new(DATALAD_PREFIX) + src

    # Prepare receiving area
    mkdir_cache_subdirs(userfile) # DataProvider method core caching subsystem

    # Download.
    #
    # Because 'datalad' can be invoked from within a singularity container,
    # we have to make sure that:
    # 1) the pwd is set to the userfile cache's parent location;
    # 2) we provide a full path for the destination too;
    # 3) we HOPE the singularity setup has 'overlay' support to mount the
    #    pwd too using the SINGULARITY_BINDPATH environment variable.
    #
    # This may seem excessive but datalad in singularity is very brittle.
    with_modified_env('SINGULARITY_BINDPATH' => cache_rootdir().to_s) do # from BrainPortal/config/initializers/added_core_extensions/kernel.rb
      datalad_command = "cd #{parent.to_s.bash_escape} ; datalad install -r -g -s #{url_src.to_s.bash_escape} #{dest.to_s.bash_escape}"
      system(datalad_command)  # the stupid command produces tons of output on stdout
    end

    # Fix for too restrictive permissions deep in the .git repo
    system("chmod", "-R", "u+rwx", "#{dest.to_s.bash_escape}/.git")

    # We may have to run 'git-annex uninit' many levels deep;
    # hopefully our applications are OK with accessing files through
    # symbolic links?
    #if userfile.is_a?(FileCollection)
    #  Dir.chdir(dest.to_s) do
    #    system("git-annex uninit")
    #  end
    #end

    cb_error "Cannot fetch content of '#{userfile.name}' on Datalad site from '#{url_src}'." unless File.exists?(dest.to_s)

    true
  end

  def impl_provider_erase(userfile)  #:nodoc:
    cb_error 'Erase not allowed'
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    cb_error 'Rename not allowed'
  end

  private

  # NOTE: The metadata :datalad_path_prefix is
  # for a future feature where userfile's DP location
  # can be prefixed with a subpath; not currently implemented
  # in browsing or registration.
  def datalad_relative_path(userfile) #:nodoc:
    base   = self.remote_dir.presence
    prefix = (userfile.meta[:datalad_path_prefix] || {})[self.id]
    path   = base ? Pathname.new(base) : Pathname.new("")
    path  += prefix if prefix
    path
  end

  def impl_provider_list_all(user = nil) # user ignored

    dirname = self.remote_dir || ""

    # Datalad Caching
    # We use the SystemScratchSpace data provider for storing the datalad dataset root.
    # The name of the file might end with an "=" sign if the remote_dir is empty.
    datalad_cache_userfile_name =
      "DataLad.rr=#{RemoteResource.current_resource.id}.dp=#{self.id}.dir=#{dirname.gsub("/","_")}"

    # Fetch the datalad dataset info
    datalad_cache_userfile = DataladSystemSubset.find_or_create_as_scratch(:name => datalad_cache_userfile_name) do |datalad_cache_dir|
       system("datalad install -r --recursion-limit 1 -s #{DATALAD_PREFIX}/#{dirname} #{datalad_cache_dir}/#{dirname}")
    end
    datalad_cache_dir = datalad_cache_userfile.cache_full_path

    # Parse the information
    json_text = IO.popen("cd #{datalad_cache_dir}/#{dirname};datalad ls --json display","r") { |fh| fh.read }
    entries = JSON.parse(json_text)
    nodes   = entries["nodes"] || []

    # Build and return a list of FileInfo objects to represents the available entries.
    list = nodes.map do |node|
      name = node['name']
      type = node['type']
      size = node['size']['total'] || "0"
      size.sub!(/\s*kb/,"000")
      size.sub!(/\s*mb/,"000000")
      size.sub!(/\s*gb/,"000000000")
      size.sub!(/\s*tb/,"000000000000")
      size = size.to_i
      datetime = DateTime.parse(node['date'])

      next if name == "." || name == ".." # robust
      fileinfo = FileInfo.new

      fileinfo.name          = name
      fileinfo.symbolic_type = ( type == 'file' ? :regular :
                                 type =~ /uninitialized|dataset|directory|folder/i ? :directory :
                                 :unknown
                               )
      fileinfo.size          = size
      fileinfo.atime = fileinfo.ctime = fileinfo.mtime = datetime

      fileinfo
    end.compact

    list.sort! { |a,b| a.name <=> b.name }
    list
  end

end

