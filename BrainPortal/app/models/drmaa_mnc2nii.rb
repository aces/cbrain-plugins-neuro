
#
# CBRAIN Project
#
# DrmaaMnc2nii model as ActiveResource
#
# Original author:Mathieu Desrosiers 
#
# $Id$
#

#A subclass of DrmaaTask to launch mnc2nii.
class DrmaaMnc2nii < DrmaaTask

  Revision_info="$Id$"

  #########################################################################
  #This method should indicate whether or not mnc2nii requires 
  # arguments in order to run. If so the tasks/new view will be rendered
  # before the mnc2nii job is sent to the cluster.
  #########################################################################
  
  #See DrmaaTask.
  def self.has_args? 
    true
  end
  
  #########################################################################
  #This method should return a hash containing the default arguments for
  # mnc2nii. These can be used to set up the tasks/new form.
  #If an exception is raised here it will cause a redirect to the 
  # userfiles index page where the exception message will be displayed.
  #########################################################################
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil) 
    {}
  end

  #########################################################################
  #This method actually launches the mnc2nii job on the cluster, 
  # and returns the flash message to be displayed.
  #If an exception is raised here it will cause a redirect to the 
  # tasks/new page for mnc2nii where the exception message will be 
  # displayed.
  #########################################################################
  
  #See DrmaaTask.
  def self.launch(params) 
    flash = "Flash[:notice] message."
    file_ids = params[:file_ids]
    data_type =  params[:data_type]
    file_format =  params[:file_format]
     
     file_ids.each do |id|
       userfile = Userfile.find(id, :include  => :user)
       task = DrmaaMnc2nii.new
       task.user_id = params[:user_id]
       task.description  = params[:description]
       task.params = { :mincfile_id => id, :data_type => data_type, :file_format => file_format }
       task.save
       userfile.addlog "Started Mnc2nii, task #{task.bname_tid}"

       flash += "Started DrmaaMnc2nii on file '#{userfile.name}'.\n"
     end
  end
end

