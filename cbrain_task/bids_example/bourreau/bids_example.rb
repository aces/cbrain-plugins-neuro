
# A subclass of CbrainTask::ClusterTask to run BidsExample.
class CbrainTask::BidsExample < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  #include RestartableTask
  #include RecoverableTask

  # See the CbrainTask Programmer Guide
  def setup #:nodoc:
    params        = self.params
    @bids_dataset = BidsDataset.find(params[:interface_userfile_ids].first)

    addlog("Synchronizing #{@bids_dataset.name}")
    @bids_dataset.sync_to_cache
    make_available(@bids_dataset)

    true
  end

  # See the CbrainTask Programmer Guide
  def cluster_commands #:nodoc:
    params        = self.params
    @bids_dataset = BidsDataset.find(params[:interface_userfile_ids].first)

    # Boutique task descriptor
    boutiques_json_path = File.expand_path('../bids_example.json', __FILE__)

    # Build the bosh invoke JSON file
    outputdir   = "#{@bids_dataset.name}/derivatives/bids-example"
    select_hash = params["proc"]
    participants = select_hash.keys.select { |sub| select_hash[sub] == '1' }

    invoke_json = {
      "bids_dir"          => @bids_dataset.name,
      "output_dir_name"   => outputdir,
      "analysis_level"    => "participant",
      "participant_label" => participants,
    }

    invoke_json_basename = "invoke.#{self.run_id()}.json"
    File.open(invoke_json_basename,"w") do |fh|
      fh.write invoke_json.to_json
    end

    # Run command

    [
      "# This is a bash script for my scientific job",
      "echo Run the bids_example command here",
      "bosh exec launch #{boutiques_json_path.to_s.bash_escape} -i #{invoke_json_basename.bash_escape}"
    ]
  end

  # See the CbrainTask Programmer Guide
  def save_results #:nodoc:
    params       = self.params
    # todo
    true
  end

end

