
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

# A subclass of ClusterTask to run Nii2mnc.
class CbrainTask::Nii2mnc < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RecoverableTask
  include RestartableTask

  def setup #:nodoc:
    params       = self.params
    file_ids     = params[:interface_userfile_ids] || []
    cb_error "Expected a single NIfTY file id." unless file_ids.size == 1
    id           = file_ids[0]
    u            = Userfile.find(id)
    u.sync_to_cache
    safe_symlink(u.cache_full_path,u.cache_full_path.basename)
    self.results_data_provider_id ||= u.data_provider_id
    true
  end

  def job_walltime_estimate #:nodoc:
    1.hours
  end

  def cluster_commands #:nodoc:
    params       = self.params
    file_ids     = params[:interface_userfile_ids] || []
    id           = file_ids[0]
    u            = Userfile.find(id)
    basename     = u.cache_full_path.basename.to_s
    mincbase     = basename.sub(/\.nii$/i,"")
    mincbase    += ".mnc"
    params[:mincbase] = mincbase

    # Ignore some option for some version
    options_to_ignore = self.identify_options_to_ignore()

    voxel_type   = params[:voxel_type]        || ""
    cb_error "Unexpected voxel type"     if voxel_type !~ /^(byte|short|int|float|double|default)$/

    int_sign     = params[:voxel_int_signity] || ""
    cb_error "Unexpected voxel int sign" if int_sign   !~ /^(signed|unsigned|default)$/

    if !options_to_ignore.has_key?(:space_ordering)
      order        = params[:space_ordering]  || ""
      cb_error "Unexpected space ordering" if order    !~ /^(sagittal|transverse|coronal|xyz|yxz|zxy|default)$/
    end

    command  = "nii2mnc"
    command += " -#{voxel_type}" if voxel_type != "default"
    command += " -#{int_sign}"   if voxel_type =~ /^(short|word|int)$/ && int_sign != "default"

    command += " -noscanrange"   if params[:noscan] == "1" && !options_to_ignore.has_key?(:noscan)
    command += " -#{order}"      if order != "default"     if !options_to_ignore.has_key?(:space_ordering)

    flip_order = params[:flip_order]                       if !options_to_ignore.has_key?(:flip_order) # will check for nil later on

    # Compatibility adjustment with old tasks which used :flipx etc.
    # instead of :flip_order
    if flip_order.nil?  # not blank, NIL! It is important as "" is acceptable for flip_order
      flip_order = ""
      flip_order += "x" if params[:flipx].to_s == "1" # old arg API
      flip_order += "y" if params[:flipy].to_s == "1" # old arg API
      flip_order += "z" if params[:flipz].to_s == "1" # old arg API
    end

    # The new flip_order will place the command line options
    # for flipx etc. in a specific order.
    flip_order.downcase.each_char do |c|
      command += " -flipx" if c == 'x'
      command += " -flipy" if c == 'y'
      command += " -flipz" if c == 'z'
    end

    command += " #{basename} #{mincbase}"

    File.unlink(mincbase) rescue true

    commands = [
      "echo \"Command: #{command}\"",
      command
    ]

    if params[:rectify_cosines] == "1" && !options_to_ignore.has_key?(:rectify_cosines)
      commands += [
        "",
        "# Rectify cosines",
        "",
        "minc_modify_header -dinsert xspace:direction_cosines=1,0,0 #{mincbase}",
        "minc_modify_header -dinsert yspace:direction_cosines=0,1,0 #{mincbase}",
        "minc_modify_header -dinsert zspace:direction_cosines=0,0,1 #{mincbase}",
      ]
    end

    return commands
  end

  def save_results #:nodoc:
    params       = self.params

    mincbase     = params[:mincbase]
    unless File.exist?(mincbase)
      self.addlog("Could not found expected mincfile '#{mincbase}'.")
      return false
    end

    mincfile = safe_userfile_find_or_new(MincFile,
      :name             => mincbase,
      :data_provider_id => self.results_data_provider_id
    )
    mincfile.save!
    mincfile.cache_copy_from_local_file(mincbase)
    params[:output_mincfile_id] = mincfile.id

    file_ids     = params[:interface_userfile_ids] || []
    id = file_ids[0]
    u = Userfile.find(id)
    self.addlog("Created mincfile '#{mincbase}'")
    self.addlog_to_userfiles_these_created_these( [ u ], [ mincfile ] )
    mincfile.move_to_child_of(u)

    true
  end

end

