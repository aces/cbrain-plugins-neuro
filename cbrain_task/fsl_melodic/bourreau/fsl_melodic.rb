
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
  
  def cluster_commands #:nodoc:
    
    params    = self.params
    
    # The list of bash commands to be executed. 
    cmds      = []
    
    # Converts minc files to nifti.
    functional_file , functional_conversion_command  = converted_file_name_and_command params[:functional_file_id]   
    structural_file , structural_conversion_command  = converted_file_name_and_command params[:structural_file_id]
    regstandard_file, regstandard_conversion_command = converted_file_name_and_command params[:regstandard_file_id] 
    
    if functional_conversion_command.present?
      cmds      << functional_conversion_command
      params[:converted_functional_file_name] = functional_file
    end
    
    if structural_conversion_command.present?
      cmds      << structural_conversion_command
      params[:converted_structural_file_name] = structural_file
    end
    
    if regstandard_conversion_command.present?
      cmds      << regstandard_conversion_command
      params[:converted_regstandard_file_name] = regstandard_file
    end

    # Finds a name for the modified design file. 
    modified_design_file_path = "design-cbrain.fsf"
    count = 1
    while File.exists? modified_design_file_path
      count += 1
      modified_design_file_path = "design-cbrain-#{count}.fsf"
    end
    
    # $HOME has to be replaced on the machine where the task is
    # executed, not on the Bourreau's machine
    cmds << "# echo Replacing '$HOME' with $HOME in the design file.\n"
    cmds << "echo Replacing '$HOME' with $HOME in the design file.\n"
    cmds << sed_design_file(modified_design_file_path,"\\\$HOME","$HOME")
    cmds << "\n"

    # Auto-corrected parameters. Auto-correction needs to be done on
    # the task node (i.e. in the task script), not on the Bourreau
    # host.  Otherwise, FSL needs to be installed on the Bourreau
    # node, which might not be the case.

    if params[:npts_auto] == "1"
      cmds << find_command("FSLNVOLS","fslnvols fsl5.0-fslnvols")
      cmds << "# Auto-corrects parameter fmri(npts)\n"
      cmds << "NPTS=`${FSLNVOLS} #{functional_file}`\n"
      cmds << "if [ $? != 0 ]\n"
      cmds << "then\n"
      cmds << "  echo ERROR: cannot auto-correct number of volumes in #{functional_file} '(fslnvols failed)'.\n"
      cmds << "  exit 1\n"
      cmds << "fi\n"
      cmds << "echo Auto-corrected number of volumes to ${NPTS}.\n"
      cmds << set_design_file_option(modified_design_file_path,"npts","${NPTS}")
    end

    
    if params[:tr_auto] == "1"
      cmds << find_command("FSLHD","fslhd fsl5.0-fslhd")
      cmds << "# Auto-corrects parameter fmri(tr)\n"
      cmds << "TR=`${FSLHD} #{functional_file} | awk '$1==\"pixdim4\" {print $2}'`\n"
      cmds << "if [ $? != 0 ]\n"
      cmds << "then\n"
      cmds << "  echo ERROR: cannot auto-correct TR in #{functional_file} '(fslhd failed)'.\n"
      cmds << "  exit 1\n"
      cmds << "fi\n"
      cmds << "echo Auto-corrected TR to ${TR}.\n"
      cmds << set_design_file_option(modified_design_file_path,"tr","${TR}")
    end
    
    # Updates path of the standard brain to the local path. 
    # $FSLDIR has to be replaced on the machine where the task is
    # executed, not on the Bourreau's machine.  In some installations
    # of FSL, e.g. Neurodebian's, FSLDIR is not defined before feat is
    # called (it is set in the feat wrapper). In that case, FSLDIR
    # should be set in CBRAIN's tool configuration.
    cmds << "# Corrects path of standard brain\n"
    cmds << "echo Replacing path of standard file with its path on the current machine.\n"
    cmds << sed_design_file(modified_design_file_path,'\\\"\.*/data/standard','\\\"${FSLDIR}/data/standard')
    cmds << "\n"
    
    # Modifies paths of files in the design file when task goes to VM.    
    if self.respond_to? "job_template_goes_to_vm?" # method is defined only in the VM branch...
      if self.job_template_goes_to_vm? 
        functional_file  = modify_file_path_for_vm functional_file
        structural_file  = modify_file_path_for_vm structural_file
        regstandard_File = modify_file_path_for_vm regstandard_file 
      end
    end
    
    # Modifies options in the design file
    # These modifications will be done by the Bourreau, not by the task script.

    design_file_id = params[:design_file_id] || []
    design_file = Userfile.find(design_file_id).cache_full_path.to_s
    output  = (params[:output_name].eql? "") ? "melodic-#{self.run_id}" : "#{params[:output_name]}-#{self.run_id}"
    
    modified_design_file_content = File.read(design_file)
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "feat_files(1)"                   ,"#{functional_file}" , true
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "highres_files(1)"                ,"#{structural_file}" , true
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard)"               ,"#{regstandard_file}", true
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(outputdir)"                 ,"#{output}", true
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(multiple)"                  ,"1"
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(tr)"                        ,     params[:tr] 
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(ndelete)"                   ,     params[:ndelete]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(filtering_yn)"              ,     params[:filtering_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(brain_thresh)"              ,     params[:brain_thresh]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(mc)"                        ,     params[:mc]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(te)"                        ,     params[:te]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(bet_yn)"                    ,     params[:bet_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(smooth)"                    ,     params[:smooth]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(norm_yn)"                   ,     params[:norm_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(temphp_yn)"                 ,     params[:temphp_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(templp_yn)"                 ,     params[:templp_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(motionevs)"                 ,     params[:motionevs]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(bgimage)"                   ,     params[:bgimage]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reg_yn)"                    ,     params[:reg_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reginitial_highres_yn)"     ,     params[:reginitial_highres_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reginitial_highres_search)" ,     params[:reginitial_highres_search]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reginitial_highres_dof)"    ,     params[:reginitial_highres_dof]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reghighres_yn)"            ,      params[:reghighres_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reghighres_search)"        ,      params[:reghighres_search]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(reghighres_dof)"           ,      params[:reghighres_dof]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard_yn)"            ,     params[:regstandard_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard_search)"        ,     params[:regstandard_search]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard_dof)"           ,     params[:regstandard_dof]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard_nonlinear_yn)"  ,     params[:regstandard_nonlinear_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard_nonlinear_warpres)" , params[:regstandard_nonlinear_warpres]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(regstandard_res)"           ,     params[:regstandard_res]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(varnorm)"                   ,     params[:varnorm]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(dim_yn)"                    ,     params[:dim_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(dim)"                       ,     params[:dim]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(thresh_yn)"                 ,     params[:thresh_yn]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(mmthresh)"                  ,     params[:mmthresh]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(ostats)"                    ,     params[:ostats]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(st)"                        ,     params[:st]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(icaopt)"                    ,     params[:icaopt]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(analysis)"                  ,     params[:analysis]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(paradigm_hp)"               ,     params[:paradigm_hp]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(npts)"                      ,     params[:npts]
    modified_design_file_content = set_option_in_design_file_content modified_design_file_content , "fmri(alternateReference_yn)"     ,     params[:alternatereference_yn]
    
    # Writes the new design file
    File.open(modified_design_file_path, 'w') { |file| file.write(modified_design_file_content) }
    
    # Searches for the feat executable
    cmds   << find_command("Feat","feat fsl5.0-feat")

    # FSL melodic execution commands
    cmds   << "# Executes FSL melodic\n"
    cmds   << "echo Starting melodic\n"
    cmds   << "${FEATCMD} #{modified_design_file_path}\n"
    cmds   << "if [ $? != 0 ]\n"
    cmds   << "then\n"
    cmds   << "echo \"ERROR: melodic exited with a non-zero exit code!\"\n"
    cmds   << "fi\n" 
    
    params[:output_dir_name] = output

    return cmds

  end

  def save_results #:nodoc:

    params  = self.params
    
    functional_file_id  = params[:functional_file_id]
    structural_file_id  = params[:structural_file_id]
    regstandard_file_id = params[:regstandard_file_id]
    
    functional_file    = Userfile.find(functional_file_id)
    structural_file    = Userfile.find(structural_file_id)
    regstandard_file   = Userfile.find(regstandard_file_id) unless regstandard_file_id.nil?
    
    functional_name    = functional_file.name.gsub(".gz","").gsub(".nii","").gsub(".mnc","")
    
    # Saves converted file if any.
    functional_file  = save_converted_file( params[:converted_functional_file_name]  , functional_file )  unless params[:converted_functional_file_name].nil?
    structural_file  = save_converted_file( params[:converted_structural_file_name]  , structural_file )  unless params[:converted_structural_file_name].nil?
    regstandard_file = save_converted_file( params[:converted_regstandard_file_name] , regstandard_file) unless params[:converted_regstandard_file_name].nil?
    
    # Finds and renames output directory. 
    outputname         = "#{params[:output_dir_name]}.ica"
    outputname         = "#{params[:output_dir_name]}.gica" unless File.exists? outputname
    raise "Cannot find output file #{outputname}/.ica"      unless File.exists? outputname
    outputname_new     = "#{functional_name}-#{outputname}"
    self.addlog "Renaming #{outputname} to #{outputname_new}."
    raise "Cannot rename output file" unless File.rename(outputname,outputname_new)
    
    # Saves result file.
    outputname_unique  = unique_file_name outputname_new
    outputfile         =  safe_userfile_find_or_new(FslMelodicOutput, :name => outputname_unique)
    outputfile.save!
    outputfile.cache_copy_from_local_file(outputname_new)
    self.addlog_to_userfiles_these_created_these( [ functional_file,structural_file ], [ outputfile ] )
    self.addlog("Saved result file #{params[:output_dir_name]}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(functional_file)
    
    # Verifies if all tasks exited without error (do this after saving
    # the files because important debug information is found in the
    # melodic logs).
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
  
  private

  ##################################################
  ################# Utils methods ##################
  ##################################################

  ####
  #### File content manipulation in Ruby.
  ####
  
  # Sets an option in the design file.
  def set_option_in_design_file_content design_file_content,option,value,quotes=false
    return design_file_content if value.nil? or value.blank?
    modified_design_file_content = []
    # Remove existing option line(s)
    design_file_content.each_line do |line|
      if line.gsub(" ","").downcase.include? option.gsub(" ","").downcase
        new_line = "# Line commented by CBRAIN: #{line}"
      else
        new_line = line
      end
      modified_design_file_content << new_line
    end
    # Add new option line
    content = quotes ? "set #{option} \"#{value}\" \n" : "set #{option} #{value} \n"
    modified_design_file_content << content
    return modified_design_file_content.join
  end

  ####
  #### File content manipulation in bash.
  ####

  # Bash command to "sed" a string in a file.
  def sed_design_file design_file_path,old_value,new_value
    return "sed s,#{old_value},#{new_value},g #{design_file_path} > #{design_file_path}.temp ; \mv -f #{design_file_path}.temp #{design_file_path}"
  end
  
  # Bash command to add a line to a file.
  def add_line_to_file file_path,line
    return "echo ${line} >> #{file_path}"
  end
  
  # Bash command to set the value of a parameter in the design file
  def set_design_file_option design_file_path,parameter_name,value
    cmds = []
    cmds << "# Sets option ${parameter_name} in the design file\n"
    cmds << sed_design_file(design_file_path,"\'set.*fmri(#{parameter_name})\'","\'# Line commented by CBRAIN set fmri(#{parameter_name})\'")
    cmds << add_line_to_file(design_file_path,"set fmri(#{parameter_name}) #{value}")
    cmds << "\n"
    return cmds.join
  end
  
  ####
  #### Conversion from MINC to Nifti.
  ####
  
  # Returns the conversion command from MINC to NIFTI.
  def mnc_to_nifti_command minc_file_name    
    raise "Error: this doesn't look like a MINC file" unless is_minc_file_name? minc_file_name
    nii_file_name = nifti_file_name minc_file_name
    # removes the minc file after conversion otherwise feat crashes...
    cmds = []
    cmds << "# File converstion to Nifti\n"
    cmds << "echo Converting file #{minc_file_name} to Nifti\n"
    cmds << "mnc2nii -nii #{minc_file_name} `pwd`/#{File.basename nii_file_name}\n"
    cmds << "if [ $? != 0 ]\n"
    cmds << "then\n"
    cmds << "  echo ERROR: cannot convert file #{minc_file_name} to nii\n"
    cmds << "  exit 1\n"
    cmds << "fi\n"
    cmds << "rm -f #{minc_file_name}\n"
    cmds << "\n"
    return cmds.join
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
    return nil if file_id.nil?
    file_name = "#{self.full_cluster_workdir}/#{Userfile.find(file_id).name}"    
    return [file_name,""] unless is_minc_file_name? file_name
    # file_name is a MINC file name
    return [ nifti_file_name(file_name) ,  mnc_to_nifti_command(file_name) ] 
  end

  ####
  #### Other utils.
  ####
  
  def modify_file_path_for_vm path
    return nil if path.nil?
    task_dir = RemoteResource.current_resource.cms_shared_dir
    return path.sub(task_dir,File.join("$HOME",File.basename(task_dir)))
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

  # A bash command to find a command among a list of possible commands. 
  def find_command command_name,command_list
    variable = command_name.gsub(' ','').upcase
    cmds   << "# Looks for #{command_name} executable\n"
    cmds   << "unset #{variable}\n"
    cmds   << "for cmd in #{command_list}\n"
    cmds   << "do\n"
    cmds   << "  which ${cmd} &>/dev/null\n"
    cmds   << "  if [ $? = 0 ]\n"
    cmds   << "  then\n"
    cmds   << "    #{variable}=${cmd}\n"
    cmds   << "    break\n"
    cmds   << "fi\n"
    cmds   << "done\n"
    cmds   << "if [ -z \"${#{variable}}\" ]\n"
    cmds   << "then\n"
    cmds   << "  echo ERROR: unable to find any #{command_name} executable\n"
    cmds   << "  exit 1\n"
    cmds   << "fi\n"
    cmds   << "echo #{command_name} executable set to ${#{variable}}.\n"
    cmds   << "\n"
  end
end


