
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
    params    = self.params

    file_ids  = params[:interface_userfile_ids] || []
    files     = Userfile.find_all_by_id(file_ids)
    files.each do |file|
      cb_error "Error: this task can only run on MGZ, MINC1, NifTi files
      or on a Recon-all Cross-Sectional Output (FreeSurfer subject directory)." unless
         file.is_a?(MgzFile) || file.is_a?(NiftiFile) || 
        (file.is_a?(MincFile) && file.which_minc_version != :minc2) ||
         file.is_a?(ReconAllCrossSectionalOutput)
    end 
    
    return ""
  end

  def after_form #:nodoc:
    params = self.params

    nb_input              = params[:interface_userfile_ids].size
    multiple_subjects     = params[:multiple_subjects]
    output_name           = params[:output_name]
    nb_singlefile         = self.count_singlefiles_in_input_list
    only_singlefile       = nb_input == nb_singlefile             ? true : false
    with_multi_singlefile = nb_input > 1 && only_singlefile       ? true : false 
      
    # Verification for multiple_subjects can't be blank
    self.params_errors.add(:multiple_subjects, "provided is blank. Choose between Single or Multiple.")              if multiple_subjects.blank? && (nb_input > 1)

    # Check output_name 
    self.params_errors.add(:output_name, "provided contains some unacceptable characters.")                          unless output_name.blank? || is_legal_output_name?(output_name)

    # Output name cannot be blank if multiple_subjects is Single
    self.params_errors.add(:output_name, "cannot be blank, if you run a single subject with multiple acquisitions.") if multiple_subjects == "Single" && with_multi_singlefile && output_name.blank?

    # Check special recon-all-LBL options
    n3_3t  = (params[:n3_3t]  || "").strip
    nui_3t = (params[:nui_3t] || "").strip
    self.params_errors.add(:n3_3t,  "must be an integer") if n3_3t.present?  && n3_3t  !~ /^\d+$/
    self.params_errors.add(:nui_3t, "must be an integer") if nui_3t.present? && nui_3t !~ /^\d+$/
    self.params_errors.add(:nui_3t, "must be supplied since -N3_3T is supplied.")          if   n3_3t.present? && ! nui_3t.present?
    self.params_errors.add(:n3_3t,  "must be supplied since -nuiteration_3T is supplied.") if ! n3_3t.present? &&   nui_3t.present?

    ""
  end

  def final_task_list #:nodoc:
    params       = self.params

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
        task = self.dup # not .clone, as of Rails 3.1.10
        task.params[:interface_userfile_ids] = [ id ]
        task_list << task
      end
    end

    # Adjust output_name foreach task
    task_list.each do |task|

      ids            = task.params[:interface_userfile_ids]
      userfile_names = Userfile.find(ids).map &:name
      input_name     = userfile_names[0]

      # Verify output_name
      local_output_name   = task.params[:output_name]
      if local_output_name.blank?
        local_output_name = input_name.split(/\./)[0]
        task.params[:output_name] = local_output_name
      end

      # Adjust description
      task.description  = (task.description.presence || "").strip
      task.description  = "Recon-all on #{userfile_names.size} files" if task.description.blank? && userfile_names.size > 3
      task.description += "\n\n" if task.description.present?
      task.description += userfile_names.join(", ") if userfile_names.size <= 3
    end

    task_list
  end

  def self.pretty_params_names #:nodoc:
    { :output_name => 'Output name', :multiple_subjects => "Multiple subjects",
      :n3_3t  => "N3-3T",
      :nui_3t => "nuiterations-3T",
    }
  end

  def untouchable_params_attributes #:nodoc:
    { :outfile_id => true, :subject_id => true }
  end

end

