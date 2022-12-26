
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

      # The logic to clean the BIDS subject should only be perform
      # if the task perform on a BIDS subject
      inputid_ssm = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
      return true if !inputid_ssm

      inputid_cb  = descriptor.custom_module_info('BoutiquesBidsCleaner')
      input_cb    = descriptor.input_by_id(inputid_cb)

      anat_to_keep = invoke_params[:anat_to_keep]
      return true if anat_to_keep.empty?

      userfile_id        = invoke_params[inputid_ssm]
      userfile           = Userfile.find(userfile_id)
      subject_name       = userfile.name # 'sub-1234'
      anat_to_keep.map!{ |filename| filename.split('.')[0]}.uniq!

      files_to_exclude_by_folder = files_to_exclude_by_folder(subject_name, anat_to_keep)

      backup_and_copy_subject(subject_name)

      remove_extra_files(subject_name, files_to_exclude_by_folder)

      true
    end

    # Overrides the same method in BoutiquesClusterTask, as used
    # during cluster_commands()
    def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
      super
      .reject do |k,v|
           k.to_s == "anat_to_keep"
        end # returns a dup()
    end

    private

    def files_to_exclude_by_folder(subject_name, filenames_to_keep) #:nodoc:
      files_in_subject           = Dir.glob("#{Dir.pwd}/#{subject_name}/**/*")

      files_to_exclude_by_folder = Hash.new { |h, k| h[k] = [] }
      files_in_subject.each do |file_fullpath|
        folder_name = Pathname.new(File.dirname(file_fullpath)).basename.to_s
        next if !['anat'].include?(folder_name)
        file_basename = Pathname.new(file_fullpath).basename.to_s
        file_fullpath_without_extension = file_basename.split('.')[0]
        next if filenames_to_keep.include?(file_fullpath_without_extension)
        files_to_exclude_by_folder[folder_name] << file_fullpath
      end

      files_to_exclude_by_folder.each_pair do |folder, filenames|
        self.addlog("File to exclude from the original subject in '#{folder}' folder exclude the following files:")
        self.addlog("#{filenames.join(", ")}")
      end

      return files_to_exclude_by_folder
    end

    def backup_and_copy_subject(subject_name) #:nodoc:
      begin
        bk_name = "#{subject_name}_orig"
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
