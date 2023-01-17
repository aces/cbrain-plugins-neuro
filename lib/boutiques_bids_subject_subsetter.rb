
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

# In case of some files need to be removed from the
# original data a copy will be done.
# Then the copy will be used to create the SingleSubject.
#
# Here is how to define the usage of the module in the Boutiques
# descriptor in the "cbrain:integrator_modules" section:
#
#   "BoutiquesBidsSubjectSubsetter": { "subject_dir": "input_id_for_bids_subject_subsetter" },
#
# Note:
# - If no files as to be removed from the original subject.
# The module will avoid to do an extra copy of the subject and
# will use the original one.
# - If no files are specified for some folder (e.g: func), no filtering
# will be performed on the func folder.
# - The filtering will take care of keeping the associate file together.
# If 'anat/sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz' the
# associated *.json file will be kept too.
#
# For the following subject:
#
#   sub-123456
#     - ses-V01
#       - anat
#         - sub-123456_ses-V01_acq-anat_run-1_TB1TFL.json
#         - sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz
#         - sub-123456_ses-V01_acq-svs_run-1_localizer.json
#       - func
#         - sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.json
#         - sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.nii.gz
#
# the string 'anat/sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz' is
# specified, the result will be the following:
#
#   sub-123456
#     - ses-V01
#       - anat
#         - sub-123456_ses-V01_acq-anat_run-1_TB1TFL.json
#         - sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz
#       - func
#         - sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.json
#         - sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.nii.gz
#
module BoutiquesBidsSubjectSubsetter

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method takes a descriptor and adds a new
  # fake input.
  # Inputs specified in BoutiquesBidsSubjectSubsetter are moved
  # in the "cbrain_bids_extensions" group section.
  def descriptor_with_special_input(descriptor)
    descriptor       = descriptor.dup
    map_ids_for_bbss = descriptor.custom_module_info('BoutiquesBidsSubjectSubsetter')
    groups           = descriptor.groups || []

    map_ids_for_bbss.each do |dir_input_id, keep_input_id|
      dir_input_name = descriptor.input_by_id(dir_input_id).name

      new_input = BoutiquesSupport::Input.new(
        "name"          => "Partial path for BIDS sub setter",
        "id"            => "#{keep_input_id}",
        "description"   => "List of files to keep within the BIDS subject defined by '#{dir_input_name}'. The filtering will take care of keeping the associated file together.\n If 'anat/sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz' the associated *.json file will be kept too.\n If files are not specified for some subfolder no filtering will be perfomed.\n That should include the folder name and at least the file name with or without extension (e.g: 'anat/T1')",
        "type"          => "String",
        "optional"      => true,
        "list"          => true
      )

      descriptor.inputs << new_input

      # Add new group with that input
      cb_mod_group = groups.detect { |group| group.id == 'cbrain_bids_extensions' }
      if cb_mod_group.blank?
        cb_mod_group = BoutiquesSupport::Group.new(
          "name"        => 'CBRAIN BIDS Extensions',
          "id"          => 'cbrain_bids_extensions',
          "description" => 'Special options for BIDS data files',
          "members"     => [],
        )
        groups.unshift cb_mod_group
      end

      cb_mod_group.members << new_input.id
    end

    descriptor.groups = groups
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
    return false unless super

    descriptor  = self.descriptor_for_setup

    basename    = Revision_info.basename
    commit      = Revision_info.short_commit

    self.addlog("Cleaning BIDS dataset")
    self.addlog("#{basename} rev. #{commit}")

    map_ids_for_bbss = descriptor.custom_module_info('BoutiquesBidsSubjectSubsetter')

    map_ids_for_bbss.each do |dir_input_id, keep_input_id|
      # Extract filenames without extension to keep
      filenames_wo_ext_by_folder = extract_filenames_wo_ext_by_folder(keep_input_id)

      # Call the logic to clean the BIDS subject only if some files are specified
      return true if filenames_wo_ext_by_folder.empty?

      userfile_id  = invoke_params[dir_input_id]
      userfile     = Userfile.find(userfile_id)
      subject_name = userfile.name # 'sub-1234'

      # Reverse the logic to get the files to exclude
      files_to_exclude_by_folder = files_to_exclude_by_folder(subject_name, filenames_wo_ext_by_folder)

      # Backup the original subject and do a copy to work on
      backup_and_copy_subject(subject_name)

      # Remove extra files in the copied subject.
      # The partial copy will be used by the SingleSubjectMaker.
      remove_extra_files(subject_name, files_to_exclude_by_folder)
    end

    true
  end

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands()
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    map_ids_for_bbss_values = self.descriptor_for_cluster_commands
                                  .custom_module_info('BoutiquesBidsSubjectSubsetter')
                                  .values

    super
      .reject do |k,v|
        map_ids_for_bbss_values.include?(k.to_s)
      end # returns a dup()
  end

  private

  # The parent directory in the partial filepath
  # is used to define the folder name.
  # If no folder is found the file will be ingnored.
  #
  # This is done to avoid user to specify every single files
  # they want to keep in the whole subject folder.
  # For example if no files was specified in 'dwi' folder,
  # then this folder will be untouch.
  def extract_filenames_wo_ext_by_folder(keep_input_id) #:nodoc:
    descriptor = self.descriptor_for_setup

    filenames  = invoke_params["#{keep_input_id}"] || []

    filenames_wo_ext_by_folder = Hash.new { |h, k| h[k] = [] }
    return filenames_wo_ext_by_folder if filenames.empty?

    filenames.each do |filename|
      dirname, basename = File.split(filename)
      in_folder = File.split(dirname)[-1]
      if in_folder == "."
        self.addlog("Ignore file #{basename} no parent folder was found.")
        next
      end
      basename_wo_ext = basename.split('.')[0]
      if filenames_wo_ext_by_folder[in_folder] && !filenames_wo_ext_by_folder[in_folder].include?(basename_wo_ext)
        filenames_wo_ext_by_folder[in_folder] << basename_wo_ext
      end
    end

    return filenames_wo_ext_by_folder
  end

  # Return a hash each key correspond to a folder,
  # value are arrays that contain basenames of files
  # to remove if files are present in a folder
  # specified by the key.
  def files_to_exclude_by_folder(subject_name, filenames_wo_ext_by_folder) #:nodoc:
    files_in_subject = Dir.glob("#{subject_name}/**/*")

    folders_name = filenames_wo_ext_by_folder.keys

    files_to_exclude_by_folder = Hash.new { |h, k| h[k] = [] }
    # Iterate over the full subject directory

    files_in_subject.each do |file_fullpath|
      dirname, basename = File.split(file_fullpath)
      # Extract parent_folder name if
      # for 'sub-123/ses-01/anat/*_T1.json' folder_name is 'anat'
      folder_name = Pathname.new(dirname).basename.to_s
      next if !folders_name.include?(folder_name)

      file_fullpath_wo_ext = basename.split('.')[0]

      next if filenames_wo_ext_by_folder[folder_name].include?(file_fullpath_wo_ext)
      files_to_exclude_by_folder[folder_name] << file_fullpath
    end

    files_to_exclude_by_folder.each_pair do |folder, filenames|
      self.addlog("File to exclude from the original subject in '#{folder}' folder exclude the following files:")
      self.addlog("\n- #{filenames.join("\n- ")}")
    end

    return files_to_exclude_by_folder
  end

  # Copy the original subject, allow to not touch the cache when
  # the extra files will be deleted.
  def backup_and_copy_subject(subject_name) #:nodoc:
      bk_name      = "#{subject_name}_#{self.id}"
      File.rename(subject_name, bk_name) if !File.exist?(bk_name)
      rsyncout = bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{bk_name.bash_escape}/ #{subject_name.bash_escape} 2>&1")
      self.addlog "Failed to rsync '#{bk_name}' to '#{subject_name}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?
  end

  # This method removed the extra files from the copied subject.
  def remove_extra_files(subject_name,files_to_exclude_by_folder) #:nodoc:
    self.addlog("Remove files from #{subject_name}:\n")
    removed_files = ""
    files_to_exclude_by_folder.each_pair do |folder,filenames|
      folder = "#{subject_name}/#{folder}"
      filenames.each do |filename|
        FileUtils.remove_entry(filename) rescue true
        removed_files += "- #{filename}\n"
      end
    end
    self.addlog("\n#{removed_files}")
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
