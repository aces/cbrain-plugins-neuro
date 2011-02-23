
#
# CBRAIN Project
#
# Mnc2nii model
#
# Original author:Mathieu Desrosiers 
#
# $Id$
#

#A subclass of PortalTask to launch mnc2nii.
class CbrainTask::Mnc2nii < PortalTask

  Revision_info="$Id$"

  def self.properties #:nodoc:
    { :use_parallelizer => true }
  end

  def self.default_launch_args #:nodoc:
    {
      :voxel_type          => "",    # byte, short, int, float, double, default
      :voxel_int_signity   => "",    # signed, unsigned, default
      :file_format         => 'nii'
    }
  end

  def after_form #:nodoc:
    params = self.params
    cb_error "Missing voxel type"     if params[:voxel_type].blank?
    cb_error "Missing voxel int sign" if params[:voxel_int_signity].blank? && params[:voxel_type] =~ /^(byte|short|int)$/
    ""
  end

  def final_task_list #:nodoc:
    params             = self.params
    file_ids           = params[:interface_userfile_ids]
     
    task_list = []
    file_ids.each do |id|
      task = self.clone
      task.params[:mincfile_id]            = id
      task.params[:interface_userfile_ids] = [ id ]
      task_list << task
    end
    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :mincfile_id => true, :niifile_ids => true }
  end

end

