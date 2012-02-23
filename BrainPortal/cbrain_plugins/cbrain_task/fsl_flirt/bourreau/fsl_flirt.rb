
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
    params            = self.params

    run_subdir        = "Flirt-Out-#{self.run_id}/"
    safe_mkdir(run_subdir,0700)
                                                          
    ref_id            = params[:ref]
    reference_name    = Userfile.find(ref_id.to_i).name
    output_name       = run_subdir
    output_name      += params[:out].presence  || "Flirt"
    output_name.sub!(/\.nii(\.gz)?$/i, '') 
    bins              = params[:bins]
    cost              = params[:cost]
    searchx           = "#{params[:searchx_min]} #{params[:searchx_max]}"
    searchy           = "#{params[:searchy_min]} #{params[:searchy_max]}"
    searchz           = "#{params[:searchz_min]} #{params[:searchz_max]}"
    two_d             = params[:model].to_i == 2 ? "-2D" : ""
    dof               = params[:dof]
    interp            = params[:interp]
    input_to_ref_mode = true if params[:mode] == "input_ref"
    

    # create cmd array
    cmd = []
    cmd << "echo Starting Flirt"
    params[:output_list] = []
    file_ids           =  params[:interface_userfile_ids] || []
    remaining_file_ids = []
    # Treat input -> ref case
    if input_to_ref_mode
      input_id   = params[:in]
      input_name = Userfile.find(input_id.to_i).name
      flirt_cmd  = "flirt -in #{input_name} -ref #{reference_name} -out #{output_name} -omat #{output_name}.mat -bins #{bins} -cost #{cost} -searchrx #{searchx} -searchry #{searchy} -searchrz #{searchz} #{two_d} -dof #{dof} -interp #{interp}"
      cmd << "echo Command: #{flirt_cmd}"
      cmd << flirt_cmd
      params[:output_list] << output_name
      remaining_file_ids = file_ids - [input_id] - [ref_id]
    # Treat high -> low -> ref case  
    else
      # Treat high resolution file
      high_id   = params[:high]
      high_name = Userfile.find(high_id.to_i).name
      high_mat  = "#{output_name}1.mat"
      flirt_cmd = "flirt -in #{high_name} -ref #{reference_name} -omat #{high_mat} -bins #{bins} -cost #{cost} -searchrx #{searchx} -searchry #{searchy} -searchrz #{searchz} #{two_d} -dof #{dof}"
      cmd << "echo Command: #{flirt_cmd}"
      cmd << flirt_cmd
      params[:output_list] << high_mat
      # Treat low resolution file
      low_id    = params[:low]
      low_name  = Userfile.find(low_id.to_i).name
      low_mat   = "#{output_name}2.mat"
      flirt_cmd = "flirt -in #{low_name} -ref #{reference_name} -omat #{low_mat} -bins #{bins} -cost #{cost} -searchrx #{searchx} -searchry #{searchy} -searchrz #{searchz} #{two_d} -dof #{dof}"
      cmd << "echo Command: #{flirt_cmd}"
      cmd << flirt_cmd
      params[:output_list] << low_mat
      # Convert matrice
      gen_mat   = "#{output_name}.mat"
      conv_cmd  = "convert_xfm -concat #{high_mat} -omat #{gen_mat} #{low_mat}"
      cmd << "echo Command: #{conv_cmd}"
      cmd << conv_cmd
      params[:output_list] << gen_mat
      # flirt cmd
      flirt_cmd = "flirt -in #{low_name} -ref #{reference_name} -out #{output_name} -applyxfm -init #{gen_mat} -interp #{interp}"
      cmd << "echo Command: #{flirt_cmd}"
      cmd << flirt_cmd
      params[:output_list] << output_name
      remaining_file_ids = file_ids - [high_id] - [low_id] - [ref_id]
    end

    # Treat secondary image for both case
    params[:remainning_file_ids] = remaining_file_ids
    remaining_file_ids.each do |id|
      secondary_image_input  = secondary_image_no_ext = Userfile.find(id.to_i).name

      # Create secondary output name 
      secondary_image_no_ext.sub!(/\.nii(\.gz)?$/i, '') 
      secondary_output_name  = "#{output_name}_shadowreg_#{secondary_image_no_ext}" 

      # Create command
      secondary_cmd          = "flirt -in #{secondary_image_input} -ref #{reference_name} -out #{secondary_output_name} -applyxfm -init #{output_name}.mat -interp #{interp}"
      cmd << "echo Command: #{secondary_cmd}"
      cmd << secondary_cmd
      
      params[:output_list] << secondary_output_name
    end

    cmd
  end
  
  def save_results #:nodoc:
    params            = self.params
    run_subdir        = "Flirt-Out-#{self.run_id}"
    input_to_ref_mode = true if params[:mode] == "input_ref"
    
    output_name  = params[:out].presence  || "Flirt"
    cb_error("Sorry, but the output name provided contains some unacceptable characters.") unless Userfile.is_legal_filename?(output_name)

    if input_to_ref_mode 
      input_file = Userfile.find(params[:in])
    else
      input_file = Userfile.find(params[:high])
    end
    self.results_data_provider_id ||= input_file.data_provider_id
    
    # Verify if flirt exited without error. Check foreach output
    output_list  = params[:output_list]
    count_failed = 0
    output_list.each do |output|
      output = "#{output}.nii.gz" if output !~ /\.mat$/
      count_failed += 1  if !File.exist?(output)
    end

    if count_failed > 0
      self.addlog(" #{count_failed} on #{output_list.count} Flirt command failed (see Standard Error)")
      failed = params[:failed_restriction]
      self.addlog("failed_restriction #{failed}") 
      return false if (count_failed == output_list.count) || (params[:failed_restriction] == "1" && count_failed > 0)
    end

    # Save output files
    outfile = safe_userfile_find_or_new(FileCollection,
      :name             => run_subdir,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file("#{self.full_cluster_workdir}/#{run_subdir}")

    self.addlog_to_userfiles_these_created_these( [ input_file ], [ outfile ] )
    self.addlog("Saved result file #{output_name}")
    
    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(input_file)
    
    true
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in CbrainTask_Recovery_Restart.txt.

end

