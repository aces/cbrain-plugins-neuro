
# A subclass of CbrainTask::ClusterTask to run BidsExample.
class CbrainTask::BidsExample < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  #include RestartableTask
  #include RecoverableTask

  # See the CbrainTask Programmer Guide
  def setup #:nodoc:
    params       = self.params
    bids_dataset = self.bids_dataset

    addlog("Synchronizing #{bids_dataset.name}")
    bids_dataset.sync_to_cache

    return true
  end

  # See the CbrainTask Programmer Guide
  def cluster_commands #:nodoc:
    params       = self.params
    bids_dataset = self.bids_dataset

    return "" if params[:mode] == 'save' # a 'save' task doesn't do any cluster processing

    # Boutique task descriptor
    boutiques_json_path = File.expand_path('../bids_example.json', __FILE__)

    # Build the bosh 'invoke' JSON structure
    invoke_json = {
      "bids_dir"          => bids_dataset.cache_full_path.to_s,
      "analysis_level"    => params[:mode],
      "participant_label" => selected_participants(),
    }

    # Output goes to...
    outputdir  = "#{bids_dataset.cache_full_path}/derivatives/bids-example" # TODO make basename a param?
    dir_property = (params[:mode] == 'participant') ? "output_dir_name" : "participant_level_analysis_dir"
    invoke_json[dir_property] = outputdir

    # Write it as a file
    invoke_json_basename = "invoke.#{self.run_id()}.json"
    File.open(invoke_json_basename,"w") do |fh|
      fh.write invoke_json.to_json
    end

    # Run command

    [
      "bosh exec launch #{boutiques_json_path.to_s.bash_escape} #{invoke_json_basename.bash_escape}"
    ]
  end

  # See the CbrainTask Programmer Guide
  def save_results #:nodoc:
    params       = self.params
    bids_dataset = self.bids_dataset

    mode = params[:mode]

    # Check that we have at least oen output file per participant
    outputdir = "#{bids_dataset.name}/derivatives/bids-example" # FIXME: copy of code 25 lines above
    glob = Dir.glob "#{outputdir}/*"
    all_ok = true
    selected_participants.each do |sub|
      sublist = glob.select { |p| Pathname.new(p).basename.starts_with?("sub-#{sub}") }
      if sublist.present?
        self.addlog "Found #{sublist.size} output files for participant '#{sub}'"
      else
        self.addlog "Error: can't find outputs for participant '#{sub}'"
        all_ok = false
      end
    end
    return all_ok if mode == 'participant' # we don't do any saving for participants tasks

    # For mode 'group' or 'save', we just update the BidsDataset
    bids_dataset.cache_as_newer
    bids_dataset.sync_to_provider
    self.addlog_to_userfiles_processed(bids_dataset)

    true
  end

end

