
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

# A subclass of ClusterTask to run Recon-all of FreeSurfer.
#
# Original author: Natacha Beck
class CbrainTask::ReconAll < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    self.safe_mkdir("input")
    
    file_ids  = params[:interface_userfile_ids] || []
    
    files = Userfile.find_all_by_id(file_ids)
    files.each do |file|            
      self.addlog("Preparing input file '#{file.name}'")
      file.sync_to_cache
      if file.is_a?(MincFile)
        if file.which_minc_version != :minc1
          self.addlog("Recon-all can only run on MINC1.")
          return false
        end
      end
      cache_path = file.cache_full_path
      self.safe_symlink(cache_path, "input/#{file.name}")
    end
    
    true
  end

  def job_walltime_estimate #:nodoc:
    36.hours
  end

  def cluster_commands #:nodoc:
    params       = self.params
    
    subject_name = params[:subject_name]
    to_recover   = params.delete(:to_recover)

    # Check output_name and subject_name if not valid create one valid 
    cb_error("Sorry, but the subject name '#{subject_name}' provided contains some unacceptable characters.") unless is_legal_subject_name?(subject_name)

    # Command creation
    if !to_recover  # NORMAL EXECUTION MODE
      FileUtils.rm_rf(subject_name)
      file_ids     = params[:interface_userfile_ids] || []
      files        = Userfile.find_all_by_id(file_ids)
      dash_i       = ""
      files.map { |f| dash_i += " -i input/#{f.name}" }
      
      with_qcache    = params[:with_qcache] == "1" ? "-qcache"  : ""
      with_mprage    = params[:with_mprage] == "1" ? "-mprage"  : ""
      all            = "-all"
      subj_opt       = "-subjid"
      message        = "Starting Recon-all cross-sectional"
    else # RECOVER FROM FAILURE MODE
      dash_i         = ""
      with_qcache    = ""
      with_mprage    = ""
      all            = "-make all"
      subj_opt       = "-s"
      message        = "Recovering Recon-all cross-sectional"
    end
    
    recon_all_command = "recon-all #{with_qcache} #{with_mprage} -sd . #{dash_i} #{subj_opt} #{subject_name} #{all}"

    [
      "echo #{message}",
      "echo Command: #{recon_all_command}",
      recon_all_command
    ]
    
  end

  def save_results #:nodoc:
    params       = self.params

    subject_name = params[:subject_name]
    output_name  = params[:output_name]

    cb_error("Sorry, but the subject name provided contains some unacceptable characters.") unless is_legal_subject_name?(subject_name)

    # Define dp 
    file_ids = params[:interface_userfile_ids] || []
    files = Userfile.find_all_by_id(file_ids)
    self.results_data_provider_id ||= files[0].data_provider_id

    # Check for error
    list_of_error_dir = []
    log_file          = "#{subject_name}/scripts/recon-all.log"
    if !log_file_contains(log_file, /recon-all .+ finished without error at/) 
      self.addlog("Recon-all exited with errors. See Standard Output.")
      return false
    end

    # Create and save outfile
    output_name  += "-#{self.run_id}"
    outfile = safe_userfile_find_or_new(ReconAllCrossSectionalOutput,
      :name             => output_name,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file(subject_name)

    self.addlog_to_userfiles_these_created_these( files , [ outfile ] )
    self.addlog("Saved result file #{output_name}")

    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(files[0])

    true
  end
 
  # Error-recovery and restarting methods described
  def recover_from_cluster_failure #:nodoc:
    params       = self.params
    
    subject_name = params[:subject_name]

    # Remove IsRunning file
    files = Dir.glob("#{subject_name}/scripts/IsRunning.*" )
    files.each do |file|
      FileUtils.rm_rf(file)
    end
    
    params[:to_recover] = "yes"
    true
  end

  private

  def log_file_contains(file, grep_regex) #:nodoc:
    return false unless File.exist?(file)
    file_contain = File.read(file)
    file_contain =~ grep_regex
  end
  
end
