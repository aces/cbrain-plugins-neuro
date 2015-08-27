
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

# A subclass of ClusterTask to run FslFirst
class CbrainTask::FslFirst < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params       = self.params
    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    unless inputfile
      self.addlog("Could not find active record entry for file #{inputfile_id}")
      return false
    end

    inputfile.sync_to_cache
    cache_path = inputfile.cache_full_path
    safe_symlink(cache_path, "#{inputfile.name}")

    self.results_data_provider_id ||= inputfile.data_provider_id

    return true
  end

  def job_walltime_estimate #:nodoc:
    return (3 * params[:interface_userfile_ids].count).hours
  end

  def cluster_commands #:nodoc:
    params    = self.params

    cmds      = []
    cmds      << "echo Starting FIRST"

    # Create first cmd
    inputfile_id  = params[:inputfile_id] || []
    inputfile     = Userfile.find(inputfile_id)

    # task_work     = self.full_cluster_workdir


    output  = (params[:output_name].eql? "") ? "#{inputfile.name.split(/\./)[0]}-#{self.id}".bash_escape  : "#{inputfile.name.split(/\./)[0]}-#{params[:output_name]}-#{self.id}".bash_escape

    cmd_first = "run_first_all -i #{self.full_cluster_workdir}/#{inputfile.name} -o #{output} ; mkdir -p #{output} ; find ./ -maxdepth 1 -mindepth 1 -type f -name '#{output}*' -print0 | xargs -0 mv -t #{output}"
    cmds    << "echo running #{cmd_first.bash_escape}"
    cmds    << cmd_first

    params[:output_dir_name] = output

    return cmds
  end

  def save_results #:nodoc:
    params  = self.params
    # user_id = self.user_id

    # Verify if all tasks exited without error.
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /ERROR:/
      self.addlog("first task failed (see Standard Error)")
      return false
    end

    stdout = File.read(self.stdout_cluster_filename) rescue ""
    if stdout =~ /ERROR:/
      self.addlog("first task failed (see Standard Output)")
      return false
    end

    outputfile =  safe_userfile_find_or_new(FslFirstOutput, :name => params[:output_dir_name])
    outputfile.save!
    outputfile.cache_copy_from_local_file(params[:output_dir_name])

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    self.addlog_to_userfiles_these_created_these( [ inputfile ], [ outputfile ] )
    self.addlog("Saved result file #{params[:output_dir_name]}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(inputfile)

    true
  end

end

