
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
    cb_error "This program can only run on a single FileCollection." if file_ids.size > 1
    col_id   = file_ids[0]
    col      = Userfile.find(col_id)
    cb_error "Error: no collection found for id '#{col_id}'" unless col && col.is_a?(FileCollection)
    ""
  end
    
  def after_form #:nodoc:
    params   = self.params
    file_ids = params[:interface_userfile_ids]
    col_id   = file_ids[0]
    params[:dicom_colid] = col_id
    ""
  end

end

