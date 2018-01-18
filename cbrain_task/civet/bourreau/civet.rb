
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

# Original author: Pierre Rioux, way back when.
# Modified: a bunch of people
# Refactored: too often

# This class runs the CIVET pipeline on one t1 MINC file,
# producing a CivetOutput.
class CbrainTask::Civet < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable, almost! See recover_from_cluster_failure() below.

  def setup #:nodoc:
    params       = self.params        || {}
    file_args    = params[:file_args] || {} # this used to contain many entrie; now just one: "0"

    cb_error("This CIVET task use the old multi-CIVET structure and cannot be restarted.") if file_args.size != 1

    # The main descriptor structure for the current CIVET
    file0        = file_args["0"]          || cb_error("Params structure error!")
    prefix       = file0[:prefix]          || "unkpref"
    dsid         = file0[:dsid]            || "unkdsid"

    self.addlog("Setting up CIVET for subject '#{dsid}'")

    # Main location of symlinks for all input files
    mincfiles_dir = "mincfiles_input"
    safe_mkdir(mincfiles_dir,0700) # may already exist

    # Main location for output files
    safe_mkdir("civet_out",0700) # may already exist

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
    if collection_id # MODE A: collection
      collection = FileCollection.find(collection_id)
      unless collection
        self.addlog("Could not find active record entry for FileCollection '#{collection_id}'.")
        return false
      end
      collection.sync_to_cache
      t1_name = file0[:t1_name]  # cannot be nil
      t2_name = file0[:t2_name]  # can be nil
      pd_name = file0[:pd_name]  # can be nil
      mk_name = file0[:mk_name]  # can be nil
    else # MODE B: singlefiles
      t1_id  = file0[:t1_id]  # cannot be nil
      t1     = SingleFile.find(t1_id)
      unless t1
        self.addlog("Could not find active record entry for singlefile '#{t1_id}'.")
        return false
      end
      file0[:t1_name] = t1.name if file0[:t1_name].blank?
      t1.sync_to_cache
      t2_id  = file0[:t2_id]  # can be nil
      pd_id  = file0[:pd_id]  # can be nil
      mk_id  = file0[:mk_id]  # can be nil
    end

    self.results_data_provider_id ||= collection ? collection.data_provider_id : t1.data_provider_id

    input_symlink_base = prefix.present? ? "#{mincfiles_dir}/#{prefix}_#{dsid}" : "#{mincfiles_dir}/#{dsid}"
    # MODE A (collection) symlinks
    if collection

      t1ext = t1_name.match(/.gz$/i) ? ".gz" : ""
      t1sym = "#{input_symlink_base}_t1.mnc#{t1ext}"
      make_available(collection, t1sym, t1_name)
      return false unless validate_minc_file(t1sym)

      if mybool(file0[:multispectral]) || mybool(file0[:spectral_mask])
        if t2_name.present?
          t2ext = t2_name.match(/.gz$/i) ? ".gz" : ""
          t2sym = "#{input_symlink_base}_t2.mnc#{t2ext}"
          make_available(collection, t2sym, t2_name)
          return false unless validate_minc_file(t2sym)
        end
        if pd_name.present?
          pdext = pd_name.match(/.gz$/i) ? ".gz" : ""
          pdsym = "#{input_symlink_base}_pd.mnc#{pdext}"
          make_available(collection, pdsym, pd_name)
          return false unless validate_minc_file(pdsym)
        end
        if mk_name.present?
          mkext = mk_name.match(/.gz$/i) ? ".gz" : ""
          mksym = "#{input_symlink_base}_mask.mnc#{mkext}"
          make_available(collection, mksym, mk_name)
          return false unless validate_minc_file(mksym)
        end
      end

    else   # MODE B (singlefiles) symlinks

      t1_name = t1.name
      t1ext   = t1_name.match(/.gz$/i) ? ".gz" : ""
      t1sym   = "#{input_symlink_base}_t1.mnc#{t1ext}"
      make_available(t1,t1sym)
      return false unless validate_minc_file(t1sym)

      if mybool(file0[:multispectral]) || mybool(file0[:spectral_mask])
        if t2_id.present?
          t2      = SingleFile.find(t2_id)
          t2_name = t2.name
          t2ext   = t2_name.match(/.gz$/i) ? ".gz" : ""
          t2sym   = "#{input_symlink_base}_t2.mnc#{t2ext}"
          make_available(t2,t2sym)
          return false unless validate_minc_file(t2sym)
        end

        if pd_id.present?
          pd      = SingleFile.find(pd_id)
          pd_name = pd.name
          pdext   = pd_name.match(/.gz$/i) ? ".gz" : ""
          pdsym   = "#{input_symlink_base}_pd.mnc#{pdext}"
          make_available(pd,pdsym)
          return false unless validate_minc_file(pdsym)
        end

        if mk_id.present?
          mk      = SingleFile.find(mk_id)
          mk_name = mk.name
          mkext   = mk_name.match(/.gz$/i) ? ".gz" : ""
          mksym   = "#{input_symlink_base}_mask.mnc#{mkext}"
          make_available(mk,mksym)
          return false unless validate_minc_file(mksym)
        end
      end # if multispectral or spectral_mask
    end # MODE B

    true
  end

  def cluster_commands
    params       = self.params        || {}
    file_args    = params[:file_args] || {}

    cb_error("This CIVET task use the old multi-CIVET structure and cannot be restarted.") if file_args.size != 1

    master_script = [
      "echo =============================",
      "echo Showing ENVIRONMENT",
      "echo =============================",
      "env | sort",
      "echo ''",
      "echo =============================",
      "echo Showing LIMITS",
      "echo =============================",
      "ulimit -a",
      "echo ''"
    ]

    # Clean option and set ignored option
    self.clean_interdependent_params()
    options_to_ignore = self.identify_options_to_ignore()

    # Get commands to run this CIVET task
    comms = self.cluster_commands_single(options_to_ignore)
    return nil if comms.blank? || comms.empty?
    master_script += comms

    # Epilogue of the master script.
    master_script += [
      "echo ''",
      "echo CIVET is done, at `date`",
      "",
      "exit 0",
      ""
    ]

    master_script
  end

  def cluster_commands_single(options_to_ignore={}) #:nodoc:
    params    = self.params
    file_args = params[:file_args] || {} # this used to contain many entrie; now just one: "0"
    file0     = file_args["0"]           # we require this single entry for info on the data files

    prefix = file0[:prefix] || "unkpref"
    dsid   = file0[:dsid]   || "unkdsid"

    is_version_1_1_12          = self.tool_config.is_version("1.1.12")
    is_at_least_version_1_1_12 = self.tool_config.is_at_least_version("1.1.12")
    is_at_least_version_2_0_0  = self.tool_config.is_at_least_version("2.0.0")
    is_at_least_version_2_1_0  = self.tool_config.is_at_least_version("2.1.0")

    # -----------------------------------------------------------
    # More validations of params that are substituted in commands
    # -----------------------------------------------------------

    # Template
    if params[:template].present?
      cb_error "Bad template name."      unless params[:template]     =~ /^\s*[\d\.]+\s*$/
    end

    # Model
    if params[:model].present?
      cb_error "Bad model name."         unless params[:model]        =~ /^\s*[\w\.]+\s*$/
      cb_error "Model is not valid for this CIVET version" if params[:model] == "ADNInl"        && !is_version_1_1_12
      cb_error "Model is not valid for this CIVET version" if params[:model] == "icbm152nl_09a" && !is_at_least_version_2_0_0
      cb_error "Model is not valid for this CIVET version" if params[:model] == "icbm152nl_09s" && !is_at_least_version_1_1_12
      cb_error "Model is not valid for this CIVET version" if params[:model] == "ADNIhires"     && !is_at_least_version_2_0_0
    end

    # Interp
    if params[:interp].present?
      cb_error "Bad interp value."       unless params[:interp]       =~ /^\s*[\w]+\s*$/
    end

    # N3 distance
    if params[:N3_distance].present?
      cb_error "Bad N3 distance value."  unless params[:N3_distance]  =~ /^\s*\d+\s*$/
    end

    # Head height
    if params[:headheight].present?
      cb_error "Bad headheight value."  unless params[:headheight]    =~ /^\s*\d+\s*$/
    end

    # LSQ
    if params[:lsq].present?
      if is_at_least_version_2_1_0
        cb_error "Bad LSQ value."         unless params[:lsq]           =~ /^\s*(?:0|6|9|12)\s*$/
      else
        cb_error "Bad LSQ value."         unless params[:lsq]           =~ /^\s*(?:6|9|12)\s*$/
      end
    end

    # Resamp surf kern area
    if params[:resample_surfaces_kernel_areas].present?
      cb_error "Bad area-FWHM value for resampled surface areas."  unless
                         is_valid_integer_list(params[:resample_surfaces_kernel_areas])
    end

    # Resamp surf kern vol
    if params[:resample_surfaces_kernel_volumes].present?
      cb_error "Bad volume-FWHM value for resampled surface volumes."  unless
                         is_valid_integer_list(params[:resample_surfaces_kernel_volumes])
    end

    # A long argument string
    args = ""

    # A bunch of flags and options
    args += "-no-mpi "                                              if self.tool_config.is_version("2.0.0")
    args += "-make-graph "                                          if mybool(params[:make_graph])
    args += "-make-filename-graph "                                 if mybool(params[:make_filename_graph])
    args += "-print-status-report "                                 if mybool(params[:print_status_report])
    args += "-template #{params[:template].bash_escape} "           if params[:template].present?
    args += "-model #{params[:model].bash_escape} "                 if params[:model].present?
    args += "-surfreg-model #{params[:surfreg_model].bash_escape} " if params[:surfreg_model].present?     && !options_to_ignore[:surfreg_model]
    args += "-interp #{params[:interp].bash_escape} "               if params[:interp].present?
    args += "-N3-distance #{params[:N3_distance].bash_escape} "     if params[:N3_distance].present?
    args += "-headheight #{params[:headheight].bash_escape} "       if params[:headheight].present?        && !options_to_ignore[:headheight]
    args += "-mask-blood-vessels "                                  if mybool(params[:mask_blood_vessels]) && !options_to_ignore[:mask_blood_vessels]
    if params[:lsq] != 0
      args += "-lsq#{params[:lsq]} "                                if params[:lsq] && params[:lsq].to_i != 9 # there is NO -lsq9 option!
    else
      args += "-input_is_stx "
    end
    args += "-no-surfaces "                                         if mybool(params[:no_surfaces])
    args += "-correct-pve "                                         if mybool(params[:correct_pve])
    args += "-hi-res-surfaces "                                     if mybool(params[:high_res_surfaces])  && !options_to_ignore[:high_res_surfaces]
    args += "-combine-surfaces "                                    if mybool(params[:combine_surfaces])

    args += "-multispectral "                                       if mybool(file0[:multispectral])
    args += "-spectral_mask "                                       if mybool(file0[:spectral_mask])

    # PVE
    if is_at_least_version_2_1_0
      if    params[:pve] == "classic"
        args += "-no-correct-pve -no-subcortical -no-mask-cerebellum "
      elsif params[:pve] == "advanced"
        args += "-correct-pve -subcortical -mask-cerebellum "
      end
    end

    # Thickness methods and kernel
    if ( params[:thickness_method].present? &&
         params[:thickness_kernel].present? &&
         is_valid_integer_list(params[:thickness_kernel], allow_blanks: false)
       )
      if is_at_least_version_2_1_0
        thickness_methods = Array(params[:thickness_method])
        thickness_methods = thickness_methods & ["tlaplace", "tlink","tfs"]
        thickness_methods = thickness_methods.unshift(params[:thickness_method_for_qc]) if params[:thickness_method_for_qc].present?
        thickness_string  = thickness_methods.uniq.join(":")
      else
        # Safegard should already be a String
        thickness_string  = Array(params[:thickness_method])[0].to_s
      end
      args += "-thickness #{thickness_string.bash_escape} #{params[:thickness_kernel].bash_escape} "
    end

    # Surface resampling
    if mybool(params[:resample_surfaces])
      args += "-resample-surfaces "

      # Areas and volumes
      args += "-area-fwhm #{params[:resample_surfaces_kernel_areas].bash_escape} "     if params[:resample_surfaces_kernel_areas].present?   && !options_to_ignore[:resample_surfaces_kernel_areas]
      args += "-volume-fwhm #{params[:resample_surfaces_kernel_volumes].bash_escape} " if params[:resample_surfaces_kernel_volumes].present? && !options_to_ignore[:resample_surfaces_kernel_volumes]

      # Atlas
      if params[:atlas].present? && ! options_to_ignore[:atlas]
        atlas_name = params[:atlas].strip
        if is_at_least_version_2_0_0
          args += "-surface-atlas #{atlas_name.bash_escape} "
        else
          args += "-surface-atlas $MNI_CIVET_ROOT/models/AAL_atlas_left.txt $MNI_CIVET_ROOT/models/AAL_atlas_right.txt " if atlas_name == "AAL"
        end
      end
    end

    # VBM
    if mybool(params[:VBM])
        args += "-VBM "
        args += "-VBM-symmetry "                                if mybool(params[:VBM_symmetry])
        args += "-no-VBM-cerebellum "                           if mybool(params[:mask_VBM_cerebellum])
        args += "-VBM-fwhm #{params[:VBM_fwhm].bash_escape} "   if params[:VBM_fwhm].present?
    end

    # ANIMAL
    if mybool(params[:animal])
        args += "-animal "
        args += "-lobe_atlas #{params[:lobe_atlas].bash_escape} "
    end

    # RESET FROM
    reset_from = params[:reset_from]
    if reset_from.present?
      cb_error "Internal error: value for 'reset_from' is not a proper identifier?" unless reset_from =~ /^\w+$/;
      args += "-reset-from #{reset_from.bash_escape} "
    end

    mincfiles_dir  = "mincfiles_input"
    civet_command  = "CIVET_Processing_Pipeline -source #{mincfiles_dir} -target civet_out -spawn #{args} "
    civet_command += "-prefix #{prefix.bash_escape} " if prefix.present?
    civet_command += "-run #{dsid.bash_escape}"       if dsid.present?

    self.addlog("Full CIVET command:\n  #{civet_command.gsub(/ -/, "\n  -")}") if self.user.has_role? :admin_user

    local_script = [
      "echo ==============================================",
      "echo Starting CIVET for subject '#{dsid}'",
      "echo ==============================================",
      "echo Command: #{civet_command.bash_escape}",
      "echo ''",
      "echo 1>&2 ==============================================",
      "echo 1>&2 Standard Error of CIVET for subject '#{dsid}'",
      "echo 1>&2 ==============================================",
      "echo 1>&2 Command: #{civet_command.bash_escape}",
      "echo 1>&2 ''"
    ]

    # Debug mode available to admin: fake ID means no real execution
    fake_id = params[:fake_run_civetcollection_id]
    if fake_id.blank?
      local_script << civet_command  # the real thing
    else
      # Cheating mode (for debugging/development)
      self.addlog("Triggering fake run with pre-saved collection ID '#{fake_id}'.")
      ccol = CivetOutput.find(fake_id)
      ccol.sync_to_cache
      ccol_path = ccol.cache_full_path
      FileUtils.remove_entry("civet_out/#{dsid}",true)
      local_script << "echo Copying fake output\n"
      local_script << "/bin/cp -p -r #{ccol_path.to_s.bash_escape} civet_out/#{dsid}\n"
      local_script << "echo Stopped processing all pipelines." # because we check for that
    end

    # Provide logs of failed stages in STDOUT, if any.
    local_script << <<-"FAILED_STAGED_LOGS"

      # This block will print out the content of the logs
      # of failed stages.
      if test -d civet_out/#{dsid.bash_escape}/logs ; then
        pushd civet_out/#{dsid.bash_escape}/logs >/dev/null
        failed_stages=$(ls -1tr | grep -F .failed | sed -e 's/.failed//')
        for fail in $failed_stages ; do
          echo ""
          echo "--------------------------------------------"
          echo "Logs for failed stage $fail :"
          echo "--------------------------------------------"
          cat $fail.log
        done
        popd >/dev/null
      fi

    FAILED_STAGED_LOGS

    local_script
  end

  def save_results
    params       = self.params        || {}
    file_args    = params[:file_args] || {}

    cb_error("This CIVET task use the old multi-CIVET structure and cannot be restarted.") if file_args.size != 1

    file0  = file_args["0"] || cb_error("Params structure error!")
    dsid   = file0[:dsid]   || "unkdsid"

    self.addlog("Processing results for CIVET '#{dsid}'.")

    # Unique identifier for this run
    uniq_run = self.bname_tid_dashed + "-" + self.run_number.to_s

    # MODE A is with a collection as input, MODE B is a set of input files
    collection_id   = params[:collection_id].presence
    source_userfile = nil # the variable we use to detect modes

    if collection_id  # MODE A FileCollection
      source_userfile = FileCollection.find(collection_id)
    else              # MODE B SingleFile
      t1_id           = file0[:t1_id]
      source_userfile = SingleFile.find(t1_id)
      if file0[:t1_name].blank?
        file0[:t1_name] = source_userfile.name
      end
    end

    # Where we find this subject's results
    out_dsid = "civet_out/#{dsid}"

    # Let's make sure it ran OK, test #1
    unless File.directory?(out_dsid)
      self.addlog("Error: this CIVET run did not complete successfully.")
      self.addlog("We couldn't find the result subdirectory '#{out_dsid}' !")
      return false # Failed On Cluster
    end

    # Let's make sure it ran OK, test #2
    logfiles = Dir.entries("#{out_dsid}/logs")
    running  = logfiles.select { |lf| lf =~ /\.(running|lock)$/i }
    unless running.empty?
      self.addlog("Error: it seems this CIVET run is still processing!")
      self.addlog("We found these files in 'logs' : #{running.sort.join(', ')}")
      self.addlog("Trigger the recovery code to force a cleanup and a try again.")
      return false # Failed On Cluster
    end
    badnews  = logfiles.select { |lf| lf =~ /\.(fail(ed)?)$/i }
    unless badnews.empty?
      failed_t1_trigger = "#{dsid}.nuc_t1_native.failed"
      if badnews.include?(failed_t1_trigger)
         self.addlog("Error: it seems this CIVET run could not process your T1 file!")
         self.addlog("We found this file in 'logs' : #{failed_t1_trigger}")
         self.addlog("The input file is probably not a proper MINC file, there's not much we can do.")
         return false # Failed On Cluster
      end
      self.addlog("Error: not all processing stages of this CIVET completed successfully.")
      self.addlog("We found these files in 'logs' : #{badnews.sort.join(', ')}")
      self.addlog("Trigger the recovery code to force a cleanup and a try again.")
      return false # Failed On Cluster
    end

    # Let's make sure it ran OK, test #3
    out = File.read(self.stdout_cluster_filename) rescue "(No output)"
    if out !~ /^Stopped processing all pipelines/  # ^ in regex because multi-line string
      self.addlog("Error: could not find sentence indicating CIVET finished in its stdout.")
      self.addlog("Trigger the recovery code to force a cleanup and a try again.")
      return false # yep, Failed On Cluster
    end

    # Create new CivetOutput
    out_name    = output_name_from_pattern(file0[:t1_name])
    civetresult = safe_userfile_find_or_new(CivetOutput,
      :name             => out_name,
      :data_provider_id => self.results_data_provider_id
    )
    unless civetresult.save
      cb_error "Could not save back result file '#{civetresult.name}'."
    end

    # Record collection's ID in task's params
    # Now only has one entry, always.
    params[:output_civetcollection_ids] = [ civetresult.id ]

    # Move or copy some useful files into the collection before creating it.
    FileUtils.cp("civet_out/References.txt",    "#{out_dsid}/References.txt")                     rescue true
    FileUtils.cp(self.stdout_cluster_filename,  "#{out_dsid}/logs/CBRAIN_#{uniq_run}.stdout.txt") rescue true
    FileUtils.cp(self.stderr_cluster_filename,  "#{out_dsid}/logs/CBRAIN_#{uniq_run}.stderr.txt") rescue true

    # Transform symbolic links in 'native/' into real files.
    Dir.chdir("#{out_dsid}/native") do
      Dir.foreach(".") do |file|
        next unless File.symlink?(file)
        realsource = File.readlink(file)  # this might itself be a symlink, that's ok.
        File.rename(file,"#{file}.tmp")
        FileUtils.cp_r(realsource,file)
        File.unlink("#{file}.tmp")
      end
    end

    # Dump a serialized file with the contents of the params used to generate
    # this result set.
    run_params_file = "#{out_dsid}/CBRAIN_#{uniq_run}.params.yml"
    params_link     = "#{out_dsid}/CBRAIN.params.yml"
    File.open(run_params_file,"w") do |fh|
      fh.write(params.to_yaml)
    end
    File.unlink(params_link) rescue true
    File.symlink(run_params_file.sub(/.*\//,""),params_link) rescue true

    # Copy the CIVET result's content to the DataProvider's cache (and provider too)
    civetresult.cache_copy_from_local_file(out_dsid)

    # Log information
    self.addlog_to_userfiles_these_created_these([ source_userfile ],[ civetresult ])
    civetresult.move_to_child_of(source_userfile)
    self.addlog("Saved new CIVET result file #{civetresult.name}.")
    true

  end

  # Overrides the placeholder method in the module RecoverableTask
  def recover_from_cluster_failure
    params       = self.params        || {}
    file_args    = params[:file_args] || {}
    file0        = file_args["0"] # we require this single entry for info on the data files
    dsid         = file0[:dsid]   || "unkdsid"

    # Where we find this subject's results
    out_dsid = "civet_out/#{dsid}"
    log_dir  = "#{out_dsid}/logs"

    if File.directory?(out_dsid) && File.directory?(log_dir)
      logfiles = Dir.entries(log_dir)
      badnews  = logfiles.select { |lf| lf =~ /\.(fail(ed)?|running|lock)$/i }
      if badnews.empty?
        self.addlog("No 'failed' files found in logs.")
      else
        self.addlog("Removing these files in 'logs' : #{badnews.sort.join(', ')}")
        badnews.each { |bn| File.unlink("#{out_dsid}/logs/#{bn}") rescue true }
      end
    end

    # In case they dropped out of the cache between first setup and failure recovery:
    resync_input_files()

    true
  end

  private

  # Resync input files, in case we are in recovery from Failed On Cluster.
  def resync_input_files #:nodoc:
    params       = self.params        || {}
    file_args    = params[:file_args] || {}

    cb_error("This CIVET task use the old multi-CIVET structure and cannot be restarted.") if file_args.size != 1

    collection_id = params[:collection_id]
    if collection_id.present? # MODE A: collection
      addlog("Resyncing input FileCollection ##{collection_id}.")
      collection = FileCollection.find(collection_id)
      collection.sync_to_cache
    else # MODE B: individual files
      file0  = file_args["0"].presence || cb_error("Params structure error!")
      t1_id  = file0[:t1_id]  # cannot be nil
      t2_id  = file0[:t2_id]  # can be nil
      pd_id  = file0[:pd_id]  # can be nil
      mk_id  = file0[:mk_id]  # can be nil

      addlog("Resyncing input T1 ##{t1_id}.")
      SingleFile.find(t1_id).sync_to_cache

      if t2_id.present?
        addlog("Resyncing input T2 ##{t2_id}.")
        SingleFile.find(t2_id).sync_to_cache
      end

      if pd_id.present?
        addlog("Resyncing input PD ##{pd_id}.")
        SingleFile.find(pd_id).sync_to_cache
      end

      if mk_id.present?
        addlog("Resyncing input MASK ##{mk_id}.")
        SingleFile.find(mk_id).sync_to_cache
      end
    end

  rescue ActiveRecord::RecordNotFound
    cberror "Cannot find input file. Recovery impossible."
  end

  # Makes a quick check to ensure the input files
  # are really MINC files.
  def validate_minc_file(path) #:nodoc:
    if params[:fake_run_civetcollection_id].present?
      return true # no validation necessary in test 'fake' mode.
    end
    outerr = self.tool_config_system("mincinfo #{path.to_s.bash_escape} 2>&1")
    out    = outerr[0] + outerr[1]
    base = File.basename(path)
    if File.symlink?(path)
      base = File.basename(File.readlink(path)) rescue base
    end
    if out !~ /^file: /m
       self.addlog("Error: it seems one of the input file '#{base}' we prepared is not a MINC file?!?")
       self.addlog("Output of 'mincinfo':\n#{out}") if out.present?
       return false
    end
    true
  end

  # Creates the output filename based on the pattern
  # provided by the user.
  def output_name_from_pattern(t1name)
    file0        = params[:file_args]["0"] # we require this single entry for info on the data files
    prefix       = file0[:prefix] || "unkpref"
    dsid         = file0[:dsid]   || "unkdsid"

    pattern = self.params[:output_filename_pattern] || ""
    pattern.strip!
    pattern = '{subject}-{cluster}-{task_id}-{run_number}' if pattern.blank?

    # Create standard keywords
    now = Time.zone.now
    components = {
      "date"       => now.strftime("%Y-%m-%d"),
      "time"       => now.strftime("%H:%M:%S"),
      "task_id"    => self.id.to_s,
      "run_number" => self.run_number.to_s,
      "cluster"    => self.bourreau.name,
      "subject"    => dsid,
      "prefix"     => prefix
    }

    # Add {1}, {2} etc keywords from t1 name
    t1_comps = t1name.split(/([a-z0-9]+)/i)
    1.step(t1_comps.size-1,2) do |i|
      keyword = "#{(i-1)/2+1}"
      components[keyword] = t1_comps[i]
    end

    # Create new basename
    final = pattern.pattern_substitute(components) # in cbrain_extensions.rb

    # Validate it
    cb_error "Pattern for new filename produces an invalid filename: '#{final}'." unless
      Userfile.is_legal_filename?(final)

    return final
  end

end

