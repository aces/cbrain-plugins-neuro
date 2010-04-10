
#
# CBRAIN Project
#
# DrmaaCivetQc model as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of DrmaaTask to launch drmaa_civet_qc.
class DrmaaCivetQc < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def self.has_args?
    true
  end
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil)
    {}
  end

  #See DrmaaTask.
  def self.launch(params) 
    flash = ""

    file_ids         = params[:file_ids]

    civetstudies = []
    file_ids.each do |id|
      civetstudy = Userfile.find(id, :include  => :user)
      unless civetstudy.is_a?(CivetStudy)
        return "This program must be launched on one or several CivetStudy only."
      end
      civetstudies << civetstudy
    end

    description = params[:description]
    description = nil if description.blank?

    civetstudies.each do |civetstudy|
      task = DrmaaCivetQc.new
      task.user_id     = params[:user_id]
      task.description = description || civetstudy.name
      task.params      = { :study_id => civetstudy.id }
      task.bourreau_id = params[:bourreau_id]
      task.save
      flash += "Started DrmaaCivetQc on CivetStudy '#{civetstudy.name}'.\n"
    end

    flash
  end
  
  #See DrmaaTask.
  def self.save_options(params)
    {}
  end

end

