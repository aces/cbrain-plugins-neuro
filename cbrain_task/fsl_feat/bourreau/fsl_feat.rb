
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

# A subclass of ClusterTask to run FslFeat.
class CbrainTask::FslFeat < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  # Used to encapsulate the *.fsf (FEAT structure file) for FEAT task.
  class FeatFsfEvaluator #:nodoc:
    Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  end

  def setup #:nodoc:
    params       = self.params
    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    unless inputfile
      self.addlog("Could not find active record entry for file #{inputfile_id}.")
      return false
    end

    inputfile.sync_to_cache
    cache_path = inputfile.cache_full_path
    safe_symlink(cache_path, "#{inputfile.name}")

    self.results_data_provider_id ||= inputfile.data_provider_id

    return true
  end

  def job_walltime_estimate #:nodoc:
    return 4.hours
  end


  def cluster_commands #:nodoc:
    params    = self.params

    # -----------------------------------------------------------------
    # Create the *.fsf (FEAT structure file) for FEAT task.
    # -----------------------------------------------------------------

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)
    cache_path   = inputfile.cache_full_path

    # # Extract nb volumes if is 0
    # if params[:data][:npts] == "0"
    #   fslhd = "fslhd #{cache_path.to_s.bash_escape} | grep -w 'dim4'"
    #   npts = tool_config_system(fslhd).first

    #   npts.gsub!(/dim4/, "")
    #   npts.strip!
    #   if npts.blank?
    #     self.addlog("Could not find number of volumes.")
    #     return false
    #   end
    #   params[:data][:npts] = npts
    # end

    # Define output path and output name
    task_work    = self.full_cluster_workdir
    input_path   = "#{task_work}/#{inputfile.name}"
    output_path  = input_path.sub(/\.nii(\.gz)?$/i , "_#{self.run_id}.feat")
    output_name  = File.basename(output_path)
    params[:output_name] = output_name

    self.addlog("Building FEAT structure file")

    fsf_template   = ""
    plain_name     = self.name.underscore
    full_path      = (Pathname.new(__FILE__).parent + "design.fsf.erb").to_s
    if File.exists?(full_path)
      fsf_template = File.read(full_path)
    else
      cb_error "FEAT structure file template not found: '#{full_path}'"
    end

    fsf_erb        = ERB.new(fsf_template,0,">")

    fsf_erb.def_method(FeatFsfEvaluator, 'render(input_path, params, output_path )', "(FEAT structure file)")
    begin
      fsf_filled = FeatFsfEvaluator.new.render(input_path, params, output_path)
    rescue => ex
      self.addlog("Error building FEAT structure file.")
      self.addlog_exception(ex)
      return false
    end

    File.open("design.fsf", "w") do |fh|
      fh.write fsf_filled
    end


    cmd_feat =  "feat design.fsf"

    cmds     = []
    cmds     << "echo Starting FEAT"
    cmds     << "echo running #{cmd_feat}"
    cmds     << cmd_feat

    cmds
  end

  def save_results #:nodoc:
    params  = self.params
    # user_id = self.user_id

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    # Verify if all feat exit without error. HOW ??
    output_name = params[:output_name]
    unless File.directory?(output_name)
      self.addlog("The cluster job did not produce our 'feat' output?!?")
      return false
    end

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    outputfile   =  safe_userfile_find_or_new(FileCollection, :name => output_name )
    outputfile.save!
    outputfile.cache_copy_from_local_file(output_name)

    self.addlog_to_userfiles_these_created_these( [ inputfile ], [ outputfile ] )
    self.addlog("Saved result file #{output_name}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(inputfile)

    return true
  end

end

