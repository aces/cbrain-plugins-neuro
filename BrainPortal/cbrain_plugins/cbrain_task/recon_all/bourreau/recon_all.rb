
#
# CBRAIN Project
#
# ClusterTask Model Recon-all 
#
# Original author: Natacha Beck
#
# $Id$
#

# A subclass of ClusterTask to run Recon-all of FreeSurfer.
class CbrainTask::ReconAll < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params     = self.params
    
    self.safe_mkdir("input_minc")
    
    file_ids  = params[:interface_userfile_ids] || []
    
    mgzfiles = Userfile.find_all_by_id(file_ids)
    mgzfiles.each do |mgzfile|            
      self.addlog("Preparing input file '#{mgzfile.name}'")
      mgzfile.sync_to_cache
      cache_path = mgzfile.cache_full_path
      self.safe_symlink(cache_path, "input_minc/#{mgzfile.name}")
    end
    
    true
  end

  def job_walltime_estimate #:nodoc:
    36.hours
  end

  def cluster_commands #:nodoc:
    params       = self.params
    subject_name = params[:subject_name]

    file_ids     = params[:interface_userfile_ids] || []
    mgzfiles     = Userfile.find_all_by_id(file_ids)
    
    basenames    = mgzfiles.map &:name
    dash_i       = ""
    basenames.each { |name| dash_i += " -i input_minc/#{name}" }
    subject_name ||= basenames[0]  # should never happen

    # Check output_name and subject_name if not valid create one valid 
    task_work     = self.full_cluster_workdir
    cb_error("Sorry, but the subject name provided contains some unacceptable characters.") unless is_legal_subject_name?(subject_name)
    
    relative_subject_path = subject_name
    absolute_subject_path = "#{task_work}/#{relative_subject_path}"
    FileUtils.rm_rf(relative_subject_path)
    
    with_qcache    = params[:with_qcache].to_i == 1 ? "-qcache" : "";
    
    recon_all_command = "recon-all #{with_qcache} -sd #{task_work} #{dash_i} -subjid #{absolute_subject_path} -all"

    [
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting Recon-all",
      "echo Command: #{recon_all_command}",
      "#{recon_all_command}"
    ]
  end
  
  def save_results #:nodoc:
    params       = self.params
    subject_name = params[:subject_name].presence || "Subject"    
    output_name  = params[:output_name].presence  || "ReconAllOutput"
    
    cb_error("Sorry, but the subject name provided contains some unacceptable characters.") unless is_legal_subject_name?(subject_name)
    
    file_ids = params[:interface_userfile_ids] || []
    mgzfiles = Userfile.find_all_by_id(file_ids)
    
    self.results_data_provider_id ||= mgzfiles[0].data_provider_id

    # Verify if recon-all exit without error.
    stdout = File.read(self.stdout_cluster_filename) rescue ""
    if stdout !~ /recon-all .+ finished without error at/
      self.addlog("recon-all exit with error (see Standard Output)")
      return false
    end

    output_name  += "-#{self.run_id}"
    outfile = safe_userfile_find_or_new(ReconAllOutput,
      :name             => output_name,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file("#{self.full_cluster_workdir}/#{subject_name}")

    self.addlog_to_userfiles_these_created_these( [ mgzfiles ], [ outfile ] ) if mgzfiles
    self.addlog("Saved result file #{output_name}")
    
    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(mgzfiles[0]) if mgzfiles

    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in CbrainTask_Recovery_Restart.txt.

end

