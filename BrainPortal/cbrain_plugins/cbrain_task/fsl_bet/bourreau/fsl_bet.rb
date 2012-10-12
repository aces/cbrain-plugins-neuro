
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

# A subclass of ClusterTask to run FslBet.
class CbrainTask::FslBet < ClusterTask

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

    true
  end

  def job_walltime_estimate #:nodoc:
    (0.1 * params[:interface_userfile_ids].count).hours
  end

  def cluster_commands #:nodoc:
    params    = self.params
    f_option  = params[:fractional_intensity].blank? ? 0.5 : params[:fractional_intensity].to_f
    g_option  = params[:vertical_gradient].blank?    ? 0.0 : params[:vertical_gradient].to_f 

    cmds      = []
    cmds      << "echo Starting BET"

    # Create bet cmd
    inputfile_id  = params[:inputfile_id] || []
    inputfile     = Userfile.find(inputfile_id)

    task_work     = self.full_cluster_workdir
    
    output  = inputfile.name
    output  = output =~ /(\..+)/ ? output.sub( /(\..+)/ , "_brain-#{self.run_id}#{$1}") : "#{output}_brain-#{self.run_id}" 
    output << ".gz"

    cmd_bet = "bet #{self.full_cluster_workdir}/#{inputfile.name} #{output} -f #{f_option} -g #{g_option}"
    cmds    << "echo running #{cmd_bet}"
    cmds    << cmd_bet
    
    params[:output_name] = output
    
    cmds
  end
  
  def save_results #:nodoc:
    params  = self.params
    user_id = self.user_id

    # Verify if all bet exit without error.
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /ERROR:/
      self.addlog("Bet failed (see Standard Error)")
      return false
    end

    stdout = File.read(self.stdout_cluster_filename) rescue ""
    if stdout =~ /ERROR:/
      self.addlog("Bet failed (see Standard Output)")
      return false
    end

    output_name  = params[:output_name]
    unless File.exists?(output_name)
      self.addlog("The cluster job did not produce our 'bet' output?!?")
      return false
    end

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)
    
    outputfile =  safe_userfile_find_or_new(NiftiFile, :name => output_name )
    outputfile.save!
    outputfile.cache_copy_from_local_file(output_name)

    self.addlog_to_userfiles_these_created_these( [ inputfile ], [ outputfile ] )
    self.addlog("Saved result file #{output_name}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(inputfile)

    true
  end

end

