
#
# CBRAIN Project
#
# CbrainTask::CivetQc model
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of PortalTask to launch civet_qc.
class CbrainTask::CivetQc < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.properties #:nodoc:
    { :no_presets => true }
  end

  def before_form #:nodoc:

    params   = self.params
    file_ids = params[:interface_userfile_ids]

    file_ids.each do |id|
      civetstudy = Userfile.find(id)
      unless civetstudy.is_a?(CivetStudy)
        cb_error "This program must be launched on one or several CivetStudy only."
      end
    end

    ""
  end

  def final_task_list #:nodoc:
    params   = self.params
    file_ids = params[:interface_userfile_ids]

    task_list = []

    file_ids.each do |id|
      civetstudy = CivetStudy.find(id)
      task = self.clone
      task.description ||= civetstudy.name
      task.params[:study_id]               = civetstudy.id
      task.params[:interface_userfile_ids] = [ civetstudy.id ]
      task_list << task
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :study_id => true, :dsid_names => true, :prefix => true }
  end

end

