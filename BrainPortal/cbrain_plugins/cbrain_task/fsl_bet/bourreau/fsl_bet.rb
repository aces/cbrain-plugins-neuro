
#
# CBRAIN Project
#
# ClusterTask Model FslBet
#
# Original author:
#
# $Id$
#

# A subclass of ClusterTask to run FslBet.
class CbrainTask::FslBet < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params
      
    file_ids  =  params[:interface_userfile_ids] || []
    
    files = Userfile.find_all_by_id(file_ids)
    files.each do |file|            
      self.addlog("Preparing input file '#{file.name}'")
      file.sync_to_cache
      cache_path = file.cache_full_path
      self.safe_symlink(cache_path, "#{file.name}")
    end
    
    true
  end

  def job_walltime_estimate #:nodoc:
    (0.1 * params[:interface_userfile_ids].count).hours
  end

  def cluster_commands #:nodoc:
    params       = self.params

    file_ids  = params[:interface_userfile_ids] || []
    files     = Userfile.find_all_by_id(file_ids)


    task_work = self.full_cluster_workdir
    f_option  = params[:fractional_intensity].empty? ? 0.5 : params[:fractional_intensity].to_f
    g_option  = params[:vertical_gradient].empty?    ? 0.0 : params[:vertical_gradient].to_f 

    cmds      = []
    cmds      << "echo Starting BET"
    outnames  = {} # input_id => output_name
    files.each do |file|
      output  = file.name
      output  = output =~ /(\..+)/ ? output.sub( /(\..+)/ , "_brain-#{self.run_id}#{$1}") : "#{output}_brain-#{self.run_id}" 
      outnames[file.id] = "#{output}"
      output  = "#{task_work}/#{output}"

      cmd     = "bet #{self.full_cluster_workdir}/#{file.name} #{output} -f #{f_option} -g #{g_option}"
      cmds    << "echo running #{cmd}"
      cmds    << cmd
    end
    params[:output_names] = outnames

    cmds 
  end
  
  # See CbrainTask.txt
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

    file_ids = params[:interface_userfile_ids] || []
    files    = Userfile.find_all_by_id(file_ids)

    outnames  = params[:output_names]

    files.each do |file|
      output_name = outnames[file.id]
      group_id    = Userfile.find(file.id).group_id

      unless File.exists?(output_name)
        self.addlog("The cluster job did not produce our 'bet' output?!?")
        return false
      end
      
      self.results_data_provider_id ||= file.data_provider_id

      output =  safe_userfile_find_or_new(SingleFile,
                  :user_id          => user_id,
                  :group_id         => group_id,
                  :data_provider_id => self.results_data_provider_id,
                  :name             => output_name
                )
      output.save!
      output.cache_copy_from_local_file(output_name)
      
      self.addlog_to_userfiles_these_created_these( [ file ], [ output ] )
      self.addlog("Saved result file #{output_name}")
      output.move_to_child_of(file)
    end

    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in CbrainTask_Recovery_Restart.txt.

end

