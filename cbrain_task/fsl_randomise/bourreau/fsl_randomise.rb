
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

    n_option = params[:n_perm].blank? ? 5000 : params[:n_perm].to_i
    c_option = params[:cluster_based_tresh].blank? ? 0.01 : params[:vertical_gradient].to_f

    # Create randomise cmd
    # All files options
    inputfile = params[:inputfile_id].present?              ? Userfile.find(params[:inputfile_id]).name : ""
    mask      = params[:mask_id].present?                   ? Userfile.find(params[:mask_id]).name : ""
    mat       = params[:matrix_id].present?                 ? Userfile.find(params[:matrix_id]).name : ""
    con       = params[:t_contrasts_id].present?            ? Userfile.find(params[:t_contrasts_id]).name : ""
    fts       = params[:f_contrasts_id].present?            ? Userfile.find(params[:f_contrasts_id]).name : ""
    grp       = params[:exchangeability_matrix_id].present? ? Userfile.find(params[:exchangeability_matrix_id]).name : ""

    output_dir    = "Randomise-Out-#{self.run_id}"
    params[:output_dir] = output_dir
    safe_mkdir(output_dir,0700)

    # Create output name for -o option
    input_wo_ext   = inputfile.sub(/\..*/,"")
    output_option  = "#{output_dir}/"
    output_option += "#{input_wo_ext}"
    output_option += "_#{params[:output_name].bash_escape}" if params[:output_name]
    output_option += "_#{n_option}"

    # All boolean options
    with_T    = params[:carry_t]          == "1" ? "-T"  : ""
    with_F    = params[:carry_f]          == "1" ? "-F"  : ""
    with_x    = params[:output_voxelwise] == "1" ? "-x"  : ""
    with_R    = params[:output_raw]       == "1" ? "-R"  : ""

    cmd   = "randomise"
    cmd  += " -i #{inputfile}"
    cmd  += " -o #{output_option}"
    cmd  += " -d #{mat}"
    cmd  += " -t #{con}"
    cmd  += " -f #{fts}" if fts.present?
    cmd  += " -e #{grp}" if grp.present?
    cmd  += " -c #{c_option}"
    cmd  += " -n #{n_option}"
    cmd  += " -m #{mask}"
    cmd  += " #{with_T} #{with_F} #{with_x} #{with_R}"

    cmds = []
    cmds << "echo Starting Randomise"
    cmds << "echo running #{cmd}"
    cmds << cmd

    cmds
  end

  def save_results #:nodoc:
    params  = self.params

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    output_dir = params[:output_dir]
    unless File.directory?(output_dir)
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

