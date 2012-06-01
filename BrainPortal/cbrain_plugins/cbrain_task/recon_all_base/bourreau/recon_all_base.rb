
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

# A subclass of ClusterTask to run ReconAllBase.
#
# Original author: Natacha Beck
class CbrainTask::ReconAllBase < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params = self.params
    
    self.safe_mkdir("input")
    collection_ids  = params[:interface_userfile_ids] || []
    collections     = Userfile.find_all_by_id(collection_ids)
    collections.each do |collection|            
      self.addlog("Preparing input file '#{collection.name}'")
      collection.sync_to_cache
      cache_path = collection.cache_full_path
      self.safe_symlink(cache_path, "input/#{collection.name}")
    end
    
    true
  end

  def job_walltime_estimate #:nodoc:
    36.hours
  end
  
  def cluster_commands #:nodoc:
    params          = self.params
    base_name       = params[:base_name].presence || "Base"

    collection_ids  = params[:interface_userfile_ids] || []
    collections     = Userfile.find_all_by_id(collection_ids)

    basenames       = collections.map &:name
    tp_list         = ""
    basenames.each { |name| tp_list += " -tp #{name}" }

    # Check output_name and subject_name if not valid create one valid 
    task_work       = self.full_cluster_workdir
    cb_error("Sorry, but the subject name provided contains some unacceptable characters.") unless is_legal_base_name?(base_name)
    
    relative_base_path = base_name
    absolute_base_path = "#{task_work}/#{relative_base_path}"
    FileUtils.rm_rf(relative_base_path)

    recon_all_command = "recon-all -sd #{task_work}/input -base #{relative_base_path} #{tp_list} -all"
    
    [
      "echo Starting Recon-all -base",
      "echo Command: #{recon_all_command}",
      "#{recon_all_command}"
    ]
  end
  
  def save_results #:nodoc:
    params         = self.params
    base_name      = params[:base_name].presence || "Base"    
    
    cb_error("Sorry, but the subject name provided contains some unacceptable characters.") unless is_legal_base_name?(base_name)
    
    collection_ids = params[:interface_userfile_ids] || []
    collections    = Userfile.find_all_by_id(collection_ids)
    
    self.results_data_provider_id ||= collections[0].data_provider_id

    # Verify if recon-all exited without error.
    stdout         = File.read(self.stdout_cluster_filename) rescue ""
    if stdout !~ /recon-all .+ finished without error at/
      self.addlog("recon-all exit with error (see Standard Output)")
      return false
    end

    outfile_name = "#{base_name}-#{self.run_id}"
    outfile      = safe_userfile_find_or_new(ReconAllBaseOutput,
      :name             => base_name,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file("#{self.full_cluster_workdir}/input/#{base_name}")

    self.addlog_to_userfiles_these_created_these( [ collections ], [ outfile ] )
    self.addlog("Saved result file #{base_name}")
    
    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(collections[0])

    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in CbrainTask_Recovery_Restart.txt.

end

