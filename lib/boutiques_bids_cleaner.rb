
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


# XXXX Description of the module
module BoutiquesBidsCleaner

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # ############################################
  # # Bourreau (Cluster) Side Modifications
  # ############################################

  # TODO
  # This method overrides the one in BoutiquesClusterTask.
  def setup
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

  # XXXXX
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    descriptor   = self.descriptor_for_setup
    input_ids_bc = descriptor.custom_module_info('BoutiquesBidsCleaner')

    invoke       = super.dup
    input_ids_bc.each do |input_id|
      invoke[input_id] = [ input_id ]
    end
    invoke
  end


  # XXXXX
  def descriptor_for_cluster_commands
    descriptor   = super.dup
    input_ids_bc = descriptor.custom_module_info('BoutiquesBidsCleaner')
    command      = descriptor.command_line

    input_ids_bc.each do |input_id|
      input = descriptor.input_by_id(input_id)

      # The two strings we need
      token      = input.value_key # e.g. '[BIDSDATASET]'

      # Make the substitution
      command = command.sub(token, " ") # we replace only the first one

      # In order to prevent bosh from complaining if the value-key is no longer found
      # anywhere in the command-line, we re-instert a dummy no-op bash statement at the
      # beginning of the command with at least one use of that value-key. It will look
      # like e.g.

      #   "true [BIDSDATASET] ; real command here"

      # In bash, the 'true' statement doesn't do anything and ignores all arguments.
      if ! command.include? token
        command = "true #{token} ; #{command}"
      end
    end

    descriptor.command_line = command
    descriptor
  end

  # # This method takes a descriptor and adds a new
  # # File input, in a group at the bottom of all the other
  # # input groups. This input recives, optionally, the
  # # content of a participants.tsv file .
  # def descriptor_with_bids_cleaner(descriptor)
  #   descriptor = descriptor.dup

  #   # Add new input for dataset_description.json
  #   new_input_dd = BoutiquesSupport::Input.new(
  #     "name"          => "BIDS 'dataset_description.json' file",
  #     "id"            => "dataset_description_json",
  #     "description"   => "If set, provides a separate dataset_description.json file. If not set, a plain JSON file will be generated with dummy data.",
  #     "type"          => "File",
  #     "optional"      => true,
  #   )
  #   descriptor.inputs <<= new_input_dd

  #   # Add new input for participants.tsv
  #   new_input_part = BoutiquesSupport::Input.new(
  #     "name"          => "BIDS dataset 'participants.tsv' file",
  #     "id"            => "cbrain_participants_tsv",
  #     "description"   => "If set, provides a separate participants.tsv file. Must contain at least the subject being processed. If not set, a plain participants.tsv file will be generated with only the subject ID in it.",
  #     "type"          => "File",
  #     "optional"      => true,
  #   )
  #   descriptor.inputs <<= new_input_part

  #   # Add new group with that input
  #   groups       = descriptor.groups || []
  #   cb_mod_group = groups.detect { |group| group.id == 'cbrain_bids_extensions' }
  #   if cb_mod_group.blank?
  #     cb_mod_group = BoutiquesSupport::Group.new(
  #       "name"        => 'CBRAIN BIDS Extensions',
  #       "id"          => 'cbrain_bids_extensions',
  #       "description" => 'Special options for BIDS data files',
  #       "members"     => [],
  #     )
  #     groups.unshift cb_mod_group
  #   end
  #   cb_mod_group.members <<= new_input_dd.id
  #   cb_mod_group.members <<= new_input_part.id

  #   descriptor.groups = groups
  #   descriptor
  # end


  private

  def files_to_exclude_by_folder(subject_name, filenames_wo_ext_by_folder) #:nodoc:
    files_in_subject = Dir.glob("#{Dir.pwd}/#{subject_name}/**/*")

    folders_name = filenames_wo_ext_by_folder.keys

    files_to_exclude_by_folder = Hash.new { |h, k| h[k] = [] }
    files_in_subject.each do |file_fullpath|
      folder_name = Pathname.new(File.dirname(file_fullpath)).basename.to_s
      next if !folders_name.include?(folder_name) && !folders_name.include?("all")

      file_basename = Pathname.new(file_fullpath) rescue nil
      file_basename = file_basename && file_basename.basename.to_s
      file_fullpath_wo_ext = file_basename.split('.')[0]

      next if filenames_wo_ext_by_folder[folder_name].include?(file_fullpath_wo_ext)
      files_to_exclude_by_folder[folder_name] << file_fullpath
    end

    files_to_exclude_by_folder.each_pair do |folder, filenames|
      self.addlog("File to exclude from the original subject in '#{folder}' folder exclude the following files:")
      self.addlog("\n- #{filenames.join("\n- ")}")
    end

    return files_to_exclude_by_folder
  end

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

  def remove_extra_files(subject_name,files_to_exclude_by_folder)
    files_to_exclude_by_folder.each_pair do |folder,filenames|
      folder = "#{subject_name}/#{folder}"
      filenames.each do |filename|
        self.addlog("Remove #{filename} from #{subject_name}")
        FileUtils.remove_entry(filename) rescue true
      end
    end
  end

end
