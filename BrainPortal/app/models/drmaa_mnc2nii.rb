
#
# CBRAIN Project
#
# DrmaaMnc2nii model as ActiveResource
#
# Original author: 
#
# $Id: model.rb 211 2009-05-20 18:52:02Z tsherif $
#

class DrmaaMnc2nii < DrmaaTask

  Revision_info="$Id: model.rb 211 2009-05-20 18:52:02Z tsherif $"

  #########################################################################
  #This method should indicate whether or not mnc2nii requires 
  # arguments in order to run. If so the tasks/new view will be rendered
  # before the mnc2nii job is sent to the cluster.
  #########################################################################
  def self.has_args?
    true
  end
  
  #########################################################################
  #This method should return a hash containing the default arguments for
  # mnc2nii. These can be used to set up the tasks/new form.
  #If an exception is raised here it will cause a redirect to the 
  # userfiles index page where the exception message will be displayed.
  #########################################################################
  def self.get_default_args(params = {})
    {}
  end

  #########################################################################
  #This method actually launches the mnc2nii job on the cluster, 
  # and returns the flash message to be displayed.
  #If an exception is raised here it will cause a redirect to the 
  # tasks/new page for mnc2nii where the exception message will be 
  # displayed.
  #########################################################################
  def self.launch(params)
    flash = "Flash[:notice] message."
    file_ids = params[:file_ids]
    data_type =  params[:data_type]
    file_format =  params[:file_format]
     
     file_ids.each do |id|
       userfile = Userfile.find(id, :include  => :user)
       task = DrmaaMnc2nii.new
       task.user_id = userfile.user.id
       task.params = { :mincfile_id => id, :data_type => data_type, :file_format => file_format }
       task.save
       flash += "Started DrmaaMnc2nii on file '#{userfile.name}'.\n"
     end
  end
end

