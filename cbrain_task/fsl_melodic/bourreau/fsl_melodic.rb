
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

  def self.properties #:nodoc:
    super.merge :can_submit_new_tasks => true
  end
  
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
    return 24.hours
  end

  def cluster_commands #:nodoc:

    params    = self.params

    # The list of bash commands to be executed.
    cmds      = []

    # Function and variable declarations
    add_cmd_declarations(cmds)

    # Searches for FSL executables
    cmds << find_command("Feat","feat fsl5.0-feat")
    cmds << find_command("FSLHD","fslhd fsl5.0-fslhd")
    cmds << find_command("FSLNVOLS","fslnvols fsl5.0-fslnvols")
    cmds << find_command("FSLSTATS","fslstats fsl5.0-fslstats")
    cmds << find_command("FSLINFO","fslinfo fsl5.0-fslinfo")
    
    # Finds a name for the modified design file.
    modified_design_file_path = "design-cbrain.fsf"
    count = 1
    while File.exists? modified_design_file_path
      count += 1
      modified_design_file_path = "design-cbrain-#{count}.fsf"
    end

    # A hash containing the options to change in the design file
    new_options = Hash.new

    # A hash containing the files converted from MINC to Nifti.
    # Used in save_results to save the Nifti files.
    # key: file id of MINC file.
    # value: file name of corresponding Nifti file.
    params[:converted_files] = Hash.new
    
    ###
    ### Processes functional files.
    ###
    params[:functional_file_ids].each_with_index do |functional_file_id,index|
      functional_file_name = pre_process_input_data_file(cmds,
                                                         functional_file_id,
                                                         "feat_files(#{index+1})",
                                                         new_options)

      # Extracts the file dimensions and TRs so that they can be checked.
      add_cmd_extract_file_dimensions(cmds,functional_file_name)
      add_cmd_extract_trs(cmds,functional_file_name)
      cmds << "\n"

      # Excludes files that violate dimension requirements
      add_cmd_check_file_dimension_violations(cmds,
                                              functional_file_name,
                                              modified_design_file_path,
                                              index)

      # Performs auto-corrections in the design file
      add_cmd_auto_correct_design_file(cmds,
                                       functional_file_name,
                                       modified_design_file_path)
      # Check that file t dimension is greater than 20 after removal
      # of the first ndelete volumes. In case of a group analysis (icaopt = 2 or icaopt = 3)
      # then it guarantees that all the files have more than 20 volumes because we check later
      # that all the files have the same dimensions.
      add_cmd_check_t_dimension_greater_than(cmds,
                                             functional_file_name,
                                             20+params[:ndelete].to_i)

    end

    # Check if all the files were excluded due to dimension violations
    add_cmd_check_if_all_files_were_excluded_and_reindex(cmds,
                                             modified_design_file_path,
                                             params[:functional_file_ids].size)

    # If the task is a group analysis, check that all the functional files have
    # the same file dimensions and TRs.
    if params[:icaopt]=="2" || params[:icaopt]=="3"
      add_cmd_check_file_dimensions_identical(cmds)
      add_cmd_check_trs_identical(cmds)
    end
    
    ###
    ### Pre-processes structural files.
    ###
    params[:structural_file_ids].each_with_index do |structural_file_id,index|
      pre_process_input_data_file(cmds,
                                  structural_file_id,
                                  "highres_files(#{index+1})",
                                  new_options)
    end
    
    ###
    ### Processes regstandard file
    ###
    if params[:regstandard_file_id].present?
      pre_process_input_data_file(cmds,
                                  params[:regstandard_file_id],
                                  "fmri(regstandard)",
                                  new_options)                
    end

    ###
    ### Design file modifications on the execution machine.
    ###

    # $HOME has to be replaced on the machine where the task is
    # executed, not on the Bourreau's machine
    cmds << "info Replacing '$HOME' with $HOME in the design file."
    cmds << sed_design_file(modified_design_file_path,"\\\$HOME","$HOME")

    if !params[:regstandard_file_id].present?
      # Set regstandard path to default, as documented in the task launch form.
      # $FSLDIR has to be replaced on the machine where the task is
      # executed, not on the Bourreau's machine.  In some installations
      # of FSL, e.g. Neurodebian's, FSLDIR is not defined before feat is
      # called (it is set in the feat wrapper). In that case, FSLDIR
      # should be set in CBRAIN's tool configuration.
      cmds << "# Corrects path of standard brain"
      cmds << set_design_file_option(modified_design_file_path,"regstandard","\\\"${FSLDIR}/data/standard/MNI152_T1_2mm_brain\\\"")
    end

    ###
    ### Modifies the design file to take into account the task parameters.
    ###
    output  = (! params[:output_name].present?) ? "melodic-#{self.run_id}" : "#{params[:output_name]}-#{self.run_id}"

    new_options["fmri(outputdir)"]                     =     "\"#{output}\""
    new_options["fmri(multiple)"]                      =     "#{params[:functional_file_ids].size}"
    new_options["fmri(tr)"]                            =     params[:tr]            unless params[:tr_auto] == "1"
    new_options["fmri(ndelete)"]                       =     params[:ndelete]
    new_options["fmri(filtering_yn)"]                  =     params[:filtering_yn]
    new_options["fmri(brain_thresh)"]                  =     params[:brain_thresh]
    new_options["fmri(mc)"]                            =     params[:mc]
    new_options["fmri(te)"]                            =     params[:te]
    new_options["fmri(bet_yn)"]                        =     params[:bet_yn]
    new_options["fmri(smooth)"]                        =     params[:smooth]
    new_options["fmri(norm_yn)"]                       =     params[:norm_yn]
    new_options["fmri(temphp_yn)"]                     =     params[:temphp_yn]
    new_options["fmri(templp_yn)"]                     =     params[:templp_yn]
    new_options["fmri(motionevs)"]                     =     params[:motionevs]
    new_options["fmri(bgimage)"]                       =     params[:bgimage]
    new_options["fmri(reg_yn)"]                        =     ( params[:reghighres_yn] == "1" || params[:regstandard_yn] == "1" ) ? "1" : "0"
    #    Commented out as this option is not properly supported by CBRAIN yet.
    #    new_options["fmri(reginitial_highres_yn)"]        =     params[:reginitial_highres_yn]
    #    new_options["fmri(reginitial_highres_search)"]    =     params[:reginitial_highres_search]
    #    new_options["fmri(reginitial_highres_dof)"]       =     params[:reginitial_highres_dof]
    new_options["fmri(reghighres_yn)"]                 =     params[:reghighres_yn]
    new_options["fmri(reghighres_search)"]             =     params[:reghighres_search]
    new_options["fmri(reghighres_dof)"]                =     params[:reghighres_dof]
    new_options["fmri(regstandard_yn)"]                =     params[:regstandard_yn]
    new_options["fmri(regstandard_search)"]            =     params[:regstandard_search]
    new_options["fmri(regstandard_dof)"]               =     params[:regstandard_dof]
    new_options["fmri(regstandard_nonlinear_yn)"]      =     params[:regstandard_nonlinear_yn]
    new_options["fmri(regstandard_nonlinear_warpres)"] =     params[:regstandard_nonlinear_warpres]
    new_options["fmri(regstandard_res)"]               =     params[:regstandard_res]
    new_options["fmri(varnorm)"]                       =     params[:varnorm]
    new_options["fmri(dim_yn)"]                        =     params[:dim_yn]
    new_options["fmri(dim)"]                           =     params[:dim]
    new_options["fmri(thresh_yn)"]                     =     params[:thresh_yn]
    new_options["fmri(mmthresh)"]                      =     params[:mmthresh]
    new_options["fmri(ostats)"]                        =     params[:ostats]
    new_options["fmri(st)"]                            =     params[:st]
    new_options["fmri(icaopt)"]                        =     params[:icaopt]
    new_options["fmri(analysis)"]                      =     params[:analysis]
    new_options["fmri(paradigm_hp)"]                   =     params[:paradigm_hp]
    new_options["fmri(npts)"]                          =     params[:npts]                      unless params[:npts_auto] == "1"
    new_options["fmri(totalVoxels)"]                   =     params[:totalvoxels]               unless params[:totalvoxels_auto] == "1"

    # Writes the new design file
    design_file_id               = params[:design_file_id]
    design_file                  = Userfile.find(design_file_id).cache_full_path.to_s
    design_file_content          = File.read(design_file)
    modified_design_file_content = set_options_in_design_file_content(design_file_content,new_options)
    File.open(modified_design_file_path, 'w') { |file| file.write(modified_design_file_content) }

    ###
    ### Execution of melodic
    ###
    
    # FSL melodic execution commands

    # Export of the CBRAIN_WORKDIR variable is used by 
    # fsl_sub to determine if task has to be parallelized.
    # In our case, workdir is exported only for group analyses because
    # individual analyses will not be parallelized. 
    export_workdir_command = (params[:icaopt]=="1") ? "" :
                             "export CBRAIN_WORKDIR=#{self.full_cluster_workdir} # To make fsl_sub submit tasks to CBRAIN"
    command=<<-END
# Executes FSL melodic
info Starting melodic
#{export_workdir_command}
${FEAT} #{modified_design_file_path}
if [ $? != 0 ]
then
    error "Melodic exited with a non-zero exit code"
fi
chmod -R o+rx *ica 
END
    cmds << command
    params[:output_dir_name] = output

    return cmds

  end

  def save_results #:nodoc:
    # Extracted from the documentation in ClusterTask:
    # returning false will mark
    # the job with a final status "Failed On Cluster".
    # Raising an exception will mark the job with
    # a final status "Failed To PostProcess".
    params  = self.params
    em = error_messages?
    begin
      # Try to transfer output files even when
      # error messages are found
      # (output files contain important debugging information).
      save_output_files
    rescue Exception => msg
      self.addlog(msg)
      # Output files couldn't be transferred:
      #  * raise an exception if no error messages
      #     were found so that task is put in status "Failed To PostProcess".
      #  * return false otherwise so that task is put in status "Failed on Cluster".
      raise msg if !em 
    end
    # At this stage, em=true if save_output_file raised an exception. 
    return !em
  end

  private

  ####################################################
  ################# File saving and results checking #
  ####################################################
  
  
  # Transfer all *.ica and *.gica directories
  # Raises an exception if none are found
  def save_output_files
    # Finds and renames output directory.
    main_output_file_name         = "#{params[:output_dir_name]}.ica"
    main_output_file_name         = "#{params[:output_dir_name]}.gica" unless File.exists? main_output_file_name
    raise "Cannot find output file #{params[:output_dir_name]}.ica or #{params[:output_dir_name]}.gica"    unless File.exists? main_output_file_name

    # Builds an array containing the input files (not the input file ids).
    # This array is used later to create the task log (in invocations
    # of method 'addlog_to_userfiles_these_created_these')
    input_files = []
    params[:task_file_ids].each do |id|
      input_files << Userfile.find(id)
    end

    # Saves the main result file.
    cbrain_output_name  = unique_file_name(main_output_file_name)
    cbrain_parent_file  = params[:functional_file_ids].size == 1 ?
                            Userfile.find(params[:functional_file_ids][0]) :
                            Userfile.find(params[:csv_file_id])
    main_output_file    = save_file(FslMelodicOutput,
                                    cbrain_output_name,
                                    main_output_file_name,
                                    cbrain_parent_file,
                                    input_files)    
    params[:outfile_id] = main_output_file.id

    # Saves additional result files (individual analyses when the main
    # analysis is a group analysis).
    Dir.glob("*.ica").each do |result_directory|
      unless main_output_file_name == result_directory
        self.addlog("Saving additional result file: #{result_directory}")
        save_file(FslMelodicOutput,
                  result_directory,
                  result_directory,
                  main_output_file,
                  input_files)
      end
    end
    
    # Saves the files converted to Nifti
    params[:converted_files].each do |minc_file_id,nifti_file_name|
      minc_file = Userfile.find(minc_file_id)
      save_file(NiftiFile,
                unique_file_name(File.basename(nifti_file_name)),
                nifti_file_name,
                minc_file,
                [ minc_file ] )
    end
  end

  # Saves a local file in CBRAIN
  # Parameters:
  # * cbrain_file_type  : the type of the file created in CBRAIN (e.g. SingleFile)
  # * cbrain_file_name  : the name of the file created in CBRAIN (e.g. "foo.txt")
  # * local_file_name   : the name of the local file to synchronize (e.g. "bar.txt")
  # * cbrain_parent_file: the name of the CBRAIN file under which the new CBRAIN file will be created
  # * input_files       : an array containing the CBRAIN files that were used to produce this file.   
  def save_file cbrain_file_type,cbrain_file_name,local_file_name,cbrain_parent_file,input_files
    self.addlog("Saving result file #{cbrain_file_name} as a child of #{cbrain_parent_file.name}")
    outputfile= safe_userfile_find_or_new(cbrain_file_type, :name => cbrain_file_name)
    outputfile.save!
    outputfile.cache_copy_from_local_file(local_file_name)
    outputfile.move_to_child_of(cbrain_parent_file)
    self.addlog_to_userfiles_these_created_these( input_files, [ outputfile ] )
    self.addlog("Saved result file #{cbrain_file_name}")
    return outputfile
  end  

  
  # Returns true if error messages were detected.
  def error_messages?
    # Verifies if all tasks exited without error (do this after saving
    # the files because important debug information is found in the
    # melodic logs).
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /ERROR/
      self.addlog("melodic task failed (see Standard Error)")
      return true
    end
    stdout = File.read(self.stdout_cluster_filename) rescue ""
    if stdout =~ /ERROR/
      self.addlog("melodic task failed (see Standard Output)")
      return true
    end
    return false
  end

  
  ##################################################
  ################# Utils methods ##################
  ##################################################

  ####
  #### File content manipulation in Ruby.
  ####

  # Options is a hash containing option => value.
  # Example: { "fmri(npts)" => "1234", "fmri(ostats)" => "45" }
  def set_options_in_design_file_content design_file_content,options
    return design_file_content if options.nil? || options.size == 0
    modified_design_file_content = []
    # Remove existing option line(s)
    design_file_content.each_line do |line|
      new_line = line
      options.each do |option,value|
        if line.gsub(" ","").downcase.include?(option.gsub(" ","").downcase)
          new_line = "# Line commented by CBRAIN: #{line}"
          break
        end
      end
      modified_design_file_content << new_line
    end
    # Add new option line(s)
    options.each do |option,value|
      modified_design_file_content << "set #{option} #{value} \n" if value.present?
    end
    return modified_design_file_content.join
  end

  ####
  #### File content manipulation in bash.
  ####

  # Bash command to replace old_value with new_value anywhere in design_file_path.
  # old_value and new_value cannot contain commas.
  def sed_design_file design_file_path,old_value,new_value
    return "sed s,#{old_value},#{new_value},g #{design_file_path} > #{design_file_path}.temp \n\mv -f #{design_file_path}.temp #{design_file_path}\n"
  end

  # Bash command to add a line to a file.
  def add_line_to_file file_path,line
    return "echo #{line} >> #{file_path}"
  end

  # Bash command to set the value of a parameter in the design file.
  # The parameter name and value cannot contain commas.
  def set_design_file_option design_file_path,parameter_name,value
    cmds = []
    cmds << "# Sets option #{parameter_name} in the design file\n"
    cmds << comment_out_design_file_option(design_file_path,parameter_name)
    cmds << add_line_to_file(design_file_path,"'set fmri(#{parameter_name})' #{value}")
    cmds << "\n"
    return cmds.join
  end

  # Bash command to set the value of a parameter in the design file.
  # The parameter name and value cannot contain commas.
  def comment_out_design_file_option design_file_path,parameter_name
    cmds = []
    cmds << sed_design_file(design_file_path,"\'set.*fmri(#{parameter_name})\'","\'# Line commented by CBRAIN set fmri(#{parameter_name})\'")
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
    command=<<-END
      # File conversion to Nifti
      info Converting file #{minc_file_name} to Nifti
      mnc2nii -nii #{minc_file_name} `pwd`/#{File.basename nii_file_name}
      if [ $? != 0 ]
      then
        error "Cannot convert file #{minc_file_name} to nii"
        exit 1
      fi
      rm -f #{minc_file_name}
    END
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
    return nil if !file_id.present?
    file_name = "#{self.full_cluster_workdir}/#{Userfile.find(file_id).name}"
    return [file_name,""] unless is_minc_file_name? file_name
    # file_name is a MINC file name
    return [ nifti_file_name(file_name) ,  mnc_to_nifti_command(file_name) ]
  end

  ####
  #### Other utils.
  ####

  def modify_file_path_for_vm path
    return nil if !path.present?
    task_dir = RemoteResource.current_resource.cms_shared_dir
    # assumes that HOME is defined in the VM.
    return path.sub(task_dir,File.join("$HOME",File.basename(task_dir)))
  end

  # Returns a file_name if there is no file named file_name. Returns a
  # unique file name based on file_name otherwise.
  def unique_file_name file_name
    count = 0
    name  = file_name
    current_user = User.find(self.user_id)
    while Userfile.find_all_accessible_by_user(current_user).exists?(:name => name)
      count += 1
      extname = File.extname(name)
      name = "#{File.basename(name,extname)}-#{count}#{extname}"
    end
    return name
  end
  
  # A bash command to find a command among a list of possible
  # commands.
  # Parameters:
  # * command_name: the name of the command to
  #   look for. A bash variable named command_name.upcase will
  #   eventually contain the name of the actual command found on the
  #   host.
  # * command_list: the list of possible commands. The first
  #   command of this list found on the execution host will be selected.
  # Example: find_command("Feat","feat fsl5.0-feat") will define a bash
  #          variable named FEAT that will contain either "feat" or
  #          "fsl5.0-feat" depending on what is found on the execution host.
  def find_command command_name,command_list
    variable = command_name.gsub(' ','').upcase
    command=<<-END
# Looks for #{command_name} executable
unset #{variable}
for cmd in #{command_list}
do
   which ${cmd} &>/dev/null
   if [ $? = 0 ]
   then
     #{variable}=${cmd}
     break
   fi
done
if [ -z \"${#{variable}}\" ]
then
    error "Unable to find any #{command_name} executable."
    exit 1
fi
info "#{command_name} executable set to ${#{variable}}."
END
    return command
  end

  # Pre-processes an input data file, i.e.:
  # * converts it to nifti if it's a MINC file
  # * modify the path of the file in the design file if the task goes to a VM
  # * adds the (possibly converted) file path to the design file
  # Parameters:
  #   * cmds: an array that receives the (bash) commands required for the conversion
  #   * file_id: the id of the input file to pre-process
  #   * design_file_option: the corresponding option in the design file (e.g. "feat_files(42)")
  def pre_process_input_data_file cmds,file_id,design_file_option,new_options
    
    # Converts minc files to nifti.
    converted_file_name , conversion_command  = converted_file_name_and_command(file_id)
    if conversion_command.present?
      cmds << conversion_command
      params[:converted_files][file_id] = converted_file_name
    end

    # Modifies paths of file in the design file when task goes to VM.
    converted_file_name = modify_file_path_for_vm(converted_file_name) if self.respond_to?("job_template_goes_to_vm?") && self.job_template_goes_to_vm?

    # Adds new file to design file
    new_options[design_file_option] = "\"#{converted_file_name}\""
    
    return converted_file_name
  end

  # Adds commands to auto-correct the design file based on input file characteristics.
  # * cmds: an array that receives the (bash) commands needed for the auto correction.
  # * functional_file_name: the name of a functional file used to correct parameters.
  # * modified_design_file_path: the path of the modified design file.
  def add_cmd_auto_correct_design_file cmds,functional_file_name,modified_design_file_path

    # Auto-correction needs to be done on the task node (i.e. in
    # the task script), not on the Bourreau host.  Otherwise, FSL
    # needs to be installed on the Bourreau node, which might not
    # be the case (e.g. in case the task runs in a Docker container).
    if params[:npts_auto] == "1"
      command=<<-END
# Auto-corrects fmri(npts) unless #{functional_file_name} was excluded or correction was already done.
if [ -z ${EXCLUDED_FILES[\'#{functional_file_name}\']+x} ] && [ -z ${NPTS_CORRECTED+z} ]
then
  NPTS=`${FSLNVOLS} #{functional_file_name}`
  if [ $? != 0 ]
  then
    error "Cannot auto-correct number of volumes in #{functional_file_name} '(fslnvols failed)'."
  fi
  info "Auto-corrected number of volumes to ${NPTS}."
  NPTS_CORRECTED=true
fi
END
      cmds << command
      cmds << set_design_file_option(modified_design_file_path,"npts","${NPTS}")
    end

    
    if params[:tr_auto] == "1"
      command=<<-END
# Auto-corrects parameter fmri(tr) unless #{functional_file_name} was excluded or correction was already done.
if [ -z ${EXCLUDED_FILES[\'#{functional_file_name}\']+x} ] && [ -z ${TR_CORRECTED+z} ]
then
  TR=`${FSLHD} #{functional_file_name} | awk '$1==\"pixdim4\" {print $2}'`
  if [ $? != 0 ]
  then
    error "Cannot auto-correct TR in #{functional_file_name} '(fslhd failed)'."
  fi
  info "Auto-corrected TR to ${TR}."
  TR_CORRECTED=true
fi
END
      cmds << command
      cmds << set_design_file_option(modified_design_file_path,"tr","${TR}")
    end
    
    if params[:totalvoxels_auto] == "1"
      command=<<-END
# Auto-corrects parameter fmri(totalVoxels) unless #{functional_file_name} was excluded or correction was already done.
if [ -z ${EXCLUDED_FILES[\'#{functional_file_name}\']+x} ] && [ -z ${NVOX_CORRECTED+z} ]
then
  NVOX=`${FSLSTATS} #{functional_file_name} -v | awk '{print $1}'`
  if [ $? != 0 ]
  then
    error "Cannot auto-correct number of voxels in #{functional_file_name} '(fslstats failed)'."
  fi
  info "Auto-corrected total voxels to ${NVOX}."
  NVOX_CORRECTED=true
fi
END
      cmds << command
      cmds << set_design_file_option(modified_design_file_path,"totalVoxels","${NVOX}")
    end
  end

  # Extracts the dimensions of a file and puts them in a .fslinfo file
  # Parameters:
  #   * functional_file_name: name of the file.
  #   * cmds: array that receives the (bash) commands to perform the check.
  def add_cmd_extract_file_dimensions cmds,functional_file_name
    cmds << "# Extracts dimensions of file #{functional_file_name}"
    cmds << "${FSLINFO} #{functional_file_name} | awk '$1==\"dim1\" || $1==\"dim2\" || $1==\"dim3\" || $1==\"dim4\" {print}'> #{functional_file_name}.fslinfo"
  end


  # Adds functions and variable declarations.
  # * cmds: an array that receives the (bash) commands needed for the auto correction.
  def add_cmd_declarations cmds
    command=<<-END
# Will contain the list of functional
# files that were excluded due to dimenstion violations
declare -A EXCLUDED_FILES # Associative array, requires bash 4

# Will contain the list of file indices
# that were excluded due to dimenstion violations
declare -a EXCLUDED_INDICES # Indices (in FSL design file) of excluded files

# Excludes a functional file that violates dimension
# requirements. Parameters:
# * functional_file_name: name of the functional file to exclude
# * index: index of the functional file in the FSL design file
# * design_file_path: path to the FSL design file
function exclude {
  local functional_file_name=$1
  local index=$2
  local design_file_path=$3
  EXCLUDED_FILES["${functional_file_name}"]=true
  EXCLUDED_INDICES=("${EXCLUDED_INDICES[@]}" "${index}")
  rm -f ${functional_file_name}.fslinfo
  rm -f ${functional_file_name}.trvalue
  for variable in feat_files highres_files initial_highres_files
  do
    sed s,'set '${variable}\\\(${index}\\\),'# Line commented by CBRAIN due to dimension violation set '${variable}\\\(${index}\\\),g ${design_file_path} > ${design_file_path}.temp
    mv -f ${design_file_path}.temp ${design_file_path}
  done
}

# Updates the index of a file in the design file
function replace_index {
  local design_file_path=$1
  local old_index=$2
  local new_index=$3
  for variable in feat_files highres_files initial_highres_files
  do
    sed s,'set '${variable}\\\(${old_index}\\\),'set '${variable}\\\(${new_index}\\\),g ${design_file_path} > ${design_file_path}.temp
    mv -f ${design_file_path}.temp ${design_file_path}
  done
}

# Returns 0 if element is contained in array
# * $1: element to test
# * other arguments: array elements
function containsElement {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# Re-indexes the files in design file so that
# there is a continuous sequence of indices (0,1,2,...)
# even if some files were excluded
function clean_all_indices {
  local design_file_path=$1
  local n_files=$2
  local current_index=1
  for i in `seq 1 ${n_files}`
  do
    containsElement "${i}" "${EXCLUDED_INDICES[@]}"
    if [ $? != 0 ]
    then
      # i was not excluded
      replace_index ${design_file_path} ${i} ${current_index}
      current_index=$(( current_index + 1 ))
    fi
  done
  # Updates parameter fmri(multiple) to current_index - 1 (new total number of files in the analysis)
  local new_fmri_multiple=$(( current_index - 1 ))
  sed s,'set.*fmri(multiple)','# Line commented by CBRAIN due to dimension violation set fmri(multiple)',g ${design_file_path} > ${design_file_path}.temp
  mv -f ${design_file_path}.temp ${design_file_path}
  echo "set fmri(multiple) ${new_fmri_multiple}" >> ${design_file_path}
}

# Log functions
function timestamped_log {
  D=`date`
  echo "[ ${D} ] $*"
}

function info {
  timestamped_log "INFO $*"
}

function warning {
  timestamped_log "WARNING $*"
}

function error {
  timestamped_log "ERROR $*"
  exit 1
}
# End log functions

END
    cmds << command
  end

  # Adds commands to check if functional files violate dimension requirements.
  # * cmds: an array that receives the (bash) commands needed for the auto correction.
  # * functional_file_name: the name of the functional file to test.
  # * design_file_path: the path of the modified design file.
  # * index: index of the functional file in the list of functional files (CBRAIN index, starts a 0)
  def add_cmd_check_file_dimension_violations cmds,functional_file_name,design_file_path,index
    if(params[:check_x_dim] == "1")
      command=<<-END
XDIM=`awk '$1==\"dim1\" {print $2}' #{functional_file_name}.fslinfo`
if [ ${XDIM} -eq #{params[:required_x]} ]
then
 info "#{functional_file_name} has required X dimension (${XDIM})"
else
 warning "Excluding file #{functional_file_name} because it doesn't have the required X dimension (${XDIM} != #{params[:required_x]})"
 exclude #{functional_file_name} #{index+1} #{design_file_path}
fi
END
      cmds << command
    end
    if(params[:check_y_dim] == "1")
      command=<<-END
YDIM=`awk '$1==\"dim2\" {print $2}' #{functional_file_name}.fslinfo`
if [ ${YDIM} -eq #{params[:required_y]} ]
then
 info "#{functional_file_name} has required Y dimension (${YDIM})"
else
 warning "Excluding file #{functional_file_name} because it doesn't have the required Y dimension (${YDIM} != #{params[:required_y]})"
 exclude #{functional_file_name} #{index+1} #{design_file_path}
fi
END
      cmds << command
    end
    if(params[:check_z_dim] == "1")
      command=<<-END
ZDIM=`awk '$1==\"dim3\" {print $2}' #{functional_file_name}.fslinfo`
if [ ${ZDIM} -eq #{params[:required_z]} ]
then
 info "#{functional_file_name} has required Z dimension (${ZDIM})"
else
 warning "Excluding file #{functional_file_name} because it doesn't have the required Z dimension (${ZDIM} != #{params[:required_z]})"
 exclude #{functional_file_name} #{index+1} #{design_file_path}
fi
END
      cmds << command
    end
    if(params[:check_t_dim] == "1")
      command=<<-END
TDIM=`awk '$1==\"dim4\" {print $2}' #{functional_file_name}.fslinfo`
if [ ${TDIM} -eq #{params[:required_t]} ]
then
 info "#{functional_file_name} has required T dimension (${TDIM})"
else
 warning "Excluding file #{functional_file_name} because it doesn't have the required T dimension (${TDIM} != #{params[:required_t]})"
 exclude #{functional_file_name} #{index+1} #{design_file_path}
fi
END
      cmd << command
    end
  end

  # Extracts the TR of a file and puts them in a .trvalue file
  # Parameters:
  #   * functional_file_name: name of the file.
  #   * cmds: array that receives the (bash) commands to perform the check.
  def add_cmd_extract_trs cmds,functional_file_name
    cmds << "# Extracts TR of file #{functional_file_name}"
    cmds << "${FSLHD} #{functional_file_name} | awk '$1==\"pixdim4\" {print $2}' > #{functional_file_name}.trvalue"
  end

  # Check that all .trvalue files (created by method extract_trs)
  # are identical, i.e. all the files have the same TR. If this is
  # not the case, prints a warning.
  # Parameters:
  #  * cmds: an array that receives the (bash) commands to perform the check. 
  def add_cmd_check_trs_identical cmds
    command=<<-END
# Checks if all files have the same TR (excluded files have no *.trvalue file).
md5sum *.trvalue | awk 'NR>1&&$1!=last{exit 1}{last=$1}'
if [ $? != 0 ]
then
  echo "# File TRvalue"
  for file in `ls *.trvalue`
  do
    FILE_NAME=`basename ${file} .trvalue`
    INDEX=`grep ${FILE_NAME} design-cbrain.fsf | awk '{print $2}' | sed s,feat_files\\\(,,g | sed s,\\\),,g`
    TR=`cat ${file}`
    echo ${INDEX} ${FILE_NAME} ${TR}
  done | sort -g
  warning "Functional files do not all have the same TR (see TR values above)."
else
  info "All functional files have the same TR."
fi
# Remove .trvalue files so that they are not considered if task is restarted.
rm -f *.trvalue
END
    cmds << command
  end

  
  # Check that all .fslinfo files (created by method extract_file_dimensions)
  # are identical, i.e. all the files have the same file dimensions.
  # Parameters:
  #  * cmds: an array that receives the (bash) commands to perform the check. 
  def add_cmd_check_file_dimensions_identical cmds
    command=<<-END
# Checks if all files have the same dimensions (excluded files have no .fslinfo file.
md5sum *.fslinfo | awk 'NR>1&&$1!=last{exit 1}{last=$1}'
if [ $? != 0 ]
then
  echo "# File dim1 dim2 dim3 dim4"
  for file in `ls *.fslinfo`
  do
    FILE_NAME=`basename ${file} .fslinfo`
    INDEX=`grep ${FILE_NAME} design-cbrain.fsf | awk '{print $2}' | sed s,feat_files\\\(,,g | sed s,\\\),,g`
    X=`awk '$1=="dim1" {print $2}' ${file}`
    Y=`awk '$1=="dim2" {print $2}' ${file}`
    Z=`awk '$1=="dim3" {print $2}' ${file}`
    T=`awk '$1=="dim4" {print $2}' ${file}`
    echo ${INDEX} ${FILE_NAME} ${X} ${Y} ${Z} ${T}
  done | sort -g
  error "Functional files do not all have the same dimensions. Check the dimensions reported above and exclude the problematic file(s)."
  # Remove .fslinfo files so that they are not considered if task is restarted.
  rm -f *.fslinfo
  exit 1
fi
info "All functional files have the same dimensions."
# Remove .fslinfo files so that they are not considered if task is restarted.
rm -f *.fslinfo
END
    cmds << command
  end

  # Check that the number of volumes of a functional file is greater than a threshold.
  # Parameters:
  #  * cmds: an array that receives the (bash) commands to do the check.
  #  * file_name: the name of the structural file to check. Method 'add_cmd_extract_file_dimensions'
  #     must have been called on this file before the present method is called.
  #  * min_value: the threshold value.
  def add_cmd_check_t_dimension_greater_than cmds,functional_file_name,min_value
    command=<<-END
# Checking number of volumes in #{functional_file_name} unless file was excluded
if [ -z ${EXCLUDED_FILES[\'#{functional_file_name}\']+x} ]
then
  test -f #{functional_file_name}.fslinfo || ( error "Cannot check the dimension of file #{functional_file_name} (#{functional_file_name}.fslinfo does not exist)." )
  NVOLS=`awk '$1=="dim4" {print $2}' #{functional_file_name}.fslinfo`
  if [ $NVOLS -lt #{min_value} ]
  then
    error "Refusing to process functional files with only ${NVOLS} volumes. Minimal number of volumes must be greater than 20, after initial volume deletion (ndelete parameter)."
  else
    info "Number of functional volumes ($NVOLS) is greater than #{min_value}: proceeding."
  fi
fi
END
    cmds << command
  end

  # Adds commands to check if all the functional files were excluded (in this case the script will end).
  # Re-indexes all the files in the design file so that indices are a continuous sequence (0,1,2,3,...) even
  # if some files were excluded.
  # * cmds: an array that receives the (bash) commands needed for the auto correction.
  # * design_file_path: the path of the modified design file.
  # * number_of_files: total number of functional files
  def add_cmd_check_if_all_files_were_excluded_and_reindex cmds,design_file_path,number_of_files
    command=<<-END
# Check if there are files remaining (not excluded) in the design file
if [ ${#EXCLUDED_FILES[@]} = #{number_of_files} ]
then
  error "All the ${#EXCLUDED_FILES[@]} functional files were excluded due to dimension violations."
fi

# Re-index files in design file
clean_all_indices #{design_file_path} #{number_of_files}

END
    cmds << command
  end
end
