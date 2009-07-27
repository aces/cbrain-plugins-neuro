
#
# CBRAIN Project
#
# DrmaaTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of DrmaaTask to run civet.
class DrmaaCivet < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def setup
    params       = self.params
    prefix       = params[:prefix] || "unkpref1"
    dsid         = params[:dsid]   || "unkdsid1"
    mincfile_id  = params[:mincfile_id]

    t2_id        = params[:t2_id]
    pd_id        = params[:pd_id]
    mk_id        = params[:mk_id]

    mincfile     = Userfile.find(mincfile_id)
    unless mincfile
      self.addlog("Could not find active record entry for userfile '#{mincfile_id}'.")
      return false
    end

    mincfile.sync_to_cache
    Dir.mkdir("mincfiles",0700)

    params[:data_provider_id] ||= mincfile.data_provider.id

    cachename    = mincfile.cache_full_path.to_s
    File.symlink(cachename,"mincfiles/#{prefix}_#{dsid}_t1.mnc")

    if params[:multispectral] || params[:spectral_mask]
      if (t2_id)
        t2cachefile = Userfile.find(t2_id)
        t2cachefile.sync_to_cache
        t2cachename = t2cachefile.cache_full_path.to_s
        File.symlink(t2cachename,"mincfiles/#{prefix}_#{dsid}_t2.mnc")
      end

      if (pd_id)
        pdcachefile = Userfile.find(pd_id)
        pdcachefile.sync_to_cache
        pdcachename = pdcachefile.cache_full_path.to_s
        File.symlink(pdcachename,"mincfiles/#{prefix}_#{dsid}_pd.mnc")
      end

      if (mk_id)
        mkcachefile = Userfile.find(mk_id)
        mkcachefile.sync_to_cache
        mkcachename = mkcachefile.cache_full_path.to_s
        File.symlink(mkcachename,"mincfiles/#{prefix}_#{dsid}_mask.mnc")
      end
    end

    Dir.mkdir("civet_out",0700)

    true
  end

  #See DrmaaTask.
  def drmaa_commands
    params = self.params

    prefix = params[:prefix] || "unkpref2"
    dsid   = params[:dsid]   || "unkdsid2"

    args = ""

    args += "-make-graph "                          if params[:make_graph]
    args += "-make-filename-graph "                 if params[:make_filename_graph]
    args += "-print-status-report "                 if params[:print_status_report]
    args += "-template #{params[:template]} "       if params[:template]
    args += "-model #{params[:model]} "             if params[:model]
    args += "-interp #{params[:interp]} "           if params[:interp]
    args += "-N3-distance #{params[:N3_distance]} " if params[:N3_distance]
    args += "-lsq#{params[:lsq]} "                  if params[:lsq] && params[:lsq].to_i != 9
    args += "-no-surfaces "                         if params[:no_surfaces]
    args += "-multispectral "                       if params[:multispectral]
    args += "-spectral_mask "                       if params[:spectral_mask]

    if params[:correct_pve]
        args += "-correct-pve "
    else
        # args += "-no-correct-pve "      # default
    end

    if params[:thickness_method] && params[:thickness_kernel]
        args += "-thickness #{params[:thickness_method]} #{params[:thickness_kernel]} "
    end

    if params[:resample_surfaces]
        args += "-resample-surfaces "
    else
        # args += "-no-resample-surfaces "      # default
    end

    if params[:combine_surfaces]
        args += "-combine-surfaces "
    else
        # args += "-no-combine-surfaces "      # default
    end

    civet_command = "CIVET_Processing_Pipeline -prefix #{prefix} -source mincfiles -target civet_out -spawn #{args} -run #{dsid}"

    self.addlog("Full CIVET command:\n  #{civet_command.gsub(/ -/, "\n  -")}")

    return [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "export PATH=\"#{CBRAIN::CIVET_dir}:$PATH\"",
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET",
      "echo Command: #{civet_command}",
      "#{civet_command}"
    ]

  end

  #See DrmaaTask.
  def save_results
    params       = self.params
    user_id      = self.user_id

    prefix = params[:prefix] || "unkpref2"
    dsid   = params[:dsid]   || "unkdsid2"

    data_provider_id = params[:data_provider_id]

    mincfile_id  = params[:mincfile_id]
    mincfile     = Userfile.find(mincfile_id)
    group_id     = mincfile.group_id 

    civetresult = CivetCollection.new(
      :name             => dsid + "-" + self.id.to_s,
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => data_provider_id,
      :task             => "Civet"
    )
    File.rename("civet_out/References.txt","civet_out/#{dsid}/References.txt") rescue true
    civetresult.cache_copy_from_local_file("civet_out/#{dsid}")

    if civetresult.save
      civetresult.move_to_child_of(mincfile)
      self.addlog("Saved new civet result file #{civetresult.name}.")
      return true
    else
      self.addlog("Could not save back result file '#{civetresult.name}'.")
      return false
    end

  end

end

