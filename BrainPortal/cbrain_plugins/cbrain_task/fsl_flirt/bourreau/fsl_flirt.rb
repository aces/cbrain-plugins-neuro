
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

# A subclass of ClusterTask to run FslFlirt.
#
# Original author: Natacha Beck
class CbrainTask::FslFlirt < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

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

    self.addlog("End setup !")
    true
  end

  def job_walltime_estimate #:nodoc:
    (0.5 * params[:interface_userfile_ids].count).hours
  end
  
  def cluster_commands #:nodoc:
    params       = self.params

    self.addlog("cluster_commands")
    
    input_name     = Userfile.find(params[:in].to_i).name
    reference_name = Userfile.find(params[:ref].to_i).name
    output_name    = params[:out].presence  || "Flirt-#{self.run_id}"
    matrice_name   = "#{output_name}.mat"
    output_name   += ".nii.gz" if output_name !~ /.nii.gz$/
    bins           = params[:bins]
    cost           = params[:cost]
    searchx        = "#{params[:searchx_min]} #{params[:searchx_max]}"
    searchy        = "#{params[:searchy_min]} #{params[:searchy_max]}"
    searchz        = "#{params[:searchz_min]} #{params[:searchz_max]}"
    dof            = params[:dof]
    interp         = params[:interp]

    flirt_cmd = "flirt -in #{input_name} -ref #{reference_name} -out #{output_name} -omat #{matrice_name} -bins #{bins} -cost #{cost}
    -searchx #{searchx} -searchy #{searchy} -searchz #{searchz} -dof #{dof} -interp #{interp}"

    self.addlog("flirt_cmd '#{flirt_cmd}'")
    
    [
     "echo \"\";echo Starting Flirt",
     "echo Command: #{flirt_cmd}",
     "#{flirt_cmd}"
    ]
  end
  
  def save_results #:nodoc:
    params       = self.params
    output_name  = params[:out].presence  || "Flirt-#{self.run_id}"
    matrice_name = "#{output_name}.mat"
    output_name += ".nii.gz" if output_name !~ /.nii.gz$/

    cb_error("Sorry, but the output name provided contains some unacceptable characters.") unless Userfile.is_legal_filename?(output_name)

    input_file = Userfile.find(params[:in])
    self.results_data_provider_id ||= input_file.data_provider_id

    # Verify if flirt exited without error.
    stdout = File.read(self.stdout_cluster_filename) rescue ""
    if stdout =~ /ERROR:/
      self.addlog("Flirt exit with error (see Standard Output)")
      return false
    end

    # Save output file
    outfile = safe_userfile_find_or_new(SingleFile,
      :name             => output_name,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file("#{self.full_cluster_workdir}/#{output_name}")

    self.addlog_to_userfiles_these_created_these( [ input_file ], [ outfile ] )
    self.addlog("Saved result file #{output_name}")
    
    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(input_file)

    # Save output matrice 
    outmatrice = safe_userfile_find_or_new(SingleFile,
      :name             => matrice_name,
      :data_provider_id => self.results_data_provider_id
    )
    outmatrice.save!
    outmatrice.cache_copy_from_local_file("#{self.full_cluster_workdir}/#{matrice_name}")

    self.addlog_to_userfiles_these_created_these( [ input_file ], [ outmatrice ] )
    self.addlog("Saved matrice file #{matrice_name}")
    
    params[:outmatrice_id] = outmatrice.id
    outmatrice.move_to_child_of(input_file)
    
    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in CbrainTask_Recovery_Restart.txt.

end

