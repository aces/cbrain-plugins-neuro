
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

class DataladDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :datalad_repository_url, :datalad_relative_path
  before_validation     :strip_datalad_info

  def self.pretty_category_name #:nodoc:
    "DataladProvider"
  end

  # Callback before_validation
  def strip_datalad_info #:nodoc:
    self.datalad_repository_url  = (self.datalad_repository_url.presence || "").strip
    self.datalad_relative_path   = (self.datalad_relative_path.presence  || "").strip
    true
  end

  def datalad_repo
    @datalad_repo ||= DataladRepository.new(self.datalad_repository_url,
                                            self.datalad_relative_path,
                                            self.id,
                                            RemoteResource.current_resource.id)
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

  def provider_full_path(userfile) #:nodoc: # not sure is needed anymore
    datalad_repo.url_for_userfile(userfile)
  end

  def impl_is_alive? #:nodoc:
    datalad_repo.connected?
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    datalad_repo.download_userfile_to_cache(userfile)
    true
  end

  def impl_provider_erase(userfile)  #:nodoc:
    cb_error 'Erase not allowed'
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    cb_error 'Rename not allowed'
  end

  def impl_provider_list_all(user = nil) #:nodoc: # user ignored
    subset_cache = datalad_repo.install_subset_for_browsing
    provider_readdir(subset_cache,false)
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    subset_cache = datalad_repo.install_subset_for_userfile(userfile)

    ### Should this be recursive?
    recursive = directory == :all ? true : false

    ### fix the right path name
    directory = "" if directory == :top || directory == :all || directory == '.'
    path_name = File.join(subset_cache, directory).sub(/\/$/,"")

    # Scan tree on filesystem
    subtree = provider_readdir(path_name,recursive,allowed_types)

    # Re-insert prefix path for all entries
    prefix_path = File.join(userfile.name,directory)
    subtree.each { |fi| fi.name = File.join(prefix_path,fi.name) }
    subtree
  end

  private

  # This method invokes the method
  #
  #   DataladRepository.list_contents_from_dataset
  #
  # and build a list of FileInfo objects out of the
  # returned array.
  def provider_readdir(dirname, recursive=true, allowed_types = [:regular, :directory]) #:nodoc:

    dirname       = Pathname.new(dirname)
    allowed_types = Array(allowed_types)

    list = []

    # Syscall caches
    uid_to_owner = {}
    gid_to_group = {}

    # Call the datalad repository method to get the short
    # reports about each entry
    DataladRepository.list_contents_from_dataset(dirname,recursive).each do |fname|

      # There are only three attributes in the reports
      name = fname[:name]          # relative path, e.g. "a/b/c.txt"
      size = fname[:size_in_bytes]
      type = fname[:type]

      dl_full_path = dirname.join(name)

      # fix type
      type = :regular if type == :file || type == :gitannexlink

      next unless allowed_types.include? type
      next if is_excluded?(name)

      # get stat with lstat
      stat = File.lstat(dl_full_path)

      # Look up user name from uid
      uid        = stat.uid
      owner_name = (uid_to_owner[uid] ||= (Etc.getpwuid(uid).name rescue uid.to_s))

      # Lookup group name from gid
      gid        = stat.gid
      group_name = (gid_to_group[gid] ||= (Etc.getgrgid(gid).name rescue gid.to_s))

      # Create a FileInfo
      fileinfo               = FileInfo.new

      # From Datalad
      fileinfo.name          = name
      fileinfo.symbolic_type = type
      fileinfo.size          = size

      # From lstat():
      fileinfo.permissions   = stat.mode
      fileinfo.atime         = stat.atime
      fileinfo.ctime         = stat.ctime
      fileinfo.mtime         = stat.mtime
      fileinfo.uid           = uid
      fileinfo.owner         = owner_name
      fileinfo.gid           = gid
      fileinfo.group         = group_name

      list << fileinfo
    end

    list.sort! { |a,b| a.name <=> b.name }
    list
  end
end

