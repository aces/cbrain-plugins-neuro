
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

# This class implements a DataProvider that can
# fetch files and directories from a Datalad
# remote storage.
class DataladDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :datalad_repository_url
  validate              :relative_path_is_it
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

  # Makes sure the subpath is relative.
  def relative_path_is_it #:nodoc:
    clean = Pathname.new((self.datalad_relative_path.presence || "").strip).cleanpath
    if clean.to_s =~ /^\.\./
      errors.add(:datalad_relative_path, ' must be a relative path')
      return false
    end
    clean = "" if clean.to_s == '.' # just to make things pretty in the form; also acts as '.'
    self.datalad_relative_path = clean.to_s
    true
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

  # Not a full path, a relative path in this implementation!
  def provider_full_path(userfile) #:nodoc:
    Pathname.new(self.datalad_relative_path) + userfile.name
  end

  def impl_is_alive? #:nodoc:
    DataladRepository.remote_reachable?(self.datalad_repository_url)
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    datalad_repo.get_and_uninit!( provider_full_path(userfile) )

    needslash = userfile.is_a?(FileCollection) ? "/" : ""
    source    = datalad_repo.install_path + self.datalad_relative_path + userfile.name

    mkdir_cache_subdirs(userfile)
    dest      = userfile.cache_full_path

    rsyncout = bash_this("rsync -a -l --no-p --no-g --chmod=u=rwX,g=rX,o=r --delete #{self.rsync_excludes} #{shell_escape(source)}#{needslash} #{shell_escape(dest)} 2>&1")
    cb_error "Failed to rsync local file '#{source}' to cache file '#{dest}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?

    true
  end

  def impl_provider_erase(userfile)  #:nodoc:
    cb_error 'Erase not allowed'
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    cb_error 'Rename not allowed'
  end

  def impl_provider_list_all(user = nil) #:nodoc: # user ignored
    provider_readdir(self.datalad_relative_path.presence || ".", false)
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    ### Should this be recursive?
    recursive = directory == :all ? true : false

    ### fix the right path name
    directory = "" if directory == :top || directory == :all || directory == '.'
    subpath   = Pathname.new(self.datalad_relative_path) + userfile.name + directory

    # Scan tree on filesystem
    subtree = provider_readdir(subpath,recursive,allowed_types)

    # Re-insert prefix path for all entries
    if userfile.is_a?(FileCollection)
      prefix_path = File.join(userfile.name,directory)
      subtree.each { |fi| fi.name = File.join(prefix_path,fi.name) }
    end
    subtree
  end

  private

  # Name of the automatically-created userfile that
  # holds the datalad install
  def default_name_of_userfile_for_datalad_cache
    "TopDatalad.rr=#{RemoteResource.current_resource.id}.dp=#{self.id}"
  end

  # The datalad installation tree is cached in a standard userfile.
  # The administrator has the liberty to configure this in two ways:
  # 1) automatic and transparent, it will be a file created on demand
  # in the special ScratchDataProvider
  # 2) manually, it can be a DataladSystemSubset registered on any standard data
  # provider; the datalad 'install' command will have to be run manually too.
  def userfile_for_datalad_cache
    return @userfile_for_datalad_cache if @userfile_for_datalad_cache

    # Option 1: admin has configured a file by ID manually
    custom_id = self.meta[:datalad_system_subset_id].presence
    if custom_id
      @userfile_for_datalad_cache = DataladSystemSubset.where(:id => custom_id).first
      return @userfile_for_datalad_cache if @userfile_for_datalad_cache
    end

    # Option 2: we cache in the scratch space, on demand
    @userfile_for_datalad_cache = DataladSystemSubset.find_or_create_as_scratch(
      :name => default_name_of_userfile_for_datalad_cache()
    ) do |cache_full_path|
      dlr = DataladRepository.new(cache_full_path)
      dlr.install_from_url!( self.datalad_repository_url )
      dlr.install_r!( self.datalad_relative_path ) if self.datalad_relative_path.present?
    end
    @userfile_for_datalad_cache
  end

  # Returns a DataladRepository handler that provides
  # an api to a file system instance of a datalad install tree
  def datalad_repo
    userfile_for_datalad_cache.sync_to_cache
    @datalad_repo ||= DataladRepository.new(
      userfile_for_datalad_cache.cache_full_path
    )
  end

  # This method invokes the method
  #
  #   list_contents_from_dataset()
  #
  # on the DalataRepository object used to maintain the
  # cached repository, and builds a list of FileInfo objects out of the
  # returned array.
  def provider_readdir(dirname, recursive=true, allowed_types = [:regular, :directory]) #:nodoc:

    dirname       = Pathname.new(dirname) # it's possible dirname to point to a file, in fact
    allowed_types = Array(allowed_types)

    full_dirname  = datalad_repo.install_path + dirname
    is_dir        = true if File.directory?(full_dirname)

    list = []

    # Syscall caches
    uid_to_owner = {}
    gid_to_group = {}

    # Call the datalad repository method to get the short
    # reports about each entry
    datalad_repo.list_contents_from_dataset(dirname,recursive).each do |fname|

      # There are only three attributes in the reports
      name = fname[:name]          # relative path, e.g. "a/b/c.txt"
      size = fname[:size_in_bytes]
      type = fname[:type]

      dl_full_path = is_dir ? full_dirname + name : full_dirname

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

