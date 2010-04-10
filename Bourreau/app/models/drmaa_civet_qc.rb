
#
# CBRAIN Project
#
# DrmaaCivetQc subclass for running civet_qc
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of DrmaaTask to run civet_qc
class DrmaaCivetQc < DrmaaTask

  Revision_info="$Id$"

  # See DrmaaTask.
  def setup
    params       = self.params
    user_id      = self.user_id

    study_id = params[:study_id]
    study = CivetStudy.find(study_id)
    study.sync_to_cache

    # Find out the subject IDs we have; these are stored in
    # yml files in each CivetCollection subdirectory.
    study_path = study.cache_full_path
    dsid_dirs  = Dir.entries(study_path.to_s).reject do |e|
       e == '.' || e == '..' ||
       !File.directory?( study_path + e ) ||
       !File.exist?( study_path + e + "CBRAIN.params.yml")
    end
    if dsid_dirs.size == 0
      self.addlog("Could not find any CivetCollection with params file?")
      return false
    end

    # Check the params structure for each CIVET run
    prefix = nil
    dsid_dirs.each do |dir|
      ymltext        = File.read("#{study_path}/#{dir}/CBRAIN.params.yml")
      civet_params   = YAML::load(ymltext)

      # Check that the DSID matches the dir name
      civet_dsid     = civet_params[:dsid] || "(unset)"
      if civet_dsid.to_s != dir
        self.addlog("Error: CivetCollection '#{dir}' is for subject id (DSID) '#{civet_dsid}'.")
        return false
      end

      # Check that all prefixes are the same
      civet_prefix   = civet_params[:prefix] || "(unset)"
      prefix       ||= civet_prefix
      if prefix != civet_prefix
        self.addlog("Error: CivetCollection '#{dir}' is for prefix '#{civet_prefix}' while we found others with '#{prefix}'.")
        return false
      end

      # TODO check other params here to make sure everything is consistent?
    end

    # Creates a 'input' directory for mincfiles by linking to
    # all the files in all the 'native/' subdirs.
    Dir.mkdir("mincfiles",0700)
    dsid_dirs.each do |dir|
      native = "#{study_path}/#{dir}/native"
      next unless File.exist?(native) && File.directory?(native)
      Dir.foreach(native) do |minc|
        next unless File.file?("#{native}/#{minc}")
        File.symlink("#{native}/#{minc}","mincfiles/#{minc}") unless File.exist?("mincfiles/#{minc}")
      end
    end

    # Store the list of DSIDs in a hash in the params
    dsid_names = {}  # "Xn" => dsid   where n is some number
    dsid_dirs.each_with_index { |dir,i| dsid_names["X#{i}"] = dir }
    params[:dsid_names] = dsid_names
    params[:prefix]     = prefix

    true
  end

  # See DrmaaTask.
  def drmaa_commands
    params       = self.params
    user_id      = self.user_id

    study_id = params[:study_id]
    study = CivetStudy.find(study_id)
    study_path = study.cache_full_path

    prefix     = params[:prefix]
    dsid_names = params[:dsid_names] # hash, keys are meaningless
    dsids      = dsid_names.values.sort.join(" ")

    civet_command = "CIVET_QC_Pipeline -sourcedir mincfiles -targetdir '#{study_path}' -prefix #{prefix} #{dsids}"

    self.addlog("Full CIVET QC command:\n  #{civet_command.gsub(/ -/, "\n  -")}")

    return [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "export PATH=\"#{CBRAIN::CIVET_dir}:$PATH\"",
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET QC",
      "echo Command: #{civet_command}",
      "#{civet_command}"
    ]

  end
  
  # See DrmaaTask.
  def save_results
    params       = self.params
    user_id      = self.user_id

    prefix     = params[:prefix]
    dsid_names = params[:dsid_names] # hash, keys are meaningless
    dsids      = dsid_names.values.sort.join(" ")

    self.addlog("Syncing study with QC reports back to data provider.")
    study_id = params[:study_id]
    study = CivetStudy.find(study_id)
    study.addlog_context(self,"QC pipeline performed with prefix '#{prefix}' and subjects '#{dsids}'")
    study.cache_is_newer
    study.sync_to_provider
    self.addlog("Done.")

  end

end

