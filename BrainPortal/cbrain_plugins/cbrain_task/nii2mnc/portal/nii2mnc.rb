
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

  after_find :after_find_update_flip_params

  def self.properties #:nodoc:
    { :use_parallelizer => true }
  end

  def self.default_launch_args #:nodoc:
    {
    :voxel_type          => "",    # byte, short, int, float, double, default
    :voxel_int_signity   => "",    # signed, unsigned, default
    :noscan              => 0,     # -noscanrange
    :space_ordering      => "",    # transverse, sagittal, coronal, xyz, zxy, yxz, default
    #:flipx               => 0,     # -flipx DEPRECATED
    #:flipy               => 0,     # -flipy DEPRECATED
    #:flipz               => 0,     # -flipz DEPRECATED
    :flip_order          => "",    # Order of -flip[xyz] options, one of "xyz", "xzy" etc etc.
    :rectify_cosines     => 0,     # run minc_modify_header -dinsert xspace:direction_cosines=1,0,0 (y and z too)
    }
  end
  
  # Updates the old flip options :flipx, :flipy and :flipz into the new :flip_order
  # when reloading an old task
  def after_find_update_flip_params #:nodoc:
    params = self.params
    return true if ! params
    return true unless params.has_key?(:flipx) || params.has_key?(:flipy) || params.has_key?(:flipz)
    if params[:flip_order].blank?
      params[:flip_order] = ""
      params[:flip_order] += "x" if params[:flipx].to_s == "1"
      params[:flip_order] += "y" if params[:flipy].to_s == "1"
      params[:flip_order] += "z" if params[:flipz].to_s == "1"
    end
    params.delete(:flipx)
    params.delete(:flipy)
    params.delete(:flipz)
    true
  end

  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids]
    ids.each do |id|
      u = Userfile.find(id) rescue nil
      cb_error "Error: the input file for this task doesn't exist anymore." unless u
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

