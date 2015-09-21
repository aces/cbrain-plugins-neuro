
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
    return 1.hours  if params[:icaopt] == "1"
    return [ 1.hours , 15.minutes * ( params[:functional_file_ids].size ) ].max
  end

  def cluster_commands #:nodoc:

    params    = self.params

    # The list of bash commands to be executed.
    cmds      = []

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

    # A hash containing the files converted from Nifti to MINC.
    # Used in save_results to save the MINC files.
    # key: file id of Nifti file.
    # value: file name of corresponding MINC file.
    params[:converted_files] = Hash.new
    
    ###
    ### Processes functional files.
    ###
    params[:functional_file_ids].each_with_index do |functional_file_id,index|
          functional_file_name = pre_process_input_data_file(cmds,
                                                         functional_file_id,
                                                         "feat_files(#{index+1})",
                                                         new_options)
          # Extract the file dimensions and TRs so that they can be checked.
          add_cmd_extract_file_dimensions(cmds,functional_file_name)
          add_cmd_extract_trs(cmds,functional_file_name)
          cmds << "\n"
          
          if index == 0
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
    end
    
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
                                  regstandard_file_id,
                                  "fmri(regstandard)",
                                  new_options)                
    end

    ###
    ### Design file modifications on the execution machine.
    ###

    # $HOME has to be replaced on the machine where the task is
    # executed, not on the Bourreau's machine
    cmds << "echo Replacing '$HOME' with $HOME in the design file."
    cmds << sed_design_file(modified_design_file_path,"\\\$HOME","$HOME")


    # Updates path of the standard brain to the local path.
    # $FSLDIR has to be replaced on the machine where the task is
    # executed, not on the Bourreau's machine.  In some installations
    # of FSL, e.g. Neurodebian's, FSLDIR is not defined before feat is
    # called (it is set in the feat wrapper). In that case, FSLDIR
    # should be set in CBRAIN's tool configuration.
    cmds << "# Corrects path of standard brain"
    cmds << "echo Replacing path of standard file with its path on the current machine."
    cmds << sed_design_file(modified_design_file_path,'\\"\.*/data/standard','\\"${FSLDIR}/data/standard')

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
    new_options["fmri(reg_yn)"]                        =     ( params[:reghighres_yn] == "1" or params[:regstandard_yn] == "1" ) ? "1" : "0"
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
    new_options["fmri(alternateReference_yn)"]         =     params[:alternatereference_yn]
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
    command=<<-END
# Executes FSL melodic
echo Starting melodic
${FEAT} #{modified_design_file_path}
if [ $? != 0 ]
then
    echo ERROR: melodic exited with a non-zero exit code
fi
chmod -R o+rx *ica 
END
    cmds << command
    params[:output_dir_name] = output

    return cmds

  end

  def save_results #:nodoc:

    params  = self.params

    # Finds and renames output directory.
    main_output_file_name         = "#{params[:output_dir_name]}.ica"
    main_output_file_name         = "#{params[:output_dir_name]}.gica" unless File.exists? main_output_file_name
    raise "Cannot find output file #{params[:output_dir_name]}.ica or #{params[:output_dir_name]}.gica"      unless File.exists? main_output_file_name

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
    
    # Saves the files converted to MINC
    params[:converted_files].each do |nifti_file_id,minc_file_name|
      save_file(NiftiFile,
                unique_file_name(File.basename(minc_file_name)),
                output_file_name,
                Userfile.find(nifti_file_id),
                [ parent_file ] )
    end

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
    cmds << sed_design_file(design_file_path,"\'set.*fmri(#{parameter_name})\'","\'# Line commented by CBRAIN set fmri(#{parameter_name})\'")
    cmds << add_line_to_file(design_file_path,"'set fmri(#{parameter_name})' #{value}")
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
      # File converstion to Nifti
      echo Converting file #{minc_file_name} to Nifti
      mnc2nii -nii #{minc_file_name} `pwd`/#{File.basename nii_file_name}
      if [ $? != 0 ]
      then
        echo \"ERROR: cannot convert file #{minc_file_name} to nii\"
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
    echo ERROR: unable to find any #{command_name} executable
    exit 1
fi
echo #{command_name} executable set to ${#{variable}}.
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
  #   * new_options: the hash storing the new options of the design file
  def pre_process_input_data_file cmds,file_id,design_file_option,new_options
    
      # Converts minc files to nifti.
      converted_file_name , conversion_command  = converted_file_name_and_command(file_id)
      if conversion_command.present?
        cmds << structural_conversion_command
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
# Auto-corrects parameter fmri(npts)
NPTS=`${FSLNVOLS} #{functional_file_name}`
if [ $? != 0 ]
then
  echo ERROR: cannot auto-correct number of volumes in #{functional_file_name} '(fslnvols failed)'.
  exit 1
fi
echo Auto-corrected number of volumes to ${NPTS}.
END
      cmds << command
      cmds << set_design_file_option(modified_design_file_path,"npts","${NPTS}")
    end

    
    if params[:tr_auto] == "1"
      command=<<-END
# Auto-corrects parameter fmri(tr)
TR=`${FSLHD} #{functional_file_name} | awk '$1==\"pixdim4\" {print $2}'`
if [ $? != 0 ]
then
  echo ERROR: cannot auto-correct TR in #{functional_file_name} '(fslhd failed)'.
  exit 1
fi
echo Auto-corrected TR to ${TR}.
END
      cmds << command
      cmds << set_design_file_option(modified_design_file_path,"tr","${TR}")
    end
    
    if params[:totalvoxels_auto] == "1"
      command=<<-END
# Auto-corrects parameter fmri(totalVoxels)
NVOX=`${FSLSTATS} #{functional_file_name} -v | awk '{print $1}'`
if [ $? != 0 ]
then
  echo ERROR: cannot auto-correct number of voxels in #{functional_file_name} '(fslstats failed)'.
  exit 1
fi
echo Auto-corrected total voxels to ${NVOX}.
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
# Checks if all files have the same TR.
md5sum *.trvalue | awk 'NR>1&&$1!=last{exit 1}{last=$1}'
if [ $? != 0 ]
then
  for file in `ls *.trvalue`
  do
    basename ${file} .trvalue
    cat ${file}
  done
  echo "Warning: functional files do not all have the same TR (see TR values above)."
else
  echo "All functional files have the same TR."
fi
END
    cmds << command
  end

  
  # Check that all .fslinfo files (created by method extract_file_dimenstions)
  # are identical, i.e. all the files have the same file dimensions.
  # Parameters:
  #  * cmds: an array that receives the (bash) commands to perform the check. 
  def add_cmd_check_file_dimensions_identical cmds
    command=<<-END
# Checks if all files have the same dimensions.
md5sum *.fslinfo | awk 'NR>1&&$1!=last{exit 1}{last=$1}'
if [ $? != 0 ]
then
  for file in `ls *.fslinfo`
  do
    basename ${file} .fslinfo
    cat ${file}
  done
  echo "ERROR: functional files do not all have the same dimensions. Check the dimensions reported above and exclude the problematic file(s)."
  exit 1
else
  echo "All functional files have the same dimensions."
fi
END
    cmds << command
  end

  # Check that the number of volumes of a functional file is greater than a threshold.
  # Parameters:
  #  * cmds: an array that receives the (bash) commands to do the check.
  #  * file_name: the name of the structural file to check. Method 'add_cmd_extract_file_dimensions'
  #     must have been called on this file before the present method is called.
  #  * min_value: the threshold value.
  def add_cmd_check_t_dimension_greater_than cmds,file_name,min_value
    command=<<-END
# Checking number of volumes in #{file_name}
test -f #{file_name}.fslinfo || ( echo "ERROR: Cannot check the dimension of file #{file_name} (#{file_name}.fslinfo does not exist)" ; exit 1)
NVOLS=`awk '$1=="dim4" {print $2}' #{file_name}.fslinfo`
if [ $NVOLS -lt #{min_value} ]
then
  echo "ERROR: Refusing to process functional files with only ${NVOLS} volumes. Minimal number of volumes must be greater than 20, after initial volume deletion (ndelete parameter)."
  exit 1
else 
  echo "Number of functional volumes ($NVOLS) is greater than #{min_value}: proceeding."
fi
END
    cmds << command
  end
end
