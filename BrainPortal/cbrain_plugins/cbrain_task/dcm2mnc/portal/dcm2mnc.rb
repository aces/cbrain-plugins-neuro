
#
# CBRAIN Project
#
# Dcm2mnc model
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of PortalTask to launch dcm2mnc.
class CbrainTask::Dcm2mnc < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.properties #:nodoc:
    { :no_presets => true, :use_parallelizer => true }
  end
  
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
      task.params[:dicom_colid]            = col_id
      task.params[:interface_userfile_ids] = [ col_id ]
      task_list << task
    end
    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :dicom_colid => true, :created_mincfile_ids => true, :orig_mincfile_basenames => true }
  end

end

