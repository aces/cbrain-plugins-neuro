
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

    # Main location of symlinks for all input files
    Dir.mkdir("mincfiles",0700)

    # Main location for output files
    Dir.mkdir("civet_out",0700)

    # We have two modes:
    # (A) We process a T1 (and T2?, PD?, and MK?) file(s) stored inside a FileCollection
    # (B) We process a T1 (and T2?, PD?, and MK?) stored as individual SingleFiles.
    # - We detect (A) when we have a collection_id, and then the
    #   files are specified with :t1_name, :t2_name, etc.
    # - We detect (B) when we have do NOT have a collection ID, and then the
    #   files are specified with :t1_id, :t2_id, etc.

    collection_id = params[:collection_id]
    collection_id = nil if collection_id.blank?
    collection    = nil # the variable we use to detect modes
    if collection_id
      collection = Userfile.find(collection_id)
      unless collection
        self.addlog("Could not find active record entry for FileCollection '#{collection_id}'.")
        return false
      end
      collection.sync_to_cache
      t1_name = params[:t1_name]  # cannot be nil
      t2_name = params[:t2_name]  # can be nil
      pd_name = params[:pd_name]  # can be nil
      mk_name = params[:mk_name]  # can be nil
    else
      t1_id  = params[:t1_id]  # cannot be nil
      t1 = Userfile.find(t1_id)
      unless t1
        self.addlog("Could not find active record entry for singlefile '#{t1_id}'.")
        return false
      end
      t2_id  = params[:t2_id]  # can be nil
      pd_id  = params[:pd_id]  # can be nil
      mk_id  = params[:mk_id]  # can be nil
    end

    # Setting the data_provider_id here means it persists
    # in the ActiveRecord params structure for later use.
    if params[:data_provider_id].blank?
       params[:data_provider_id] = collection.data_provider.id if collection
       params[:data_provider_id] = t1.data_provider.id if ! collection
    end

    # MODE A (collection) symlinks
    if collection
      colpath = collection.cache_full_path.to_s

      t1ext   = t1_name.match(/.gz$/i) ? ".gz" : ""
      File.symlink("#{colpath}/#{t1_name}","mincfiles/#{prefix}_#{dsid}_t1.mnc#{t1ext}")

      if params[:multispectral] || params[:spectral_mask]
        if t2_name
          t2ext = t2_name.match(/.gz$/i) ? ".gz" : ""
          File.symlink("#{colpath}/#{t2_name}","mincfiles/#{prefix}_#{dsid}_t2.mnc#{t2ext}")
        end
        if pd_name
          pdext = pd_name.match(/.gz$/i) ? ".gz" : ""
          File.symlink("#{colpath}/#{pd_name}","mincfiles/#{prefix}_#{dsid}_pd.mnc#{pdext}")
        end
        if mk_name
          mkext = mk_name.match(/.gz$/i) ? ".gz" : ""
          File.symlink("#{colpath}/#{mk_name}","mincfiles/#{prefix}_#{dsid}_mask.mnc#{mkext}")
        end
      end

    else   # MODE B (singlefiles) symlinks

      t1_name     = t1.name
      t1cachename = t1.cache_full_path.to_s
      t1ext       = t1_name.match(/.gz$/i) ? ".gz" : ""
      File.symlink(t1cachename,"mincfiles/#{prefix}_#{dsid}_t1.mnc#{t1ext}")

      if params[:multispectral] || params[:spectral_mask]
        if t2_id
          t2cachefile = Userfile.find(t2_id)
          t2cachefile.sync_to_cache
          t2cachename = t2cachefile.cache_full_path.to_s
          t2ext = t2cachename.match(/.gz$/i) ? ".gz" : ""
          File.symlink(t2cachename,"mincfiles/#{prefix}_#{dsid}_t2.mnc#{t2ext}")
        end

        if pd_id
          pdcachefile = Userfile.find(pd_id)
          pdcachefile.sync_to_cache
          pdcachename = pdcachefile.cache_full_path.to_s
          pdext = pdcachename.match(/.gz$/i) ? ".gz" : ""
          File.symlink(pdcachename,"mincfiles/#{prefix}_#{dsid}_pd.mnc#{pdext}")
        end

        if mk_id
          mkcachefile = Userfile.find(mk_id)
          mkcachefile.sync_to_cache
          mkcachename = mkcachefile.cache_full_path.to_s
          mkext = mkcachename.match(/.gz$/i) ? ".gz" : ""
          File.symlink(mkcachename,"mincfiles/#{prefix}_#{dsid}_mask.mnc#{mkext}")
        end
      end # if multispectral or spectral_mask
    end # mode B

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

