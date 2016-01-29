
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

# A subclass of PortalTask to run dcm2nii
class CbrainTask::Dcm2nii < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  task_properties  :use_parallelizer, :readonly_input_files

  def self.default_launch_args #:nodoc:
    {
      :anonymize => "1",
      :date      => "1",
      :events    => "1", 
      :gzip      => "1",
      :id        => "1",
      :protocol  => "1"
    }
  end
    
  def before_form #:nodoc:
    params = self.params

    file_ids = params[:interface_userfile_ids]
    file_ids.each do |col_id|
      col = Userfile.find(col_id)
      cb_error "This program can only run on FileCollections." unless col && col.is_a?(FileCollection)
    end
    
    ""
  end

  def final_task_list #:nodoc:
    params   = self.params
    
    file_ids = params[:interface_userfile_ids]
    task_list = []
    file_ids.each do |col_id|
      task = self.dup # not .clone, as of Rails 3.1.10
      task.params[:dicom_colid]            = col_id
      task.params[:interface_userfile_ids] = [ col_id ]

      # Adjust description
      task.description  = (task.description.presence || "").strip
      task.description += "\n\n" if task.description.present?
      task.description += Userfile.where(:id => col_id).raw_first_column(:name)[0].presence || ""

      task_list << task
    end
    
    task_list
  end
  

  def untouchable_params_attributes #:nodoc:
    { :dicom_colid => true, :created_niifile_ids => true, :orig_niifile_basenames => true }
  end

end

