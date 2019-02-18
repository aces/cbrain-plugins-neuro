
# A subclass of CbrainTask::ClusterTask to run BidsAppHandler.
class CbrainTask::BidsAppHandler < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  Bosh_Required_Version = "0.5.18" # 0.5.18 fails too; waiting for patches, 2019-02-13

  # See the CbrainTask Programmer Guide
  def setup #:nodoc:
    bids_dataset = self.bids_dataset

    mode = params[:_cb_mode]
    return true if mode =~ /save|group/ # a 'save' or 'group' task doesn't need any setup

    # Make sure 'bosh' is recent enough
    return false unless self.bosh_is_supported?

    addlog("Synchronizing #{bids_dataset.name}")
    make_available(bids_dataset, bids_dataset.name)

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

    invoke_json.merge!({
      :bids_dir          => bids_dataset.name,
      :participant_label => selected_participants,
      :analysis_level    => mode,
    })
    if mode == 'participant'
      invoke_json.merge!( { :output_dir_name => outputdir, } )
    end
    if mode == 'group'
      invoke_json.merge!( { :output_dir_name => outputdir, } )
      #invoke_json.merge!( { :participant_level_analysis_dir => outputdir, } )
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
      bosh exec launch                                                \\
        --imagepath #{cached_image.cache_full_path.to_s.bash_escape}  \\
        -v #{cache_dir.to_s.bash_escape}                              \\
        -v #{gridshare_dir.to_s.bash_escape}                          \\
        #{esc_local_dp_mountpoints}                                   \\
        -u -s                                                         \\
        #{boutiques_json_basename.bash_escape}                        \\
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
    if mode == 'participant'
      self.addlog("No output files need saving here, a separate task handles that.")
      return all_ok
    end

    # For provevance logs at the end
    created_outputs = []

    # For mode 'save', we just save each participant's result
    if mode == 'save'
      selected_participants.each do |sub|
        sublist = participants_outputs[sub]
        sublist.each do |one_output| # "outdir/something"
          out_type = File.file?(one_output) ? SingleFile : FileCollection
          basename = Pathname.new(one_output).basename.to_s #hopefully respects CBRAIN legal characters
          cb_out = safe_userfile_find_or_new(out_type,
            { :name => basename + "_" + run_id(), :data_provider_id => dest_dp_id }
          )
          cb_out.cache_copy_from_local_file(one_output)
          cb_out.move_to_child_of( bids_dataset )
          created_outputs << cb_out
        end
      end
    end

    # For mode 'group', we just save the output dir containing all participants outputs
    if mode == 'group'
      group_output_name = 'group_output' + "_" + run_id()
      self.addlog("Attempting to save group results '#{group_output_name}'")
      cb_out = safe_userfile_find_or_new(FileCollection,
        { :name => group_output_name, :data_provider_id => dest_dp_id }
      )
      cb_out.cache_copy_from_local_file(outputdir)
      cb_out.move_to_child_of(bids_dataset)
      created_outputs << cb_out
    end

    # Add provenance logs
    self.addlog_to_userfiles_these_created_these( bids_dataset, created_outputs )

    return true
  end

  protected

  def output_dir_basename_for_batch #:nodoc:
    batch_id = self.batch_id || self.id
    "outdir-#{batch_id}-#{run_number}"
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

end

