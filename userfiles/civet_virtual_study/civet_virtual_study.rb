
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

# This class represents a FileCollection meant specifically
# to represent the output of several *CIVET* runs (see CbrainTask::Civet).
#
class CivetVirtualStudy < CivetStudy

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  CSV_BASENAME = "_civet_outputs.cbcsv"

  reset_viewers # we don't need any of the superclass viewers
  has_viewer :name => 'CIVET Virtual Study', :partial => :civet_virtual_study, :if => Proc.new { |u| u.is_locally_synced? }

  # Sync the CivetVirtualStudy, with the CivetOutputs too if deep=true
  def sync_to_cache(deep=true) #:nodoc:
    syncstat = self.local_sync_status(:refresh)
    return true if syncstat && syncstat.status == 'InSync'
    super()
    if deep && ! self.archived?
      self.sync_civet_outputs
      self.update_cache_symlinks
    end
    @cbfl = @civet_outs = nil # flush internal cache
    true
  end

  # Invokes the local sync_to_cache with deep=false; this means the
  # CivetOutputs are not synchronized and symlinks not created.
  # This method is used by FileCollection when archiving or unarchiving.
  def sync_to_cache_for_archiving
    result = sync_to_cache(false)
    self.erase_cache_symlinks rescue nil
    result
  end

  # When syncing to the provider, we locally erase
  # the symlinks, because they make no sense outside
  # of the local Rails app.
  # FIXME: this method has a slight race condition,
  # after syncing to the provider we recreate the
  # symlinks, but of another program tries to access
  # them during that time they might not yet be there.
  def sync_to_provider #:nodoc:
    self.cache_writehandle do # when the block ends, it will trigger the provider upload
      self.erase_cache_symlinks unless self.archived?
    end
    self.make_cache_symlinks unless self.archived?
    true
  end

  # Sets the set of CivetOutputs belonging to this study.
  # The CSV file inside the study will be created/updated,
  # as well as all the symbolic links. The content of the
  # study is NOT synced to the provider side.
  def set_civet_outputs(civetoutputs)
    cb_error "Not all CivetOutputs." unless civetoutputs.all? { |f| f.is_a?(CivetOutput) }

    # Prepare CSV content
    content     = CbrainFileList.create_csv_file_from_userfiles(civetoutputs)

    # This optimize so we don't reload the content for making the symlinks
    @cbfl       = CbrainFileList.new
    @cbfl.load_from_content(content)
    @civet_outs = nil

    # Write CSV content to the interal CSV file
    self.cache_prepare
    Dir.mkdir(self.cache_full_path) unless Dir.exist?(self.cache_full_path)
    File.write(csv_cache_full_path.to_s, content)
    self.update_cache_symlinks
    self.cache_is_newer
  end

  # Returns the subject IDs of the CivetOutputs in this study.
  def subject_ids
    self.get_civet_outputs.map(&:dsid)
  end

  # Returns the list of CivetOutputs from the internal CbrainFileList
  # The list is cached internally and access control is applied
  # based on the owner of the CivetVirtualStudy.
  def get_civet_outputs #:nodoc:
    if @cbfl.blank?
      @cbfl = CbrainFileList.new
      file_content = File.read(csv_cache_full_path.to_s)
      @cbfl.load_from_content(file_content)
    end
    @civet_outs ||= @cbfl.userfiles_accessible_by_user!(self.user).compact.select { |f| f.is_a?(CivetOutput) }
  end



  #====================================================================
  # Support methods, not part of this model's API.
  #====================================================================

  protected

  # Synchronize each of the CivetOutputs in the study
  def sync_civet_outputs #:nodoc:
    self.get_civet_outputs.each { |co| co.sync_to_cache }
  end

  # Clean up ALL symbolic links in the virtual study
  def erase_cache_symlinks #:nodoc:
    Dir.chdir(self.cache_full_path) do
      Dir.glob('*').each do |entry|
        # FIXME how to only erase symlinks that points to a CBRAIN cache or local DP?
        # Parsing the value of the symlink is tricky...
        File.unlink(entry) if File.symlink?(entry)
      end
    end
  end

  # This cleans up any old symbolic links, then recreates them.
  # Note that this does not sync the CivetOutput themselves.
  def update_cache_symlinks #:nodoc:
    self.erase_cache_symlinks
    self.make_cache_symlinks
  end

  # Create symbolic links within the study to its CivetOutputs.
  # Note that this does not sync the CivetOutput themselves.
  def make_cache_symlinks #:nodoc:
    self.get_civet_outputs.each do |co|
      link_path  = self.cache_full_path + co.dsid
      link_value = co.cache_full_path.to_s
      File.unlink(link_path) if File.symlink?(link_path) && File.readlink(link_path) != link_value
      File.symlink(link_value, link_path) unless File.exist?(link_path)
    end
  end

  def csv_cache_full_path #:nodoc:
    self.cache_full_path + CSV_BASENAME
  end

end
