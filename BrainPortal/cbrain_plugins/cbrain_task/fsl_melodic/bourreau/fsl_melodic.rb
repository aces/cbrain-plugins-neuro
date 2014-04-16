
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

# A subclass of ClusterTask to run FslMelodic
class CbrainTask::FslMelodic < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params       = self.params
    params[:task_file_ids].each do |inputfile_id|
      inputfile    = Userfile.find(inputfile_id)
      unless inputfile
        self.addlog("Could not find active record entry for file #{inputfile_id}")
        return false
      end
      self.addlog("Synchronizing file #{inputfile.name}")
      inputfile.sync_to_cache
      cache_path = inputfile.cache_full_path
      safe_symlink(cache_path, "#{inputfile.name}")
      self.results_data_provider_id ||= inputfile.data_provider_id
    end
    true
  end

  def job_walltime_estimate #:nodoc:
    4.hours
  end

  def cluster_commands #:nodoc:
    params    = self.params
    
    cmds      = []
    cmds      << "echo Starting melodic"

    # Create melodic cmd
    output  = (params[:output_name].eql? "") ? "melodic-#{self.run_id}" : "#{params[:output_name]}-#{self.run_id}"
    design_file_id = params[:design_file_id] || []
    design_file = Userfile.find(design_file_id).cache_full_path.to_s

    functional_file = Userfile.find(params[:functional_file_id]).cache_full_path.to_s
    structural_file = Userfile.find(params[:structural_file_id]).cache_full_path.to_s

    # put data files into design file
    modified_design_file=Tempfile.new(["design",".fsf"],".").path
    sed_command = 'sed s/^set\ feat_files.*/\#\ LINE\ REMOVED\ BY\ CBRAIN/g '"#{design_file}"' | sed s/^set\ highres_files.*/\#\ LINE\ REMOVED\ BY\ CBRAIN/g | sed s/^set\ fmri\(outputdir\)/\#\ LINE\ REMOVED\ BY\ CBRAIN/g'" > #{modified_design_file}"
    self.addlog(sed_command)
    raise "Cannot sed design file" unless system(sed_command)
    File.open(modified_design_file, 'a') {|f| f.write("#LINES ADDED BY CBRAIN\n"); f.write("set feat_files(1) \"#{functional_file}\"\n") ; f.write("set highres_files(1) \"#{structural_file}\"\n") unless self.params[:structural_file_id].blank? ; f.write("set fmri(outputdir) \"#{output}\"\n")}

    cmd_melodic = "feat #{modified_design_file}"
    cmds    << "echo running #{cmd_melodic.bash_escape}"
    cmds    << cmd_melodic
    
    params[:output_dir_name] = output
    
    cmds

  end
  
  def save_results #:nodoc:
    params  = self.params
    user_id = self.user_id

    # Verify if all tasks exited without error.
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /ERROR:/
      self.addlog("melodic task failed (see Standard Error)")
      return false
    end

    stdout = File.read(self.stdout_cluster_filename) rescue ""
    if stdout =~ /ERROR:/
      self.addlog("melodic task failed (see Standard Output)")
      return false
    end

    outputfile =  safe_userfile_find_or_new(FslMelodicOutput, :name => params[:output_dir_name])
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


