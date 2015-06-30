
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
    return true
  end

  def job_walltime_estimate #:nodoc:
    return 1.hours
  end

  # Returns the conversion command from MINC to NIFTI.
  def mnc_to_nifti_command minc_file_name    
    raise "Error: this doesn't look like a MINC file" unless is_minc_file_name? minc_file_name
    nii_file_name = nifti_file_name minc_file_name
    # removes the minc file after conversion otherwise feat crashes...
    command = "mnc2nii -nii #{minc_file_name} `pwd`/#{File.basename nii_file_name}; if [ $? != 0 ]; then echo ERROR: cannot convert file #{minc_file_name} to nii ; exit 1 ; fi; rm -f #{minc_file_name}"
    return command
  end

  # Gets a NIFTI file name from a MINC file name. 
  def nifti_file_name minc_file_name
    raise "Error: this doesn't look like a MINC file" unless is_minc_file_name? minc_file_name
    name ="#{File.dirname(minc_file_name)}/#{File.basename(minc_file_name,".mnc")}" 
    return "#{name}.nii"
  end

  # Tests if file name looks like a MINC file. 
  def is_minc_file_name? file_name
    return file_name.end_with? ".mnc"
  end

  # Returns an array containing the cache full name of the file converted to MINC
  # format, and the conversion command.
  def converted_file_name_and_command file_id
    file_name = "#{self.full_cluster_workdir}/#{Userfile.find(file_id).name}"    
    return [file_name,""] unless is_minc_file_name? file_name
    # file_name is a MINC file name
    return [ nifti_file_name(file_name) ,  mnc_to_nifti_command(file_name) ] 
  end
  
  def cluster_commands #:nodoc:
    params    = self.params

    cmds      = []
    
    # Convert minc files to nifti.
    functional_file , functional_conversion_command = converted_file_name_and_command params[:functional_file_id]   
    structural_file , structural_conversion_command = converted_file_name_and_command params[:structural_file_id]
    
    if functional_conversion_command != "" 
      cmds      << "echo File conversion to NIFTI"
      cmds      << functional_conversion_command
      params[:converted_functional_file_name] = functional_file
    end
    
    if structural_conversion_command != "" 
      cmds      << "echo File conversion to NIFTI"
      cmds      << structural_conversion_command
      params[:converted_structural_file_name] = structural_file
     end

    cmds      << "echo Starting melodic"
    
    # Create melodic cmd
    output  = (params[:output_name].eql? "") ? "melodic-#{self.run_id}" : "#{params[:output_name]}-#{self.run_id}"
    design_file_id = params[:design_file_id] || []
    design_file = Userfile.find(design_file_id).cache_full_path.to_s

    # modify design files according to local context (paths)
    modified_design_file=Tempfile.new(["design",".fsf"],".").path

    sed_command = 'sed s/^set\ feat_files.*/\#\ LINE\ REMOVED\ BY\ CBRAIN/g '"#{design_file}"' | sed s/^set\ highres_files.*/\#\ LINE\ REMOVED\ BY\ CBRAIN/g | sed s/^set\ fmri\(outputdir\)/\#\ LINE\ REMOVED\ BY\ CBRAIN/g | sed s/^set\ fmri\(multiple\)/\#\ LINE\ REMOVED\ BY\\ CBRAIN/g | sed s,\"\.*/data/standard,\"${FSLDIR}/data/standard,g'" > #{modified_design_file}"
    cmds << sed_command

    cmds << "echo \"#LINES ADDED BY CBRAIN\" >> #{modified_design_file} \n"
    cmds << "echo \"set feat_files\(1\) \\\"#{functional_file}\\\"\" >> #{modified_design_file}\n"
    cmds << "echo \"set highres_files\(1\) \\\"#{structural_file}\\\"\" >> #{modified_design_file}\n" unless self.params[:structural_file_id].blank?
    cmds << "echo \"set fmri\(outputdir\) \\\"#{output}\\\"\" >> #{modified_design_file}\n"
    cmds << "echo \"set fmri\(multiple\) 1\" >> #{modified_design_file}\n"

    cmd_melodic          = "fsl5.0-feat #{modified_design_file}"
    # separate the error check from cmd_melodic otherwise ERROR always shows in the stdout and all the jobs fail
    cmd_with_error_check = "#{cmd_melodic} ; if [ $? != 0 ]; then echo \"ERROR: melodic exited with a non-zero exit code!\"; fi " 
    
    cmds    << "echo running #{cmd_melodic.bash_escape}"
    cmds    << cmd_with_error_check

    params[:output_dir_name] = output

    return cmds

  end

  def save_results #:nodoc:
    params  = self.params
    # user_id = self.user_id

    functional_file_id = params[:functional_file_id].to_i
    structural_file_id = params[:structural_file_id].to_i

    functional_file    = Userfile.find(functional_file_id)
    structural_file    = Userfile.find(structural_file_id)

    functional_name    = functional_file.name.gsub(".gz","").gsub(".nii","").gsub(".mnc","")

    outputname         = "#{params[:output_dir_name]}.ica"
    outputname_new     = "#{functional_name}-#{outputname}"
    raise "Cannot rename output file" unless File.rename(outputname,outputname_new)

    # Save converted file if any
    functional_file = save_converted_file(params[:converted_functional_file_name],functional_file) unless params[:converted_functional_file_name].nil?
    structural_file = save_converted_file(params[:converted_structural_file_name],structural_file) unless params[:converted_structural_file_name].nil?
    
    # Save result file
    outputname_unique  = unique_file_name outputname_new
    outputfile         =  safe_userfile_find_or_new(FslMelodicOutput, :name => outputname_unique)
    outputfile.save!
    outputfile.cache_copy_from_local_file(outputname_new)
    self.addlog_to_userfiles_these_created_these( [ functional_file,structural_file ], [ outputfile ] )
    self.addlog("Saved result file #{params[:output_dir_name]}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(functional_file)
    
    # Verify if all tasks exited without error (do this after saving the files because important debug information is found in the melodic logs).
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
    
    
    return true
  end

  # Returns a file_name if there is no file named file_name. Returns a
  # unique file name based on file_name otherwise.
  def unique_file_name file_name
    count = 0
    name  = file_name
    while not Userfile.where(:name => name).empty?
      count += 1
      extname = File.extname(name)
      name = "#{File.basename(name,extname)}-#{count}#{extname}"
    end
    return name
  end
  
  # Saves and returns converted file.
  def save_converted_file converted_file_name,parent_file
    output_file_name = File.basename(converted_file_name)
    self.addlog("Saving result file #{output_file_name}")
    converted_file = safe_userfile_find_or_new(NiftiFile, :name => unique_file_name(output_file_name))
    converted_file.save!
    converted_file.cache_copy_from_local_file(output_file_name)
    self.addlog_to_userfiles_these_created_these( [ parent_file ], [ converted_file ] )
    self.addlog("Saved result file #{converted_file.name}")
    converted_file.move_to_child_of(parent_file)
    return converted_file
  end
end


