
#
# CBRAIN Project
#
# ClusterTask Model Nii2mnc
#
# Original author:
#
# $Id$
#

# A subclass of ClusterTask to run Nii2mnc.
class CbrainTask::Nii2mnc < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RecoverableTask
  include RestartableTask

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params
    file_ids     = params[:interface_userfile_ids] || []
    cb_error "Expected a single NIfTY file id." unless file_ids.size == 1
    id = file_ids[0]
    u = Userfile.find(id)
    u.sync_to_cache
    safe_symlink(u.cache_full_path,u.cache_full_path.basename)
    self.results_data_provider_id ||= u.data_provider_id
    true
  end

  def job_walltime_estimate #:nodoc:
    1.hours
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params       = self.params
    file_ids     = params[:interface_userfile_ids] || []
    id = file_ids[0]
    u = Userfile.find(id)
    basename = u.cache_full_path.basename.to_s
    mincbase = basename.sub(/\.nii$/i,"")
    mincbase += ".mnc"
    params[:mincbase] = mincbase

    voxel_type   = params[:voxel_type]        || ""
    int_sign     = params[:voxel_int_signity] || ""
    order        = params[:space_ordering]    || ""

    cb_error "Unexpected voxel type"     if voxel_type !~ /^(byte|short|int|float|double|default)$/
    cb_error "Unexpected voxel int sign" if int_sign   !~ /^(signed|unsigned|default)$/
    cb_error "Unexpected space ordering" if order      !~ /^(sagittal|transverse|coronal|xyz|yxz|zxy|default)$/

    command  = "nii2mnc"
    command += " -#{voxel_type}" if voxel_type != "default"
    command += " -#{int_sign}"   if voxel_type =~ /^(short|word|int)$/ && int_sign != "default"
    command += " -noscanrange"   if params[:noscan] == "1"
    command += " -#{order}"      if order != "default"

    flip_order = params[:flip_order] # will check for nil later on

    # Compatibility adjustment with old tasks which used :flipx etc.
    # instead of :flip_order
    if flip_order.nil?  # not blank, NIL! It is important as "" is acceptable for flip_order
      flip_order = ""
      flip_order += "x" if params[:flipx].to_s == "1"   # old arg API
      flip_order += "y" if params[:flipy].to_s == "1"   # old arg API
      flip_order += "z" if params[:flipz].to_s == "1"   # old arg API
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

    if params[:rectify_cosines] == "1"
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
  
  # See CbrainTask.txt
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

