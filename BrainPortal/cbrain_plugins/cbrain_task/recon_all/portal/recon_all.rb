
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

# A subclass of CbrainTask to launch recon-all of FreeSurfer.
#
# Original author: Natacha Beck
class CbrainTask::ReconAll < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties
    { :use_parallelizer => true }
  end
  
  def self.default_launch_args #:nodoc:
    {
    }
  end
  
  def before_form #:nodoc:
    params   = self.params

    file_ids  = params[:interface_userfile_ids] || []
    files = Userfile.find_all_by_id(file_ids)
    files.each do |file|
      cb_error "Error: this task can only run on MGZ files MINC1 or NifTi." unless
         file.is_a?(MgzFile) || file.is_a?(NiftiFile) || 
        (file.is_a?(MincFile) && file.which_minc_version != :minc2)
    end 
    
    return ""
  end

  def after_form #:nodoc:
    params = self.params

    # Check output_name 
    self.params_errors.add(:output_name, "provided contains some unacceptable characters.") unless params[:output_name].blank?  || is_legal_output_name?(params[:output_name])

    # Check subject_name
    self.params_errors.add(:subject_name, "provided contains some unacceptable characters.") unless params[:subject_name].blank? || is_legal_subject_name?(params[:subject_name])

    # Verification for multiple_subjects can't be blank
    self.params_errors.add(:multiple_subjects, "provided is blank. Choose between Single or Multiple.") if params[:multiple_subjects].blank? && (params[:interface_userfile_ids].size > 1)

    # If multiple_subjects is Single subject_name id required
    if params[:multiple_subjects] == "Single" && params[:subject_name].blank? && params[:interface_userfile_ids].size > 1
      self.params_errors.add(:subject_name, "you chose to run more than one file for a single subject, so you need to choose a subject name.")
    end
    
    ""
  end

  def final_task_list #:nodoc:
    params       = self.params

    subject_name = params[:subject_name].presence  || ""
    output_name  = params[:output_name].presence   || ""
    mode         = params.delete(:multiple_subjects)
    is_single    = mode == "Single" ? true : false 
    ids          = params[:interface_userfile_ids] || []
    
    # Create X tasks if !is_single
    task_list  = []
    if is_single
      task_list << self 
    else
      ids.each do |id|
        task = self.clone
        task.params[:interface_userfile_ids] = [ id ]
        task_list << task
      end
    end

    # Adjust subject_name and output_name foreach task
    task_list.each do |task|

      ids            = task.params[:interface_userfile_ids]
      userfiles_name = Userfile.find(ids).map &:name
      input_name     = userfiles_name[0]
      userfile_list  = userfiles_name.join(", ")

      # Verify subject_name
      local_subject_name   = task.params[:subject_name]
      if local_subject_name.blank?
        local_subject_name = input_name.split(/\./)[0]
        task.params[:subject_name] = local_subject_name 
      end

      # Verify output_name
      local_output_name   = task.params[:output_name]
      if local_output_name.blank?
        local_output_name = local_subject_name
        task.params[:output_name] = local_output_name
      end

      # Adjust description
      task.description  = (task.description.presence || "").strip
      task.description += "\n\n" if task.description.present?
      task.description += userfile_list
    end

    task_list
  end

  def self.pretty_params_names #:nodoc:
    { :output_name => 'Output name ', :subject_name => 'Subject name ' }
  end

  def untouchable_params_attributes #:nodoc:
    { :outfile_id => true}
  end

end

