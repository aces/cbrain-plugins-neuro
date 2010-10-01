
#
# CBRAIN Project
#
# PortalTask model Nii2mnc
#
# Original author: 
#
# $Id$
#

# A subclass of CbrainTask to launch Nii2mnc.
class CbrainTask::Nii2mnc < PortalTask

  Revision_info="$Id$"

  def self.default_launch_args #:nodoc:
    {
    :voxel_type          => "",    # byte, short, int, float, double, default
    :voxel_int_signity   => "",    # signed, unsigned, default
    :noscan              => 0,     # -noscanrange
    :space_ordering      => "",    # transverse, sagittal, coronal, xyz, zxy, yxz, default
    :flipx               => 0,     # -flipx
    :flipy               => 0,     # -flipy
    :flipz               => 0,     # -flipz
    :rectify_cosines     => 0,     # run minc_modify_header -dinsert xspace:direction_cosines=1,0,0 (y and z too)
    }
  end
  
  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids]
    ids.each do |id|
      u = Userfile.find(id)
      cb_error "Error: '#{u.name}' does not seem to be a single file." unless u.is_a?(SingleFile)
    end
    ""
  end

  def after_form #:nodoc:
    params = self.params
    cb_error "Missing voxel type"     if params[:voxel_type].blank?
    cb_error "Missing space ordering" if params[:space_ordering].blank?
    cb_error "Missing voxel int sign" if params[:voxel_int_signity].blank? && params[:voxel_type] =~ /^(byte|short|int)$/
    ""
  end

  def final_task_list #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids] || []

    task_list = []
    ids.each do |id|
      task    = self.clone
      tparams = task.params
      tparams[:interface_userfile_ids] = [ id ]
      task_list << task
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :output_mincfile_id => true, :mincbase => true }
  end

end

