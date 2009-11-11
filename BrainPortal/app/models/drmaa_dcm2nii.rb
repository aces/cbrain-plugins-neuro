
#
# CBRAIN Project
#
# DrmaaDcm2nii model as ActiveResource
#
# Original author: 
#
# $Id: model.rb 342 2009-07-17 22:07:21Z tsherif $
#

#A subclass of DrmaaTask to launch dcm2nii.
class DrmaaDcm2nii < DrmaaTask

  Revision_info="$Id: model.rb 342 2009-07-17 22:07:21Z tsherif $"

  #########################################################################
  #This method should indicate whether or not dcm2nii requires 
  # arguments in order to run. If so the tasks/new view will be rendered
  # before the dcm2nii job is sent to the cluster.
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
  
  #See DrmaaTask.
  def self.has_args?
    true
  end
  
  #########################################################################
  #This method should return a hash containing the default arguments for
  # dcm2nii. These can be used to set up the tasks/new form.
  #The saved_args argument is the hash from the user preferences for 
  # DrmaaDcm2nii. It is the has created by the 
  # self.save_options method (see below).
  #If an exception is raised here it will cause a redirect to the 
  # userfiles index page where the exception message will be displayed.
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil)
    {}
  end

  #########################################################################
  #This method actually launches the dcm2nii job on the cluster, 
  # and returns the flash message to be displayed.
  #Default behaviour is to launch the job to the user's prefered cluster,
  # or if the latter is not set, to choose an available cluster at random.
  # You can select a specific cluster to launch to by setting the 
  # bourreau_id attribute on the DrmaaDcm2nii object (task.bourreau_id) 
  # explicitly.
  # If an exception is raised here, it will cause a redirect to one of the 
  # following pages:
  # 1. The argument input page for dcm2nii if the has_args? returns true.
  # 2. The userfiles index page if has_args? returns false.
  #
  # The exception message will be displayed to the user as 
  # a flash message after the redirect.
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
  
  #See DrmaaTask.
  def self.launch(params) 
    flash = "Flash[:notice] message."
    #Example (you can uncomment this and use it as a template):
    # file_ids = params[:file_ids]
    # 
    # file_ids.each do |id|
    #   userfile = Userfile.find(id, :include  => :user)
    #   task = DrmaaDcm2nii.new
    #   task.user_id = userfile.user.id
    #   task.params = { :mincfile_id => id }
    #   task.save
    #   
    #   flash += "Started DrmaaDcm2nii on file '#{userfile.name}'.\n"
    # end
    flash
  end
  
  #########################################################################
  #This method creates a hash of the options to be saved in the user's
  # preferences. It will be stored in:  
  # <user_preference>.other_options["DrmaaDcm2nii_options"]
  # This has is automatically passed to the self.get_default_args method
  # (see above) for each DrmaaDcm2nii creation request.
  #
  #NOTE: The comment below is for use by rdoc.
  #########################################################################
    
  #See DrmaaTask.
  def self.save_options(params)
    {}
  end
end

