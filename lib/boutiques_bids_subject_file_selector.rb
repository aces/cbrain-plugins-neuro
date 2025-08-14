
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# This module allows a user to explicitely select a set of
# files to keep within a BidsSubject provided as input.
# Within the task's work directory, a full copy of the
# input BidsSubject will be made, and then any files
# not selected for keeping will be deleted within this copy.
#
# In the Boutiques descriptor, the module can be configured with
# an entry in the "cbrain:integrator_modules" section:
#
#   "BoutiquesBidsSubjectFileSelector": { "input_id": "input_id_for_file_list" },
#
# In this case, the BidsSubject selected for the input "input_id" will
# be the one copied. Also, a new artifical input with ID "input_id_for_file_list"
# of type String (with list=true)  will be added to the descriptor. That new
# input is the one containing a list of relative file paths to keep.
# The paths should not include the basename of the BidsSubject itself.
#
# E.g. if "input_id" is a BidsSubject named "sub-123" containing:
#
#   "sub-123/anat/sub-123_abc.nii"
#   "sub-123/anat/sub-123_xyz.nii"
#   "sub-123/func/sub-123_func1.json"
#   "sub-123/func/sub-123_func2.json"
#
# Then the list of Strings for the input "input_id_for_file_list" might select
# two files with these two entries:
#
#   "anat/sub-123_xyz.nii"
#   "func/sub-123_func1.json"
#
# Notes:
#
# 1) If the value of "input_id_for_file_list" is completely empty, NO files
# will be removed from the input list (but a full copy will still be made
# in the task's work directory).
#
# 2) If a subdirectory end up empty after file removal, the subdirectory will
# stay present within the task's work directory.
module BoutiquesBidsSubjectFileSelector

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method takes a descriptor and adds a new
  # fake input.
  # Inputs specified in BoutiquesBidsSubjectFileSelector are moved
  # in the "cbrain_bids_extensions" group section of the form.
  def descriptor_with_special_input(descriptor)
    descriptor       = descriptor.dup
    map_ids_for_bbss = descriptor.custom_module_info('BoutiquesBidsSubjectFileSelector') || {}
    return descriptor if map_ids_for_bbss.empty?
    groups           = descriptor.groups || []

    # Find or create new group if necessary
    cb_mod_group = groups.detect { |group| group.id == 'cbrain_bids_extensions' }
    if cb_mod_group.blank?
      cb_mod_group = BoutiquesSupport::Group.new(
        "name"        => 'CBRAIN BIDS Extensions',
        "id"          => 'cbrain_bids_extensions',
        "description" => 'Special options for BIDS data files',
        "members"     => [],
      )
      groups.push cb_mod_group
    end
    descriptor.groups = groups

    # Add new inputs
    map_ids_for_bbss.each do |dir_input_id, keep_input_id|
      dir_input_name = descriptor.input_by_id(dir_input_id).name

      new_input = BoutiquesSupport::Input.new(
        "name"          => "List of relative paths to keep within subject '#{dir_input_id}'",
        "id"            => "#{keep_input_id}",
        "description"   => "List of files to keep within the subject folder defined by the input '#{dir_input_name}'. This list must match files that are present. Files not listed here will be remove before processing starts. If no files are specified, no files are removed at all. Relative paths must not start with the subject name (e.g. 'anat/xyz' instead of 'sub-123/anat/xyz').",
        "type"          => "String",
        "optional"      => true,
        "list"          => true
      )

      descriptor.inputs    << new_input
      cb_mod_group.members << new_input.id
    end

    descriptor
  end

  def descriptor_for_form #:nodoc:
    descriptor_with_special_input(super)
  end

  def descriptor_for_before_form #:nodoc:
    descriptor_with_special_input(super)
  end

  def descriptor_for_after_form #:nodoc:
    descriptor_with_special_input(super)
  end

  def descriptor_for_final_task_list #:nodoc:
    descriptor_with_special_input(super)
  end

  # This method overrides the one in BoutiquesClusterTask.
  #
  # Only copy and clean the Subject directory if needed.
  # If only files specified in input are present in folder
  # no need to copy and remove files.
  #
  # If cleaning need to be done the subject will be copied,
  # then the extra files will be removed.
  def setup #:nodoc:
    basename    = Revision_info.basename
    commit      = Revision_info.short_commit

    self.addlog("Cleaning BIDS Subjects")
    self.addlog("#{basename} rev. #{commit}")

    descriptor       = self.descriptor_for_setup
    map_ids_for_bbss = descriptor.custom_module_info('BoutiquesBidsSubjectFileSelector') || {}

    # Restart handling; we need to restore the state of the workdir
    # if we had previously renamed some inputs.
    map_ids_for_bbss.each do |dir_input_id, _|
      userfile_id  = invoke_params[dir_input_id]
      userfile     = Userfile.find(userfile_id)
      subject_name = userfile.name # 'sub-1234'

      undo_backup_and_copy_subject(subject_name) # will do nothing if we are not restarting
    end

    # Standard setup code: sync the files etc etc.
    return false unless super

    # Main copying and removing
    map_ids_for_bbss.each do |dir_input_id, keep_input_id|

      userfile_id  = invoke_params[dir_input_id]
      userfile     = Userfile.find(userfile_id)
      subject_name = userfile.name # 'sub-1234'

      # Backup the original subject and do a copy to work on
      backup_and_copy_subject(subject_name)

      to_keep = invoke_params[keep_input_id] || []
      if to_keep.blank? # we keep everything as-is
        self.addlog "Keeping all files for subject '#{subject_name}'"
        next
      end

      self.addlog("Got an list of #{to_keep.size} files to keep")
      to_keep = to_keep.map { |x| "#{subject_name}/#{x}" } # turns "path" to "subject_name/path"
      #self.addlog("ToKeep=\n#{to_keep.join("\n")}")

      current_list = IO.popen("find #{subject_name.bash_escape} -type f -print","r") do |fh|
        fh.readlines.map(&:strip)
      end
      self.addlog("Found #{current_list.size} files in '#{subject_name}'")
      #self.addlog("CurrentList=\n#{current_list.join("\n")}")

      common_list = current_list & to_keep
      self.addlog("Found #{common_list.size} files in common")
      cb_error "Error: the list of files to keep is not all included in the files found in the subject" if
        common_list.size != to_keep.size

      to_remove = current_list - to_keep
      self.addlog("Found #{to_remove.size} files to remove")
      #self.addlog("ToRemove=\n#{to_remove.join("\n")}")
      to_remove.each { |path| File.unlink(path) }
    end

    true
  end

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands()
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    map_ids_for_bbss = self.descriptor_for_cluster_commands.custom_module_info('BoutiquesBidsSubjectFileSelector') || {}
    map_ids_for_bbss_values = map_ids_for_bbss.values

    super
      .reject do |k,_|
        map_ids_for_bbss_values.include?(k.to_s)
      end # returns a dup()
  end

  private

  # Copy the original subject, allow to not touch the cache when
  # the extra files will be deleted.
  def backup_and_copy_subject(subject_name) #:nodoc:
    self.addlog "Backing up files for '#{subject_name}'"
    bk_name = "ORIG-#{subject_name}_#{self.id}"
    File.rename(subject_name, bk_name) if !File.exist?(bk_name)
    rsyncout = bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{bk_name.bash_escape}/ #{subject_name.bash_escape} 2>&1")
    cb_error "Failed to rsync '#{bk_name}' to '#{subject_name}'\nrsync reported: #{rsyncout}" unless rsyncout.blank?
  end

  # During a restart, ourq setup method must UNDO the copy steps
  # so that the normal setup can be retried.
  def undo_backup_and_copy_subject(subject_name) #:nodoc:
    bk_name = "ORIG-#{subject_name}_#{self.id}" # must match convention in other method
    if File.symlink?(bk_name) && (File.directory?(subject_name) && ! File.symlink?(subject_name))
      self.addlog("Warning: restart condition detected, undoing local copy of '#{subject_name}'")
      FileUtils.remove_entry(subject_name, true) # remove the old copy
      File.rename(bk_name,subject_name)
    end
  end

  # This utility method runs a bash +command+ , captures the output
  # and returns it. The user of this method is expected to have already
  # properly escaped any special characters in the arguments to the
  # command.
  def bash_this(command) #:nodoc:
    fh = IO.popen(command,"r")
    output = fh.read
    fh.close
    output
  end

end
