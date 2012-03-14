
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

# A subclass of ClusterTask to run minc_convert.
class CbrainTask::MincConvert < ClusterTask

  
  Revision_info=CbrainFileRevision[__FILE__]

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params       = self.params
    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    unless inputfile
      self.addlog("Could not find active record entry for file #{inputfile_id}")
      return false
    end

    inputfile.sync_to_cache
    cache_path = inputfile.cache_full_path
    safe_symlink(cache_path, "#{inputfile.name}")

    conv_direction     = params[:conv_direction]
    input_minc_version = inputfile.which_minc_version
    if (input_minc_version == "MINC2" && conv_direction == "minc2") || ( input_minc_version == "MINC1" && conv_direction == "minc1")
      self.addlog("Your file is already in the desired format.")
      return false
    end
    
    self.results_data_provider_id ||= inputfile.data_provider_id

    true
  end

  def job_walltime_estimate #:nodoc:
    (0.1 * params[:interface_userfile_ids].count).hours
  end

  def cluster_commands #:nodoc:
    params         = self.params
    conv_direction = params[:conv_direction]
    template       = params[:template]
    compress       = params[:compress]
    chunk          = params[:chunk]
    
    cmds      = []
    cmds      << "echo Starting mincconvert"

    # Minc2 --> Minc1 or Minc1 --> Minc2
    minc2_opt  = "-2" if conv_direction == "minc2"
      
    # Template option
    temp_opt   = template.present? && template == "1" ? "-template" : ""
    temp_add   = template.present? && template == "1" ? "_template" : ""


    # Compress option
    comp_opt   = compress.present? && compress.to_i != -1  ? "-compress #{compress}" : ""

    # Chunk option
    chunk_opt  = chunk.present? && chunk.to_i != -1 ? "-chunk #{chunk}" : "" 

    # Create mincconvert cmd
    inputfile_id = params[:inputfile_id]
    inputfile    = Userfile.find(inputfile_id)

    output  = inputfile.name
    output  = output =~ /(\..+)/ ? output.sub( /(\..+)/ , "_#{conv_direction}#{temp_add}-#{self.run_id}#{$1}") : "#{output}_#{conv_direction}-#{self.run_id}" 

    mincconvert_cmd = "mincconvert #{minc2_opt} #{temp_opt} #{comp_opt} #{chunk_opt} #{inputfile.name} #{output}"
    cmds    << "echo running #{mincconvert_cmd}"
    cmds    << mincconvert_cmd
    
    params[:output_name] = output

    cmds 
  end
  
  def save_results #:nodoc:
    params  = self.params

    output_name      = params[:output_name]
    self.addlog("output_name #{output_name}")
    unless File.exists?(output_name)
      self.addlog("The cluster job did not produce our 'mincconvert' output?!?")
      return false
    end

    inputfile_id = params[:inputfile_id].to_i
    inputfile    = Userfile.find(inputfile_id)

    outtype =  SingleFile
    outtype =  Minc1File if params[:conv_direction] == "minc1"
    outtype =  Minc2File if params[:conv_direction] == "minc2"
    outputfile = safe_userfile_find_or_new(outtype, :name => output_name)

    outputfile.save!
    outputfile.cache_copy_from_local_file(output_name)

    self.addlog_to_userfiles_these_created_these( [ inputfile ], [ outputfile ] )
    self.addlog("Saved result file #{output_name}")
    params[:outfile_id] = outputfile.id
    outputfile.move_to_child_of(inputfile)

    true
  end

end

