
# A subclass of ClusterTask to run FslProbtrackx.
class CbrainTask::FslProbtrackx < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ################################################################
  # For full documentation on how to write CbrainTasks,
  # read the file doc/CbrainTask.txt in the subversion trunk.
  # 
  # There are three methods that need to be completed:
  #
  #     setup(),
  #     cluster_commands() and
  #     save_results().
  #
  # These methods have the following properties:
  # 
  #   a) They will all be invoked while Ruby's current directory has already
  #      been changed to a work directory that is 'grid-aware' (usually,
  #      a subdirectory shared by the nodes).
  # 
  #   b) They all receive in their 'params' attribute a hash table containing
  #      the key-value pairs constructed on the BrainPortal side.
  # 
  #   c) Except for cluster_commands(), they should all return true when
  #      everything is OK. A false return value in setup() or save_results()
  #      will cause the object to be stuck to the state "Failed To Setup"
  #      or "Failed On Cluster", respectively.
  # 
  #   d) The method cluster_commands() must returns an array of shell commands.
  # 
  #   e) Make sure you call the appropriate file synchronization methods
  #      for your input files and output files. For files in input,
  #      you can call userfile.sync_to_cache and get a path to the cached
  #      content with userfile.cache_full_path; for files in output,
  #      we recommand you simply call userfile.cache_copy_from_local_file
  #      (for both SingleFile and FileCollections) and the syncronization
  #      steps will be performed for you.
  #
  # There are several additional and OPTIONAL methods that can be implemented
  # to provide the CbrainTask with some error-recovery and partial restarting 
  # capabilities. These are:
  #
  #   recover_from_setup_failure()            # For 'Failed To Setup'
  #   recover_from_cluster_failure()          # For 'Failed On Cluster'
  #   recover_from_post_processing_failure()  # For 'Failed To PostProcess'
  #   restart_at_setup()                      # For any non-error terminal states
  #   restart_at_cluster()                    # For any non-error terminal states
  #   restart_at_post_processing()            # For any non-error terminal states
  #
  # All of these need to return 'true' for the recovering or restarting
  # behavior to be enabled; note that by default none of them return true.
  # The run_number attribute of the task will stay the same for
  # the recover_* operations, while it will be increased by 1
  # for the restart_* operations (after the restart method is called
  # and has returned true). See also CbrainTask_Recovery_Restart.txt.
  #
  # In addition, all tasks have always the ability to recover from
  # failures in prerequisites, and all tasks can be restarted from
  # scratch in a new work directory on the same Bourreau or on another
  # one.
  #
  # Please remove all the comment blocks before committing
  # your code. Provide proper RDOC comments just before
  # each method if you want to document them, but note
  # that normally all normal API methods are #:nodoc: anyway.
  ################################################################

  ################################################################
  # Uncomment the following two lines ONLY if the task has been coded
  # to properly follow the guidelines for recovery and restartability.
  # In that case, these modules will provide the six recover_* and
  # restart_at_* methods that simply all return true.
  ################################################################

  #include RestartableTask
  #include RecoverableTask

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params
    input_collection  = FileCollection.find(params[:collection_id])
    self.results_data_provider_id ||= input_collection.data_provider_id
    input_collection.sync_to_cache
    
    safe_symlink(input_collection.cache_full_path.to_s, input_collection.name)
    
    true
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params          = self.params
    input_collection  = FileCollection.find(params[:collection_id])
    input_collection_name = input_collection.name
    
    mode            = params[:mode].to_s                           #--mode
    curve_thresh    = params[:curve_thresh].to_f                   #-c
    num_steps       = params[:num_steps].to_i                      #-S
    step_length     = params[:step_length].to_f                    #--steplength
    seed_volume     = params[:seed_volume].to_s                    #-x  (path)
    num_samples     = params[:num_samples].to_i                    #-P
    transform       = params[:transform].to_s                      #-xfm (path)
    stop_mask       = params[:stop_mask].to_s                      #--stop (path)
    sample_basename = params[:sample_basename].to_s                #-s (path)
    binary_mask     = params[:binary_mask].to_s                    #-m (path)
    waypoints       = params[:waypoints].to_s                      #--waypoints (path)
    rseed           = params[:rseed].to_i                          #--rseed
    
    name_regex = /^#{input_collection_name}\//
    raise "Seed volume outside task work directory!" if seed_volume !~ name_regex || seed_volume =~ /\.\./
    raise "Transform outside task work directory!" if transform !~ name_regex || transform =~ /\.\./
    raise "Stop mask outside task work directory!" if stop_mask !~ name_regex || stop_mask =~ /\.\./
    raise "Sample basename outside task work directory!" if sample_basename !~ name_regex || sample_basename =~ /\.\./
    raise "Binary mask outside task work directory!" if binary_mask !~ name_regex || binary_mask =~ /\.\./
    raise "Waypoint mask outside task work directory!" if waypoints !~ name_regex || waypoints =~ /\.\./
        
    [
      "probtrackx --mode=#{mode.bash_escape} -x #{seed_volume.bash_escape} -V 1 -c #{curve_thresh} -S #{num_steps} --steplength=#{step_length} -P #{num_samples} --xfm=#{transform.bash_escape} --stop=#{stop_mask.bash_escape} --forcedir --opd -s #{sample_basename} -m #{binary_mask} --dir=output_directory --waypoints=#{waypoints.bash_escape} --rseed=#{rseed}"
    ]
  end
  
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params
    
    input_collection  = FileCollection.find(params[:collection_id])
    unless File.exists?("output_directory")
      cb_error("Output directory doesn't seem to exist!")
    end
    
    now = Time.now
    output_name = "probtrackx-output-#{self.id}-#{self.bourreau.name}-#{self.run_number}-#{now.strftime("%Y-%m-%d")}-#{now.strftime("%H:%M:%S")}"
    
    output_collection = safe_userfile_find_or_new(FileCollection,
      :name             => output_name,
      :data_provider_id => self.results_data_provider_id
    )

    output_collection.cache_copy_from_local_file("output_directory")
    if output_collection.save
      output_collection.move_to_child_of(input_collection)
      params[:output_id] = output_collection.id
      self.addlog("Saved new file collection #{output_collection.name}")
    else
      cb_error("Could not save back result file '#{output_collection.name}'.")
    end
    
    self.addlog_to_userfiles_these_created_these([ input_collection ], [ output_collection ])
    
    true
  end

  def job_walltime_estimate #:nodoc:
    96.hours
  end

  # Add here the optional error-recovery and restarting
  # methods described in the documentation if you want your
  # task to have such capabilities. See the methods
  # recover_from_setup_failure(), restart_at_setup() and
  # friends, described in CbrainTask_Recovery_Restart.txt.

  def recover_from_post_processing_failure #:nodoc:
    true
  end
  
  def restart_at_post_processing #:nodoc:
    true
  end        

end

