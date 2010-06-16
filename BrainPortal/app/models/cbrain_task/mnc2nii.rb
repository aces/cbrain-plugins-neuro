
#
# CBRAIN Project
#
# Mnc2nii model
#
# Original author:Mathieu Desrosiers 
#
# $Id$
#

#A subclass of CbrainTask::PortalTask to launch mnc2nii.
class CbrainTask::Mnc2nii < CbrainTask::PortalTask

  Revision_info="$Id$"

  def self.default_launch_args #:nodoc:
    {
      :data_type   => 'default',
      :file_format => 'nii'
    }
  end

  def final_task_list #:nodoc:
    params      = self.params
    file_ids    = params[:interface_userfile_ids]
    data_type   = params[:data_type]
    file_format = params[:file_format]
     
    tasklist = []
    file_ids.each do |id|
      task = self.clone
      task.params[:mincfile_id]            = id
      task.params[:interface_userfile_ids] = [ id ]
      task_list << task
    end
    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :mincfile_id => true }
  end

end

