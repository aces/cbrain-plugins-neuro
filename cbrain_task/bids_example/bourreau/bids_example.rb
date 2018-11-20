
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

    # It's really stupid but we must make a full copy of the dataset locally
    # since symlinks don't work within the singularity container created
    # by bosh (it *would* work with the container created by CBRAIN, nyah nyah)
    cache_source = @bids_dataset.cache_full_path
    captout = "/tmp/capt.#{Process.pid}.#{rand(9999)}"
    capterr = "#{captout}.err"
    system "rsync -a --no-p --no-g --chmod=ugo=rwX #{cache_source.to_s.bash_escape}/ #{@bids_dataset.name.bash_escape} > #{captout} 2> #{capterr}"
    out = File.read(captout) #rescue "Cannot read captured output of rsync"
    err = File.read(capterr) #rescue "Cannot read captured stderr of rsync"
    if out.present?
      # ignore for the moment
    end
    if err.present?
      addlog "Rsync failed to copy dataset: #{err}"
      return false
    end

    return true
  ensure
    File.unlink captout if captout && File.exists?(captout)
    File.unlink capterr if capterr && File.exists?(capterr)
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
      "bosh exec launch #{boutiques_json_path.to_s.bash_escape} #{invoke_json_basename.bash_escape}"
    ]
  end

  # See the CbrainTask Programmer Guide
  def save_results #:nodoc:
    params       = self.params
 
    # Test that output files are there
    true
  end

end

