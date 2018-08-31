
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

# A subclass of ClusterTask to run Recon-all of FreeSurfer.
#
# Original author: Natacha Beck
class CbrainTask::ReconAll < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  RECON_ALL_STEPS=%w(
    -all
      -autorecon1
      -autorecon2
        -autorecon2-noaseg
        -autorecon2-cp
        -autorecon2-wm
        -autorecon2-pial -autorecon-pial
      -autorecon3
  )

  def setup #:nodoc:
    file_ids  = params[:interface_userfile_ids] || []

    files = Userfile.where(id: file_ids).all.to_a
    files.each do |file|
      self.addlog("Preparing input file '#{file.name}'")
      file.sync_to_cache
      if file.is_a?(MincFile)
        if file.which_minc_version != :minc1
          self.addlog("Recon-all can only run on MINC1.")
          return false
        end
      end
      cache_path = file.cache_full_path
      self.safe_symlink(cache_path, file.name)
    end

    # Copy personal license for FreeSurfer
    license = FreesurferLicense.find_all_accessible_by_user(self.user).first
    if license
      self.addlog("Copying FreeSurfer license file '#{license.name}'")
      license.sync_to_cache
      make_available(license, "license.txt")
    end

    true
  end

  def job_walltime_estimate #:nodoc:
    36.hours
  end

  def cluster_commands #:nodoc:
    params       = self.params
    to_recover   = params.delete(:to_recover)

    # Command creation
    if !to_recover  # NORMAL EXECUTION MODE

      # Simple option
      with_qcache        = params[:with_qcache]      == "1" ? "-qcache"      : ""
      with_mprage        = params[:with_mprage]      == "1" ? "-mprage"      : ""
      with_cw256         = params[:with_cw256]       == "1" ? "-cw256"       : ""
      with_notal_check   = params[:with_notal_check] == "1" ? "-notal-check" : ""
      with_3T_data       = ""
      if params[:with_3T_data] == "1"
        if self.tool_config.is_version("5.1.0")
          with_3T_data = "-nuintensitycor-3T"
        elsif self.tool_config.is_at_least_version("5.3.0")
          with_3T_data = "-3T"
        end
      end
      if params[:with_hippocampal] == "1"
        if !self.tool_config.is_at_least_version("6.0.0")
          with_hippocampal = "-hippo-subfields"
        else
          with_hippocampal = "-hippocampal-subfields-T1"
        end
      end


      # Creation of command line
      file_ids           = params[:interface_userfile_ids] || []
      files              = Userfile.where(id: file_ids).all.to_a
      with_i_option      = true if params[:multiple_subjects] == "Single" || files[0].is_a?(SingleFile)
      subjectid          = with_i_option ? "subjectid-#{self.run_id}" : files[0].name
      params[:subjectid] = subjectid
      subjid_info        = ""
      # Specific for SingleFile
      if with_i_option
        # Potential pb see with Pierre
        FileUtils.rm_rf(subjectid)
        files.map { |f| subjid_info += " -i #{f.name.bash_escape}" }
      else
        remove_is_running_file()
      end
      # For SingleFile or FileCollection
      subjid_info       += " -subjid #{subjectid.bash_escape}"

      step = params[:workflow_directives]
      cb_error "Invalid 'workflow_directives' params" unless RECON_ALL_STEPS.include?(step)
      message            = "Starting Recon-all cross-sectional"
    else # RECOVER FROM FAILURE MODE
      subjectid          = params[:subjectid]
      with_qcache        = ""
      with_mprage        = ""
      subjid_info        = "-s #{subjectid.bash_escape}"
      step               = "-make all"
      message            = "Recovering Recon-all cross-sectional"
    end

    # Special options for recon-all-LBL
    #     -nuintensitycor-3T -N3-3T [number] -nuiterations-3T [number]
    lbl_ext     = ""
    lbl_options = ""
    if self.tool_config.version_name =~ /LBL/
      n3_3t  = (params[:n3_3t].presence  || "").strip
      nui_3t = (params[:nui_3t].presence || "").strip
      if n3_3t.present? && nui_3t.present? && n3_3t =~ /^\d+$/ && nui_3t =~ /^\d+$/
         lbl_ext     = "-LBL"
         lbl_options = "-nuintensitycor-3T -N3-3T #{n3_3t.bash_escape} -nuiterations-3T #{nui_3t.bash_escape}"
      end
    end

    recon_all_command = "recon-all#{lbl_ext} #{with_qcache} #{with_mprage} #{with_3T_data} #{with_cw256} #{with_hippocampal} -sd . #{subjid_info} #{step} #{with_notal_check} #{lbl_options}"

    # Copy license
    cp_license = <<-CP_LICENSE

      # Handle FreeSurfer license

      if [ ! -f "$FREESURFER_HOME/license.txt" ] && [ ! -f "$FREESURFER_HOME/.license" ] ; then
        echo Could not find a license installed.
        if test -f license.txt ; then
          echo Attempting to install the license
          cp license.txt "$FREESURFER_HOME" || exit 20
        fi
      fi

    CP_LICENSE

    [
      cp_license,
      "echo #{message}",
      "echo Command: #{recon_all_command}",
      recon_all_command
    ]

  end

  def save_results #:nodoc:
    params       = self.params

    subjectid    = params[:subjectid]
    output_name  = params[:output_name]

    # Define dp
    file_ids = params[:interface_userfile_ids] || []
    files = Userfile.where(id: file_ids).all.to_a
    self.results_data_provider_id ||= files[0].data_provider_id

    # Check for error
    log_file          = "#{subjectid}/scripts/recon-all.log"
    if !log_file_contains(log_file, /recon-all .+ finished without error at/)
      self.addlog("Recon-all exited with errors. See Standard Output.")
      return false
    end

    # Create and save outfile
    output_name  += "-#{self.run_id}"
    outfile = safe_userfile_find_or_new(ReconAllCrossSectionalOutput,
      :name             => output_name,
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file(subjectid)

    self.addlog_to_userfiles_these_created_these( files , [ outfile ] )
    self.addlog("Saved result file #{output_name}")

    params[:outfile_id] = outfile.id
    outfile.move_to_child_of(files[0])

    true
  end

  # Error-recovery and restarting methods described
  def recover_from_cluster_failure #:nodoc:
    remove_is_running_file()

    true
  end

  private

  def log_file_contains(file, grep_regex) #:nodoc:
    return false unless File.exist?(file)
    file_contain = File.read(file)
    file_contain =~ grep_regex
  end

  def remove_is_running_file #:nodoc:
    subjectid = params[:subjectid]

    # Remove IsRunning file
    files = Dir.glob("#{subjectid}/scripts/IsRunning.*" )
    params[:to_recover] = "yes" if files.size > 0
    files.each do |file|
      FileUtils.rm_rf(file)
    end
  end

end
