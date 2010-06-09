
#
# CBRAIN Project
#
# Dcm2mnc model
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::PortalTask to launch dcm2mnc.
class CbrainTask::Dcm2mnc < CbrainTask::PortalTask

  Revision_info="$Id$"
  
  def before_form #:nodoc:
    params   = self.params
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
      task = self.clone
      task.params[:dicom_colid] = col_id
      task_list << task
    end
    task_list
  end

end

