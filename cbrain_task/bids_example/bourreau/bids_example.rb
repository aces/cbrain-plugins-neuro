
# A subclass of CbrainTask::ClusterTask to run BidsExample.
class CbrainTask::BidsExample < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  DERIVATIVES_REL_PATH = "derivatives/bids-example" #:nodoc:

  # See the CbrainTask Programmer Guide
  def setup #:nodoc:
    #params       = self.params # not used here.
    bids_dataset = self.bids_dataset
    captout = nil; capterr = nil # Declared for ensure clause below

    addlog("Synchronizing #{bids_dataset.name}")
    bids_dataset.sync_to_cache

    # It's really stupid but we must make a full copy of the dataset locally
    # since symlinks don't work within the singularity container created
    # by bosh (it *would* work with the container created by CBRAIN, nyah nyah)
    localname = bids_dataset.name # name of copy on work directory
    SyncStatus.ready_to_modify_cache(bids_dataset, "InSync") do # only one process at a time will get the lock for the rsync
      next if File.directory?(localname) # already synced by another process? Good!
      cache_source = bids_dataset.cache_full_path
      captout = "/tmp/capt.#{Process.pid}.#{rand(9999)}"
      capterr = "#{captout}.err"
      system "rsync -a --delete --no-g --chmod=ugo=rwX #{cache_source.to_s.bash_escape}/ #{localname.bash_escape} > #{captout} 2> #{capterr}"
      out = File.read(captout) rescue "Cannot read captured output of rsync"
      err = File.read(capterr) rescue "Cannot read captured stderr of rsync"
      if out.present?
        # ignore for the moment
      end
      if err.present?
        addlog "Rsync failed to copy dataset: #{err}"
        return false
      end
    end

    return true
  ensure
    File.unlink captout if captout && File.exists?(captout)
    File.unlink capterr if capterr && File.exists?(capterr)
  end

  # See the CbrainTask Programmer Guide
  def cluster_commands #:nodoc:
    params       = self.params
    bids_dataset = self.bids_dataset

    return "" if params[:mode] == 'save' # a 'save' task doesn't do any cluster processing

    # Boutique task descriptor
    boutiques_json_path = File.expand_path('../bids_example.json', __FILE__)

    # Output goes to...
    outputdir  = "#{bids_dataset.name}/#{DERIVATIVES_REL_PATH}"

    # Build the bosh 'invoke' JSON structure
    invoke_json = {
      "bids_dir"          => bids_dataset.name.to_s,
      "analysis_level"    => params[:mode],
      "participant_label" => selected_participants(),
      "output_dir_name"   => outputdir,
    }

    # Output goes to... (NOTE: for BidsExample, they cannot be both supplied :-( )
    invoke_json["output_dir_name"]                = outputdir if params[:mode] == 'participant'
    invoke_json["participant_level_analysis_dir"] = outputdir if params[:mode] == 'group'

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
    captout = nil; capterr = nil # Declared for ensure clause below

    mode = params[:mode]

    # Check that we have at least one output file per participant
    outputdir = "#{bids_dataset.name}/#{DERIVATIVES_REL_PATH}"
    glob = Dir.glob "#{outputdir}/*"
    all_ok = true
    selected_participants.each do |sub|
      sublist = glob.select { |p| Pathname.new(p).basename.to_s.starts_with?("sub-#{sub}") }
      if sublist.present?
        self.addlog "Found #{sublist.size} output files for participant '#{sub}'"
      else
        self.addlog "Error: can't find outputs for participant '#{sub}'"
        all_ok = false
      end
    end
    return all_ok if mode == 'participant' # we don't do any saving for participants tasks

    # For mode 'group' or 'save', we just update the BidsDataset in situ
    cache_dir_for_outputs = "#{bids_dataset.cache_full_path}/#{DERIVATIVES_REL_PATH}"
    FileUtils.mkdir_p(cache_dir_for_outputs)

    captout = "/tmp/capt.#{Process.pid}.#{rand(9999)}"
    capterr = "#{captout}.err"
    system "rsync -a --delete --no-g --chmod=ugo=rwX #{outputdir}/ #{cache_dir_for_outputs} > #{captout} 2> #{capterr}"
    out = File.read(captout) rescue "Cannot read captured output of rsync"
    err = File.read(capterr) rescue "Cannot read captured stderr of rsync"
    if out.present?
      # ignore for the moment
    end
    if err.present?
      addlog "Rsync failed to install results in dataset: #{err}"
      return false
    end

    # Marks the BidsDataset as newer and upload back to DP
    bids_dataset.cache_is_newer
    bids_dataset.sync_to_provider
    self.addlog_to_userfiles_processed(bids_dataset)

    return true
  ensure
    File.unlink captout if captout && File.exists?(captout)
    File.unlink capterr if capterr && File.exists?(capterr)
  end

end

