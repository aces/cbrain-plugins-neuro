
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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


# This module work only in conjonction with the
# "BoutiquesBidsSingleSubjectMaker" module.
#
# The input Subject directory will not be used directly
# if some files need to be removed.
#
# Instead a copy witout the files specified by input defined
# in the BoutiquesBidsCleaner custom module
#
# For example in input:
#   {
#     "description": "Basename or fullpath of files to keep in * folder, if empty all files will be kept.",
#     "id": "*_to_keep",
#     "name": "Anat files to keep",
#     "optional": true,
#     "type": "String",
#     "list": true,
#     "value-key": "[ANAT_TO_KEEP]"
#   }
#
# "*" is referring to a specific folder:
#   - "anat_to_keep" refer to the anat folder.
#   - "func_to_keep" refer to the func folder.
#   - "all_to_keep" is special and refer to all the folder.
#
# Then in '"cbrain:integrator_modules":
#
#   "BoutiquesBidsCleaner": [ "*_to_keep" ],
#
# Note: If no file as to be removed from the original subject.
# The module will avoid to do a extra copy of the subject and
# will use the original one.
module BoutiquesBidsCleaner

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # ############################################
  # # Bourreau (Cluster) Side Modifications
  # ############################################

  # Inputs specified in BoutiquesBidsCleaner are moved
  # in the "cbrain_bids_extensions" group section.
  def descriptor_for_form #:nodoc:
    descriptor = super.dup

    # Nothing to do if not used in conjonction with
    # 'BoutiquesBidsSingleSubjectMaker' module
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

    input_ids_bc = descriptor.custom_module_info('BoutiquesBidsCleaner')

    input_ids_bc.each do |input_id|
      cb_mod_group.members <<= input_id
    end

    descriptor.groups = groups
    descriptor
  end

  # This method overrides the one in BoutiquesClusterTask.
  # If files is specified in input specified in "BoutiquesBidsSingleSubjectMaker".
  #
  # Only copy and clean the Subject directory if needed.
  # If only files specified in input are present in folder
  # no need to copy and remove files.
  #
  # If cleaning need to be done the subject will be copied,
  # then the extra files will be removed.
  def setup #:nodoc:
    return false unless super

    basename    = Revision_info.basename
    commit      = Revision_info.short_commit

    descriptor  = self.descriptor_for_setup

    # The logic to clean the BIDS subject
    # should only be perform on a BIDS subject
    input_id_ssm = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    return true if !input_id_ssm

    # The logic to clean the BIDS subject
    # should only be perform if BoutiquesBidsCleaner is not empty
    input_ids_bc = descriptor.custom_module_info('BoutiquesBidsCleaner')
    return true if !input_ids_bc || input_ids_bc.size == 0

    self.addlog("Cleaning BIDS dataset")
    self.addlog("#{basename} rev. #{commit}")

    # Extract filenames
    filenames_wo_ext_by_folder = Hash.new { |h, k| h[k] = [] }
    input_ids_bc.each do |input_id|
      filenames = invoke_params[input_id] || []
      next if filenames.empty?
      in_folder = input_id.gsub(/_to_keep$/, '')
      filenames_wo_ext_by_folder[in_folder] = filenames.map do |filename|
        pathname        = Pathname.new(filename) rescue nil
        next nil if !pathname
        basename        = pathname.basename.to_s
        basename_wo_ext = basename.split('.')[0]
        basename_wo_ext
      end.compact.uniq
    end

    # The logic to clean the BIDS subject
    # should only be perform if some files are specified
    return true if filenames_wo_ext_by_folder.empty?

    userfile_id        = invoke_params[input_id_ssm]
    userfile           = Userfile.find(userfile_id)
    subject_name       = userfile.name # 'sub-1234'

    files_to_exclude_by_folder = files_to_exclude_by_folder(subject_name, filenames_wo_ext_by_folder)

    backup_and_copy_subject(subject_name)

    remove_extra_files(subject_name, files_to_exclude_by_folder)

    true
  end

  # Override the value of input specified in "BoutiquesBidsCleaner"
  # by an array with a single input_id key.
  # These inputs will not be used anyway in the command line.
  # It will be append at the beggining of the command line in
  # a "true" statement in order to have "bosh exec simulate" passing.
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    descriptor   = self.descriptor_for_setup
    input_ids_bc = descriptor.custom_module_info('BoutiquesBidsCleaner')

    invoke       = super.dup
    input_ids_bc.each do |input_id|
      invoke[input_id] = [ input_id ]
    end
    invoke
  end


  # Remove token corresponding to input specified in 'BoutiquesBidsCleaner"
  # Then add a "true" statement before the command line with the token
  # to pass "bosh" validation.
  def descriptor_for_cluster_commands #:nodoc:
    descriptor   = super.dup
    input_ids_bc = descriptor.custom_module_info('BoutiquesBidsCleaner')
    command      = descriptor.command_line

    input_ids_bc.each do |input_id|
      input = descriptor.input_by_id(input_id)

      # The two strings we need
      token      = input.value_key # e.g. '[ANAT_TO_KEEP]'

      # Make the substitution
      command = command.sub(token, " ") # we replace only the first one

      # In order to prevent bosh from complaining if the value-key is no longer found
      # anywhere in the command-line, we re-instert a dummy no-op bash statement at the
      # beginning of the command with at least one use of that value-key. It will look
      # like e.g.

      #   "true [ANAT_TO_KEEP] ; real command here"

      # In bash, the 'true' statement doesn't do anything and ignores all arguments.
      if ! command.include? token
        command = "true #{token} ; #{command}"
      end
    end

    descriptor.command_line = command
    descriptor
  end

  private

  # Return a hash each key correspond to a folder
  # value is array that contain basenames of files
  # to remove if the file is present in a folder
  # corresponding to the key.
  #
  # If the key is "all" the file will be remove in
  # all the folder.


      # # Special case if folder name == all
      # if folder_name == "all"
      #   folder_name = File.split(dirname)[-1]
      #   if folder_name == '.'
      #     self.addlog("TODO --> print #{file_fullpath_wo_ext} ignored.")
      #     next
      #   end
      # end




  def files_to_exclude_by_folder(subject_name, filenames_wo_ext_by_folder) #:nodoc:
    files_in_subject = Dir.glob("#{Dir.pwd}/#{subject_name}/**/*")

    folders_name = filenames_wo_ext_by_folder.keys

    files_to_exclude_by_folder = Hash.new { |h, k| h[k] = [] }
    # Iterate over the full subject directory
    files_in_subject.each do |file_fullpath|
      dirname, basename = File.split(file_fullpath)
      # Extract parent_folder name if
      # for 'subj-123/ses-01/anat/*_T1.json' folder_name is 'anat'
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

  # Simply copy the the original subject.
  # This allow to not touch the cache when
  # the extra files will be deleted.
  def backup_and_copy_subject(subject_name) #:nodoc:
    begin
      bk_name = "#{subject_name}_#{self.id}"
      File.rename(subject_name, bk_name) if !File.exist?(bk_name)
      FileUtils.cp_r(bk_name, subject_name)
    rescue Error => error
      self.addlog("Unable to copy the original subject")
      self.addlog(error)
      return false
    end
  end

  # This method removed the extra files from the
  # copied subject.
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
