
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

# A subclass of ClusterTask to run CIVET QC PIPELINE
class CbrainTask::CivetQc < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params

    # Get the ID of the study; it can be given directly
    # in the params, or indirecly through another task ID
    study_id = params[:study_id]
    if study_id.blank?
      task_id = params[:study_from_task_id]
      task = CbrainTask.find(task_id)
      tparams = task.params
      study_id = tparams[:output_civetstudy_id]
      params[:study_id] = study_id # save back
    end
    study = CivetStudy.find(study_id)
    study.sync_to_cache

    # Find out the subject IDs we have; these are stored in
    # yml files in each CivetOutput subdirectory.
    study_path = study.cache_full_path
    dsid_dirs  = Dir.entries(study_path.to_s).reject do |e|
       e == '.' || e == '..' ||
       !File.directory?( study_path + e ) ||
       !File.exist?( study_path + e + "CBRAIN.params.yml")
    end
    if dsid_dirs.size == 0
      self.addlog("Could not find any CivetOutput with params file?")
      return false
    end

    # Check the params structure for each CIVET run
    prefix = nil
    dsid_dirs.each do |dir|
      ymltext        = File.read("#{study_path}/#{dir}/CBRAIN.params.yml")
      civet_params   = YAML.load(ymltext).with_indifferent_access
      file_args      = civet_params[:file_args] || { "0" => {} }
      file0          = file_args["0"] || {}

      # Check that the DSID matches the dir name
      civet_dsid     = file0[:dsid] || civet_params[:dsid] || "(unset)"  # NEW || OLD || unset
      if civet_dsid.to_s != dir
        self.addlog("Error: CivetOutput '#{dir}' is for subject id (DSID) '#{civet_dsid}'.")
        return false
      end

      # Check that all prefixes are the same
      civet_prefix   = file0[:prefix] || civet_params[:prefix] || "(unset)"   # NEW || OLD || unset
      prefix       ||= civet_prefix
      if prefix != civet_prefix
        self.addlog("Error: CivetOutput '#{dir}' is for prefix '#{civet_prefix}' while we found others with '#{prefix}'.")
        return false
      end

      # TODO check other params here to make sure everything is consistent?
    end

    # Creates a 'input' directory for mincfiles by linking to
    # all the files in all the 'native/' subdirs.
    safe_mkdir("mincfiles",0700)
    dsid_dirs.each do |dir|
      native = "#{study_path}/#{dir}/native"
      next unless File.exist?(native) && File.directory?(native)
      Dir.foreach(native) do |minc|
        next unless File.file?("#{native}/#{minc}")
        safe_symlink("#{native}/#{minc}","mincfiles/#{minc}") unless File.exist?("mincfiles/#{minc}")
      end
    end

    # Store the prefix
    params[:prefix] = prefix

    # Store the list of DSIDs in a string in the params
    # If the list is too long, we can use a file in the task's workdir
    dsids_commas = dsid_dirs.join(",")
    if dsids_commas.size < 50000
      params[:dsid_names] = dsids_commas
    else
      params[:dsid_names] = nil # will tell params_subject_ids() below to read from file
    end
    File.open("dsid_names.lst","w") { |fh| fh.write dsid_dirs.join("\n"); fh.write "\n" }

    self.save
    true
  end

  def job_walltime_estimate #:nodoc:
    15.minutes + (2.minutes * (params[:dsid_names] || {}).size)
  end

  def cluster_commands #:nodoc:
    params       = self.params

    study_id = params[:study_id]
    study = CivetStudy.find(study_id)
    study_path = study.cache_full_path

    prefix     = params[:prefix]
    dsid_names = params_subject_ids()
    dsids      = dsid_names.sort.map(&:bash_escape).join(" ")

    civetqc_command = "CIVET_QC_Pipeline -sourcedir mincfiles -targetdir #{study_path.to_s.bash_escape} -prefix #{prefix.bash_escape} #{dsids}"

    if (civetqc_command.size < 1000) # otherwize, we can see it in the logs
      self.addlog("Full CIVET QC command:\n  #{civetqc_command.gsub(/ -/, "\n  -")}")
    end

    return [
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET QC",
      "echo Command: #{civetqc_command}",
      "#{civetqc_command}",
      "test $? -lt 2 && touch has_run"
    ]

  end

  def save_results #:nodoc:
    params       = self.params

    unless File.exist? "has_run"
      self.addlog("Error: it seems that QC didn't run.")
      return false
    end
    File.unlink "has_run"

    # Check for some common error conditions.
    stderr = File.read(self.stderr_cluster_filename) rescue ""
    if stderr =~ /gnuplot.*command not found/i
      self.addlog("Error: it seems 'gnuplot' is not installed on this cluster. QC report incomplete.")
      return false
    elsif stderr =~ /command not found/i
      self.addlog("Error: it seems some command is not installed on this cluster. QC report incomplete.")
      return false
    end

    # Find study object and mark it as changed.
    study_id = params[:study_id]
    study = CivetStudy.find(study_id)
    study_path = study.cache_full_path
    unless Dir.exist?("#{study_path}/QC")
      self.addlog("Error: it seems that QC didn't run.")
      return false
    end

    # Save back study with QC report in it.
    self.addlog("Syncing study with QC reports back to data provider.")
    study.cache_is_newer
    study.sync_to_provider

    # Log that it was processed
    prefix     = params[:prefix]
    dsid_names = params_subject_ids()
    dsids      = dsid_names.sort.join(" ")
    dsids[50..999999] = " ..." if dsids.size > 50
    self.addlog_to_userfiles_processed(study, "with prefix '#{prefix}' and subjects '#{dsids}'")

    true
  end

  protected

  # For historical reason, some old tasks save the list of subjects IDs
  # as a hash with meaningless keys. The new convention is a single
  # long string with commas. Since some times that list is too long to
  # even fit in the params, we can also fetch it from a file.
  def params_subject_ids
    # New comma-separated format
    h = params[:dsid_names].presence
    return h.split(",") if h.is_a?(String)
    # From flat file
    if h.nil?
      return File.read("dsid_names.lst").split(/[\s,]+/)
    end
    # Old hash table format
    dsids = h.values
    params[:dsid_names] = dsids.join(",") # adjust to new convention
    dsids
  end

end

