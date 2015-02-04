
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# A subclass of CbrainTask to launch Nii2mnc.
class CbrainTask::Nii2mnc < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

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
    cb_error "Missing space ordering" if params[:space_ordering].blank?    && !self.tool_config.is_at_least_version("2.0.0")
    cb_error "Missing voxel int sign" if params[:voxel_int_signity].blank? && params[:voxel_type] =~ /^(byte|short|int)$/
    ""
  end

  def final_task_list #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids] || []

    task_list = []
    ids.each do |id|
      task    = self.dup # not .clone, as of Rails 3.1.10
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

