
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

# This module work only in conjonction with the
# "BoutiquesBidsSingleSubjectMaker" module.
#
# In case of some files need to be removed from the
# original data a copy will be done and a partial
# copy of the subject will be used to create the SingleSubject
#
# Here is of to define the usage of the module in the Boutiques
# descriptor:
#
# Define the input field:
#   {
#     "description": "Partial path that should include the folder name and at list the file name with or without extension (e.g: 'anat/T1')"",
#     "id": "files_to_keep",
#     "name": "List of files",
#     "optional": true,
#     "type": "String",
#     "list": true,
#     "value-key": "[FILES_TO_KEEP]"
#   }
#
# Then in '"cbrain:integrator_modules":
#
#   "BoutiquesBidsCleaner": [ "files_to_keep" ],
#
# Note:
#  - If no file as to be removed from the original subject.
# The module will avoid to do an extra copy of the subject and
# will use the original one.
# - If no file are specified for some folder e.g: func, no filtering
# will be performed on the func folder.
# - The filtering will take care of keeping the associate file together.
# If 'anat/sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz' the
# associated *.json file will be kept too.
#
# For the following subject:
#
# sub-123456
# └── ses-V01
#     ├── anat
#     │   ├── sub-123456_ses-V01_acq-anat_run-1_TB1TFL.json
#     │   ├── sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz
#     │   └── sub-123456_ses-V01_acq-svs_run-1_localizer.json
#     ├── dwi
#     │   ├── sub-123456_ses-V01_dir-AP_run-1_sbref.json
#     │   └── sub-123456_ses-V01_dir-AP_run-1_sbref.nii.gz
#     ├── fmap
#     │   ├── sub-123456_ses-V01_dir-AP_run-1_epi.json
#     │   └── sub-123456_ses-V01_dir-AP_run-1_epi.nii.gz
#     └── func
#         ├── sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.json
#         └── sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.nii.gz
#
# the string 'anat/sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz' is
# specified, the result will be the following:
#
# sub-123456
# └── ses-V01
#     ├── anat
#     │   ├── sub-123456_ses-V01_acq-anat_run-1_TB1TFL.json
#     │   └── sub-123456_ses-V01_acq-anat_run-1_TB1TFL.nii.gz
#     ├── dwi
#     │   ├── sub-123456_ses-V01_dir-AP_run-1_sbref.json
#     │   └── sub-123456_ses-V01_dir-AP_run-1_sbref.nii.gz
#     ├── fmap
#     │   ├── sub-123456_ses-V01_dir-AP_run-1_epi.json
#     │   └── sub-123456_ses-V01_dir-AP_run-1_epi.nii.gz
#     └── func
#         ├── sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.json
#         └── sub-123456_ses-V01_task-rest_dir-PA_run-1_bold.nii.gz
#
#
module BoutiquesBidsCleaner

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Inputs specified in BoutiquesBidsCleaner are moved
  # in the "cbrain_bids_extensions" group section.
  def descriptor_for_form #:nodoc:
    descriptor = super.dup

    # Nothing to do if not used in conjonction with
    # 'BoutiquesBidsSingleSubjectMaker' module.
    return descriptor if !descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')

    # Add new group with that input
    groups       = descriptor.groups || []
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

    cb_mod_group.members <<= descriptor.custom_module_info('BoutiquesBidsCleaner')

    descriptor.groups = groups
    descriptor
  end

  # This method overrides the one in BoutiquesClusterTask.
  # If files is specified in input specified in "BoutiquesBidsSingleSubjectMaker".
  # and in "BoutiquesBidsCleaner".
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

    input_id_ssm = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    input_id_bc  = descriptor.custom_module_info('BoutiquesBidsCleaner')

    # Extract filenames without extension to keep
    filenames_wo_ext_by_folder = extract_filenames_wo_ext_by_folder()

    # Call the logic to clean the BIDS subject only if some files are specified
    return true if filenames_wo_ext_by_folder.empty?

    userfile_id        = invoke_params[input_id_ssm]
    userfile           = Userfile.find(userfile_id)
    subject_name       = userfile.name # 'sub-1234'

    # Reverse the logic to get the files to exclude
    files_to_exclude_by_folder = files_to_exclude_by_folder(subject_name, filenames_wo_ext_by_folder)

    # Backup the original subject and do a copy to work on
    backup_and_copy_subject(subject_name)

    # Remove extra files in the copied subject.
    # The partial copy will be used by the SingleSubjectMaker.
    remove_extra_files(subject_name, files_to_exclude_by_folder)

    true
  end

  # Override the value of input specified in "BoutiquesBidsCleaner"
  # by an array with a single input_id key.
  #
  # These inputs will not be used anyway in the command line.
  # It will be append at the beggining of the command line in
  # a "true" statement in order to have "bosh exec simulate" passing.
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    descriptor = self.descriptor_for_setup
    input_id   = descriptor.custom_module_info('BoutiquesBidsCleaner')

    invoke           = super.dup
    invoke[input_id] = [ input_id ]

    invoke
  end


  # Remove token corresponding to input specified in 'BoutiquesBidsCleaner"
  # Then add a "true" statement before the command line with the token
  # to pass "bosh exec simulate" validation.
  def descriptor_for_cluster_commands #:nodoc:
    descriptor = super.dup
    input_id   = descriptor.custom_module_info('BoutiquesBidsCleaner')
    command    = descriptor.command_line

    input      = descriptor.input_by_id(input_id)

    # The two strings we need
    token      = input.value_key

    # Make the substitution
    command    = command.sub(token, " ") # we replace only the first one

    # In order to prevent bosh from complaining if the value-key is no longer found
    # anywhere in the command-line, we re-instert a dummy no-op bash statement at the
    # beginning of the command with at least one use of that value-key. It will look
    # like e.g.

    #   "true [TOKEN] ; real command here"

    # In bash, the 'true' statement doesn't do anything and ignores all arguments.
    if ! command.include? token
      command = "true #{token} ; #{command}"
    end

    descriptor.command_line = command
    descriptor
  end

  private

  # Used when it is the "all_to_keep" option
  # in this case we used the parent directory in the filepath
  # to define the in_folder name.
  # If no in_folder found the file will be ingnore.
  #
  # This is done to avoid user to specify every single files
  # they want to keep in the whole subject folder.
  # The deletion of extra files at the end will only be done
  # in sub_folder for which we found an in_folder.
  # This way if no files was specified to_keep in dwi sub_folder,
  # then this sub folder will be untouch.
  def extract_filenames_wo_ext_by_folder #:nodoc:
    descriptor  = self.descriptor_for_setup
    input_id  = descriptor.custom_module_info('BoutiquesBidsCleaner')

    filenames = invoke_params[input_id] || []

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
      next if !folders_name.include?(folder_name) && !folders_name.include?("all")

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

  # Copy the the original subject.
  # Allow to not touch the cache when
  # the extra files will be deleted.
  def backup_and_copy_subject(subject_name) #:nodoc:
      bk_name = "#{subject_name}_#{self.id}"
      File.rename(subject_name, bk_name) if !File.exist?(bk_name)
      FileUtils.cp_r(bk_name, subject_name) # Attention when 2 times setup solved by rsync `rsync -a -H --delete --chmod see dp_code bk_name/ subject_name`
      system("rsync","-arH --delete","#{bk_name}/", subject_name)
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

end
