
# A subclass of CbrainTask::ClusterTask to run BidsAppHandler.
class CbrainTask::BidsAppHandler < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  Bosh_Required_Version = "0.5.19"

  # See the CbrainTask Programmer Guide
  def setup #:nodoc:
    bids_dataset = self.bids_dataset

    mode = params[:_cb_mode]
    return true if mode =~ /save/ # a 'save' task doesn't need any setup

    # Make sure 'bosh' is recent enough
    return false unless self.bosh_is_supported?

    addlog("Synchronizing #{bids_dataset.name}")
    make_available(bids_dataset, bids_dataset.name)

    prep_output = self.bids_app_prepared_output
    if prep_output
      addlog("Synchronizing #{prep_output.name}")
      prep_output.sync_to_cache
      install_bids_output_once(prep_output, output_dir_basename_for_batch())
    end

    return true
  end

  # See the CbrainTask Programmer Guide
  def cluster_commands #:nodoc:
    params       = self.params
    bids_dataset = self.bids_dataset

    mode         = params[:_cb_mode]
    return "" if mode == 'save' # a 'save' task doesn't do any cluster processing

    # Output goes to...
    outputdir = output_dir_basename_for_batch()
    # Output directory for run
    FileUtils.mkdir_p(outputdir) # we create it here so that 'restart at cluster' work.

    # Build the bosh 'invoke' JSON structure
    invoke_json = params.dup.reject do |property,value|
      (property =~ /^_cb_/) ||
      ([ 'interface_userfile_ids', ].include?(property.to_s))
    end

    # Substitute IDs of input files for their names (probably
    # installed locally by make_available() during setup(), in
    # the subclass). We go back to our descriptor to identify which
    # keys of our invoke_json is a file input.
    identifiers_for_files = self.class.generated_from.descriptor['inputs']
                            .select { |x| x['type'] == 'File' }
                            .map    { |x| x['id']             }
    identifiers_for_files.each do |fid|
      userfile_id = invoke_json[fid].presence
      next unless userfile_id
      userfile_name = Userfile.where(:id => userfile_id).first.name
      self.addlog("Inputfile '#{fid}' is '#{userfile_name}'")
      invoke_json[fid] = userfile_name
    end

    # Analysis level for this task
    analysis_level = analysis_info["name"].presence ||
      cb_error("Can't find analysis level name?!?") # internal error

    # Add the inputs we control as a BidsAppHandler
    invoke_json.merge!({
      :bids_dir          => bids_dataset.name,
      :participant_label => selected_participants,
      :analysis_level    => analysis_level,
    })

    # Session labels are optional, and can occur no matter what
    # type of task.
    if self.has_session_label_input? && self.bids_dataset.list_sessions.present?
      invoke_json.merge!({
        :session_label   => selected_sessions,
      })
    end

    # These code blocks are there in case differences ever
    # emerges when invoking the bidsapp in different modes.
    if mode == 'participant'
      invoke_json.merge!( { :output_dir_name => outputdir, } )
    end
    if mode == 'session'
      invoke_json.merge!( { :output_dir_name => outputdir, } )
    end
    if mode == 'group'
      invoke_json.merge!( { :output_dir_name => outputdir, } )
    end
    if mode == 'direct'
      invoke_json.merge!( { :output_dir_name => outputdir, } )
    end

    # Write it as a file
    invoke_json_basename = "invoke.#{self.run_id()}.json"
    File.open(invoke_json_basename,"w") do |fh|
      fh.write JSON.pretty_generate(invoke_json)
    end

    # Boutique task descriptor.
    # We need the version with all the inputs and also
    # the container image information in it.
    boutiques_json_basename = "boutiques-T#{self.batch_id.presence || self.id}.json"
    unless File.exists? boutiques_json_basename
      descriptor = self.class.full_descriptor
      File.open("#{boutiques_json_basename}.#{Process.pid}.tmp","w") do |fh|
        fh.write JSON.pretty_generate(descriptor)
      end
      File.rename "#{boutiques_json_basename}.#{Process.pid}.tmp", boutiques_json_basename
    end

    # Prepare execution (pulling container image mostly)
    image_basename = "#{self.class}.simg"
    cached_image = SingularityImage.find_or_create_as_scratch(:name => image_basename) do |cache_path|
      self.addlog('Preparing container image')
      out,err = self.tool_config_system(
        "bosh exec prepare --imagepath #{cache_path.to_s.bash_escape} #{boutiques_json_basename}"
      )
      cb_error("Cannot prepare singularity image? Bosh output=\n#{out}#{err}") unless File.exists?(cache_path.to_s)
    end
    self.addlog("Container image prepared: \"#{cached_image.name}\" (ID=#{cached_image.id})")

    #------------------------
    # Mountpoints
    #------------------------

    # Prepare mount paths for local data providers.
    # This will be a string "-v path1:path1 -v path2:path2 -v path3:path3"
    # just like bosh expects.
    # local_dp_storage_paths() is a private method of ClusterTask.
    esc_local_dp_mountpoints = local_dp_storage_paths.inject("") do |sing_opts,path|
      "#{sing_opts} -v #{path.bash_escape}:#{path.bash_escape}"
    end

    # The root of the DataProvider cache
    cache_dir     = self.bourreau.dp_cache_dir

    # The root of the shared area for all CBRAIN tasks
    gridshare_dir = self.bourreau.cms_shared_dir

    #------------------------
    # Simulation checks
    #------------------------

    # Verify the execution command with 'simulate' !
    self.addlog("Running bosh simulation invocation")
    out, err = self.tool_config_system <<-SIMULATE
      bosh exec simulate                       \\
      -i #{invoke_json_basename.bash_escape}   \\
      #{boutiques_json_basename.bash_escape} ; \\
      echo Status=$? 1>&2
    SIMULATE

    # Parse simulation outputs
    first_three_out = out.split(/\n/)[0..2]
    first_three_err = err.split(/\n/)[0..2]
    if ! err.match(/Status=(\d+)\s*$/)
      self.addlog("Simulation command failed: got STDERR:")
      self.addlog(first_three_err)
      cb_error "Simulate command failed" # cannot return true or false here
    end
    retcode = Regexp.last_match[1] # from Status= above
    if retcode != "0"
      self.addlog("Simulation command failed: got status #{retcode} and STDERR:")
      self.addlog(first_three_out)
      cb_error "Simulate command failed" # cannot return true or false here
    end
    self.addlog(first_three_out) # Should be "Generated command:\n[command here]\n"

    #------------------------
    # Main command
    #------------------------

    # The bosh launch command. This is all a single line, but broken up
    # for readability.
    #
    # Note that as of late as bosh 0.5.18, the -v option for mountpoints
    # had a bug and caused a command line parsing failure unless at least
    # one other option is inserted before the boutiques JSON file, thus
    # the "-u -s" inserted below (which are also useful anyway)
    commands = <<-COMMANDS

      # Status preparation
      mkdir -p status.all
      rm -f status.all/#{run_id}

      # Main science command
      bosh exec launch                                                          \\
        --imagepath #{cached_image.cache_full_path.to_s.bash_escape}            \\
        -v #{cache_dir.to_s.bash_escape}:#{cache_dir.to_s.bash_escape}          \\
        -v #{gridshare_dir.to_s.bash_escape}:#{gridshare_dir.to_s.bash_escape}  \\
        #{esc_local_dp_mountpoints}                                             \\
        -u -s                                                                   \\
        #{boutiques_json_basename.bash_escape}                                  \\
        #{invoke_json_basename.bash_escape}

      # Record exit status
      echo $? > status.all/#{run_id}

    COMMANDS
    commands.gsub!(/(\S)  +(\S)/,'\1 \2') # make pretty

    [ commands ]
  end

  # See the CbrainTask Programmer Guide
  def save_results #:nodoc:
    params       = self.params
    bids_dataset = self.bids_dataset
    mode         = params[:_cb_mode]

    # Analysis level for this task
    analysis_level = analysis_info[:name].presence ||
      cb_error("Can't find analysis level name?!?") # internal error

    # DP for destination files
    dest_dp_id = self.results_data_provider_id.presence ||
                 bids_dataset.data_provider_id

    # Check that we have a zero status code from bosh
    if mode != 'save' # a 'save' task doesn't produce a status file
      status = File.read("status.all/#{run_id}").strip rescue 'No status file'
      if status != '0'
        self.addlog("Bosh did not return a success status. Got: #{status}")
        return false
      end
    end

    # Check that we have at least one output file per participant
    outputdir            = output_dir_basename_for_batch()
    glob                 = Dir.glob "#{outputdir}/*"
    all_ok               = true
    participants_outputs = {}
    selected_participants.each do |sub|
      sublist = glob.select { |p| Pathname.new(p).basename.to_s =~ /^sub-#{Regexp.quote(sub)}(\b|_)/ }
      participants_outputs[sub] = sublist
      if sublist.present?
        self.addlog "Found #{sublist.size} output files for participant '#{sub}'"
      else
        self.addlog "Error: can't find outputs for participant '#{sub}'"
        all_ok = false
      end
    end

    # We don't do any saving for participants tasks
    force_save = analysis_info[:save] == '1'
    if (!force_save && (mode == 'participant' || mode == 'session'))
      self.addlog("No output files need saving here, a separate task handles that.")
      return all_ok
    end

    # We just save the output dir containing all files outputs.
    # We use the task's LEVEL to identify and distinguish the analysis step number. TODO add as _cb_step ?
    step_number = (self.level || 0) + 1
    output_name = analysis_info[:savename].presence ||
                  "Step_#{step_number}_#{analysis_level}" + "_" + run_id()
    self.addlog("Attempting to save results '#{output_name}'")
    cb_out = safe_userfile_find_or_new(BidsAppOutput,
      { :name => output_name, :data_provider_id => dest_dp_id }
    )
    cb_out.cache_copy_from_local_file(outputdir)
    cb_out.move_to_child_of(bids_dataset)

    # Add provenance logs
    self.addlog_to_userfiles_these_created_these( bids_dataset, cb_out )

    return true
  end

  protected

  def output_dir_basename_for_batch #:nodoc:
    batch_id = self.batch_id || self.id
    "outdir-#{batch_id}"
  end

  def bosh_is_supported? #:nodoc:
    out, err = self.tool_config_system("bosh version")

    if err.present?
      self.addlog("No proper 'bosh' program (from Boutiques) detected on system. Got STDERR:")
      self.addlog(err)
      return false
    end

    if out.blank?
      self.addlog("No proper 'bosh' program (from Boutiques) detected on system. Got no outputs.")
      return false
    end

    if out !~ /(\d+\.\d+\.\d+)/
      self.addlog("Program 'bosh' (from Boutiques) did not return a version number a.b.c. Got:")
      self.addlog(out)
      return false
    end

    bosh_version = Regexp.last_match[1]
    if ToolConfig.compare_versions(bosh_version, Bosh_Required_Version) < 0
      self.addlog("Program 'bosh' (from Boutiques) is too old. Got version #{bosh_version}, expected at least #{Bosh_Required_Version}")
      return false
    end

    self.addlog("Program 'bosh' (from Boutiques) is version #{bosh_version}")

    true
  end

  # Given a synchronized file collection prep_output, installs
  # a full copy of its cache under basename . This method can
  # safeyl be called in parallel by multiple processes and only
  # one copy will be made, the others will block and return
  # once this is done.
  def install_bids_output_once(prep_output, basename) #:nodoc:
    max_time_to_install = 1.hour
    lockdir             = "#{basename}-lock"
    outerrfile          = "/tmp/capt.rsync.#{Process.pid}-#{rand(100000)}"
    tempdest            = "install-#{Process.pid}-#{rand(100000)}"
    return true if Dir.exists?(basename) # ok, someone did it quickly

    # Copy the content of the userfile to a local temp directory
    begin
      Dir.mkdir lockdir # A failure sends us to the rescue block: it means another process is doing it
      self.addlog("Attempting to install prepared BidsAppOuput #{prep_output.name}")
      src = prep_output.cache_full_path
      # The trailing slash is important in the src argument for rsync below
      ret = system("rsync -a -l --no-p --no-g --chmod=u=rwX,g=rX,o=r --delete #{src.to_s.bash_escape}/ #{tempdest.bash_escape} 1>#{outerrfile} 2>&1")
      outerr = File.read(outerrfile) rescue "(No rsync output)"
      cb_error "Can't seem to rsync prepared BidsAppOutput: message: #{outerr}" unless ret

      # Atomically install the directory and remove the lock
      File.rename tempdest, basename
      Dir.rmdir lockdir
      return true

    # OK, someone else is preparing it? Let's wait
    rescue Errno::EEXIST # normally, from the mkdir above
      self.addlog("Waiting for some other process to install prepared BidsAppOuput #{prep_output.name}")
      start = Time.now
      while Time.now - start < max_time_to_install
        sleep 5
        next if Dir.exists?(lockdir)
        sleep 1
        cb_error "We can't find the prepared output for '#{basename}'..." unless Dir.exists?(basename)
        return true # all is good
      end
      cb_error "Time out waiting for other process to install BidsAppOutput."
    end

  ensure
    # Clean up on aisle #2
    File.unlink(outerrfile)   rescue true # will happen if this process did the rsync
    #FileUtils.rm_rf(tempdest) rescue true # should never happen; comment out to inspect
  end

  # Returns the single tiny structure that describes this analysis level information. E.g.
  #
  #  { :name => 'group1', :save => '1', :savename => 'myname' }
  def analysis_info #:nodoc:
    self.params[:_cb_pipeline]["0"]
  end

end

