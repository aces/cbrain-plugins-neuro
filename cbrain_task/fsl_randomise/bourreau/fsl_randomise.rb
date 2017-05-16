
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

# A subclass of CbrainTask::ClusterTask to run FslRandomise.
class CbrainTask::FslRandomise < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def self.properties #:nodoc:
    super.merge :can_submit_new_tasks => true
  end

  def setup #:nodoc:
    params       = self.params

    unless params[:inputfile_id]
      self.addlog("No input file id provided")
      return false
    end

    params[:interface_userfile_ids].each do |id|
      inputfile    = Userfile.find(id)
      unless inputfile
        self.addlog("Could not find active record entry for file #{id}")
        return false
      end

      self.addlog("Synchronizing file #{inputfile.name}")
      inputfile.sync_to_cache
      cache_path = inputfile.cache_full_path

      safe_symlink(cache_path, "#{inputfile.name}")

      if id == params[:inputfile_id]
        self.results_data_provider_id ||= inputfile.data_provider_id
      end
    end

    return true
  end

  def cluster_commands #:nodoc:
    params       = self.params

    cmds = []

    n_option = params[:n_perm].blank? ? 5000 : params[:n_perm].to_i
    c_option = params[:cluster_based_tresh].to_f unless params[:cluster_based_tresh].blank?

    # Create randomise cmd
    # All files options
    inputfile = params[:inputfile_id].present?              ? Userfile.find(params[:inputfile_id]).name : ""
    mask      = params[:mask_id].present?                   ? Userfile.find(params[:mask_id]).name      : ""

    if params[:design_collection_id]
      mat      = params[:matrix_name]                 || ""
      mat_name = File.basename(params[:matrix_name])
      con      = params[:t_contrasts_name]            || ""
      fts      = params[:f_contrasts_name]            || ""
      grp      = params[:exchangeability_matrix_name] || ""
    else
      mat      = params[:matrix_id].present?                 ? Userfile.find(params[:matrix_id]).name                 : ""
      mat_name = mat
      con      = params[:t_contrasts_id].present?            ? Userfile.find(params[:t_contrasts_id]).name            : ""
      fts      = params[:f_contrasts_id].present?            ? Userfile.find(params[:f_contrasts_id]).name            : ""
      grp      = params[:exchangeability_matrix_id].present? ? Userfile.find(params[:exchangeability_matrix_id]).name : ""
    end

    # Create output name for -o option
    input_wo_ext   = inputfile.sub(/\..*/,"")
    matrix_wo_ext  = mat_name.sub(/\..*/,"")
    common_string  = "#{input_wo_ext}_"
    common_string += params[:output_name].blank? ?
                    "#{matrix_wo_ext}_#{n_option}"
                  : "#{params[:output_name].bash_escape}"

    # Output directory
    output_dir     = "Randomise_"
    output_dir    += common_string
    output_dir    += "_#{self.run_id}"


    params[:output_dir] = output_dir
    safe_mkdir(output_dir,0700)

    output_option = "#{output_dir}/#{common_string}"

    # FSL randomise_parallel execution commands

    # All boolean options
    with_T    = params[:carry_t]          == "1" ? "-T"    : ""
    with_T2   = params[:carry_t2]         == "1" ? "--T2"  : ""
    with_F    = params[:carry_f]          == "1" ? "-F"    : ""
    with_x    = params[:output_voxelwise] == "1" ? "-x"    : ""
    with_R    = params[:output_raw]       == "1" ? "-R"    : ""
    with_D    = params[:demean_data]      == "1" ? "-D"    : ""

    cmd   = "randomise_parallel"
    cmd  += " -i #{inputfile}"
    cmd  += " -o #{output_option}"
    cmd  += " -d #{mat}"
    cmd  += " -t #{con}"
    cmd  += " -f #{fts}"      if fts.present?
    cmd  += " -e #{grp}"      if grp.present?
    cmd  += " -c #{c_option}" if c_option.present?
    cmd  += " -n #{n_option}"
    cmd  += " -m #{mask}"     if mask.present?
    cmd  += " #{with_T} #{with_T2} #{with_F} #{with_x} #{with_R} #{with_D}"

    # Export of the CBRAIN_WORKDIR variable is used by
    # fsl_sub to determine if task has to be parallelized.
    # In our case, workdir is exported only for group analyses because
    # individual analyses will not be parallelized.
    # cmds << "export CBRAIN_WORKDIR=#{self.full_cluster_workdir} # To make fsl_sub submit tasks to CBRAIN"
    cmds << "export CBRAIN_SHARE_WD_TID=#{self.id}"
    cmds << "echo Starting Randomise"
    cmds << "echo running #{cmd}"
    cmds << cmd

    cmds
  end

  def save_results #:nodoc:
    params  = self.params

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    # Check STDERR
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /ERROR:/
      self.addlog("randomise task failed (see Standard Error)")
      return false
    end

    # File should contain something.
    output_dir = params[:output_dir]
    if !File.directory?(output_dir) || Dir["#{output_dir}/*"].empty?
      self.addlog("The cluster job did not produce our 'randomise' output?!?")
      return false
    end

    outputfile   =  safe_userfile_find_or_new(FileCollection, :name => output_dir )
    outputfile.save!
    outputfile.cache_copy_from_local_file(output_dir)

    self.addlog_to_userfiles_these_created_these( [ inputfile ], [ outputfile ] )
    self.addlog("Saved result file #{output_dir}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(inputfile)

    return true
  end

end

