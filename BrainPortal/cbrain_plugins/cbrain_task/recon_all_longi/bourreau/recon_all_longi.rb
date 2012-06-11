
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

# A subclass of ClusterTask to run ReconAllLongi.
class CbrainTask::ReconAllLongi < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params = self.params
    
    collection_ids  = params[:interface_userfile_ids] || []
    collections     = Userfile.find_all_by_id(collection_ids)
    collections.each do |collection|            
      self.addlog("Preparing input file '#{collection.name}'")
      collection.sync_to_cache
      cache_path = collection.cache_full_path
      self.safe_symlink(cache_path, collection.name)
    end
    
    true
  end

  def job_walltime_estimate #:nodoc:
    nb_cpu   = self.tool_config.ncpus || 1
    nb_input = self.params[:interface_userfile_ids].size

    # Calculate time
    # First 1 is for base creation
    if nb_input % nb_cpu == 0
      ((1 + ( nb_input / nb_cpu )) * 24).hours   
    else
      ((1 + ( (nb_input / nb_cpu) + 1 )) * 24).hours   
    end
  end
  

  def cluster_commands #:nodoc:
    params            = self.params

    # Check if each input directories is an ReconAllCrossSectionalOutput and create tpn_list
    collection_ids  = params[:interface_userfile_ids] || []
    collections     = Userfile.find_all_by_id(collection_ids)

    collections.each do |collection|
      cb_error("Sorry, but #{collection.name} is not of type #{ReconAllCrossSectionalOutput.pretty_type}.") unless collection.is_a?(ReconAllCrossSectionalOutput)
    end

    tpn_files = collections.map &:name
    tp_list         = ""
    tpn_files.each { |name| tp_list += " -tp \'#{name}\'" }


    # Check base_output_name
    base_output_name = params[:base_output_name].presence || "Base"
    cb_error("Sorry, but the base output name provided contains some unacceptable characters.") unless is_legal_base_name?(base_output_name)
    task_work        = self.full_cluster_workdir

    # Create within subject
    recon_all_base_log = "#{base_output_name}/scripts/recon-all.log"
    recon_all_base_cmd = <<-RECON_SCRIPT
      #
      # Main Recon-all creation of base #{base_output_name}
      #

      echo ""
      echo Starting Recon-all -long.

      if test -f #{recon_all_base_log} && grep -q -i -P "recon-all .+ finished without error at" #{recon_all_base_log} ; then
        echo Base file construction already performed.
      else
        echo Starting base file construction.
        recon-all -sd . -base '#{base_output_name}' #{tp_list} -all
      fi
      
      if ! test -f #{recon_all_base_log} || ! grep -q -i -P "recon-all .+ finished without error at" #{recon_all_base_log} ; then
        echo "Error: Recon-all base file construction FAILED"
        exit 20
      fi
      
    RECON_SCRIPT

    # Longitudinal runs
    recon_all_long_cmds         = []
    params[:long_outputs_names] = []
    nb_cpu = self.tool_config.ncpus || 1

    # An array of array each sub-array is composed by recon-all cmd name of stdout and name of stderr.
    cmd_out_err_list   = []
    collections.each_with_index do |collection,idx|
      output_path = "#{collection.name}.long.#{base_output_name}"
      recon_all_long_log  = "#{output_path}/scripts/recon-all.log"
      params[:long_outputs_names] << output_path

      cmd_string = "recon-all -sd . -long '#{collection.name}' '#{base_output_name}' -all"
      out_file   = "out#{idx}"
      err_file   = "err#{idx}"
      cmd_out_err_list   << [ cmd_string , out_file, err_file ] 
      recon_all_long_cmd = <<-RECON_SCRIPT
      #
      # Processing longitudinal studies for #{collection.name}
      #

      echo ""
      if test -f #{recon_all_long_log} && grep -q -i -P "recon-all .+ finished without error at" #{recon_all_long_log} ; then
        echo Longitudinal studies for #{collection.name} construction already performed.  
      else
        echo Starting longitudinal studies for #{collection.name} in background.
        #{cmd_string} > #{out_file} 2> #{err_file}  &
      fi
      
      test `jobs | wc -l` -ge #{nb_cpu} && wait

      RECON_SCRIPT
      
      recon_all_long_cmds << recon_all_long_cmd
    end

    recon_all_long_cmds << <<-WAIT_SCRIPT
    
      # Wait for all subprocesses.

      echo ""
      echo Waiting for all subprocesses to finish.
      wait

      echo ""
      echo "Compiling output and error files."
      echo ""
      
    WAIT_SCRIPT

    # Cat in STDOUT and STDERR
    cat_cmds = []
    cmd_out_err_list.each do |sub_list|
      cmd_string, out_file, err_file = sub_list
      cat_cmds  << <<-CAT_SCRIPT
    
      echo ""
      echo "**********************************************"
      echo "* Standard Output for #{cmd_string}:"
      echo "**********************************************"
      if ! -f '#{out_file}' ; then
        echo "No Standard Output."
      else
        cat '#{out_file}'
      fi
        
      echo "" 1>&2
      echo "**********************************************"  1>&2
      echo "* Standard Error for #{cmd_string}:"             1>&2
      echo "**********************************************"  1>&2
      if ! -f '#{err_file}' ; then
        echo "No Standard Error." 1>&2
      else
        cat '#{err_file}' 1>&2
      fi

      CAT_SCRIPT
    end

    [ recon_all_base_cmd ] + recon_all_long_cmds + cat_cmds
  end
  
  def save_results #:nodoc:
    params             = self.params

    collection_ids     = params[:interface_userfile_ids] || []
    collections        = Userfile.find_all_by_id(collection_ids)
    first_coll         = collections[0]
    
    self.results_data_provider_id ||= first_coll.data_provider_id
    
    # Verify if recon-all for base and foreach longitudinal studies.
    base_output_name   = params[:base_output_name]   || "Base"
    long_outputs_names = params[:long_outputs_names] || []
    outputs_name       = [base_output_name] + long_outputs_names
    if outputs_name.empty?
      self.addlog("Recon-all seemed to encounter errors when running.")
      return false
    end

    list_of_error_dir = []
    outputs_name.each do |name|
      log_file = "#{name}/scripts/recon-all.log"
      if !log_file_contains(log_file, /recon-all .+ finished without error at/) 
        list_of_error_dir << name
      end
    end

    # Return false and display log.
    if !list_of_error_dir.empty?
      list = list_of_error_dir.join(", ")
      self.addlog("Freesurfer has encounter a problem with the creation of output(s): #{list}. See Standard Output.")
      return false
    end

    # Save base output.
    outputs_userfiles = []
    base_name         = "#{base_output_name}-#{self.run_id}"
    base_userfile     = safe_userfile_find_or_new(ReconAllBaseOutput,
                :name             => base_name,
                :data_provider_id => self.results_data_provider_id
                )
    base_userfile.cache_copy_from_local_file(base_output_name)
    if base_userfile.save
      base_userfile.move_to_child_of(first_coll)
      self.addlog("Saved base output directory #{base_userfile.name}")
      outputs_userfiles << base_userfile
      params[:base_output_id] = base_userfile.id
    else
      cb_error("Could not save back result file #{base_userfile.name}")
    end
    
    # Save long output(s).
    params[:long_outputs_ids] = []
    long_outputs_names.each do |name|
      long_name       = "#{name}-#{self.run_id}"
      long_userfile   = safe_userfile_find_or_new(ReconAllLongiOutput,
        :name             => long_name,
        :data_provider_id => self.results_data_provider_id
      )
      long_userfile.cache_copy_from_local_file("#{name}")
      if long_userfile.save
        long_userfile.move_to_child_of(first_coll)
        self.addlog("Saved output directory #{long_userfile.name}")
        outputs_userfiles << long_userfile
        params[:long_outputs_ids] << long_userfile.id
      else
        cb_error("Could not save back result file #{long_userfile.name}")
      end
    end

    self.addlog_to_userfiles_these_created_these( collections, outputs_userfiles )

    true
  end


  def restart_at_setup #:nodoc:
    Dir.glob('*').each do |file|
      FileUtils.rm_rf(file)
    end
    true
  end
  
  def restart_at_cluster #:nodoc:
    self.restart_at_setup
    self.setup
  end

  
  private

  def log_file_contains(file, grep_regex) #:nodoc:
    return false unless File.exist?(file)
    file_contain = File.read(file)
    file_contain =~ grep_regex
  end

end

