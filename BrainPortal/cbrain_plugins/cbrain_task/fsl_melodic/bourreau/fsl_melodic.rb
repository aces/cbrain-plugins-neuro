
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
    1.hours
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

    # modify design files according to local context (paths)
    modified_design_file=Tempfile.new(["design",".fsf"],".").path
 
    sed_command = 'sed s/^set\ feat_files.*/\#\ LINE\ REMOVED\ BY\ CBRAIN/g '"#{design_file}"' | sed s/^set\ highres_files.*/\#\ LINE\ REMOVED\ BY\ CBRAIN/g | sed s/^set\ fmri\(outputdir\)/\#\ LINE\ REMOVED\ BY\ CBRAIN/g | sed s/^set\ fmri\(multiple\)/\#\ LINE\ REMOVED\ BY\\ CBRAIN/g | sed s,\"\.*/data/standard,\"${FSLDIR}/data/standard,g'" > #{modified_design_file}"
    cmds << sed_command

    cmds << "echo \"#LINES ADDED BY CBRAIN\" >> #{modified_design_file} \n"   
    cmds << "echo \"set feat_files\(1\) \\\"#{functional_file}\\\"\" >> #{modified_design_file}\n"
    cmds << "echo \"set highres_files\(1\) \\\"#{structural_file}\\\"\" >> #{modified_design_file}\n" unless self.params[:structural_file_id].blank?
    cmds << "echo \"set fmri\(outputdir\) \\\"#{output}\\\"\" >> #{modified_design_file}\n"
    cmds << "echo \"set fmri\(multiple\) 1\" >> #{modified_design_file}\n"

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

    functional_file_id = params[:functional_file_id].to_i
    structural_file_id = params[:structural_file_id].to_i

    functional_file    = Userfile.find(functional_file_id)
    structural_file    = Userfile.find(structural_file_id)

    functional_name = functional_file.name.sub(".gz","").sub(".nii","")
    
    outputname      = "#{params[:output_dir_name]}.ica"
    outputname_new      = "#{functional_name}-#{outputname}"
    raise "Cannot rename output file" unless File.rename(outputname,outputname_new)

    outputfile      =  safe_userfile_find_or_new(FslMelodicOutput, :name => outputname_new)
    outputfile.save!
    outputfile.cache_copy_from_local_file(outputname_new)
    
    self.addlog_to_userfiles_these_created_these( [ functional_file,structural_file ], [ outputfile ] )
    self.addlog("Saved result file #{params[:output_dir_name]}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(functional_file)

    true
  end

end


