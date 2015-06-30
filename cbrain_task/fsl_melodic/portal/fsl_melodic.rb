
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

# A subclass of CbrainTask to launch FslBet.
#
# Original author: Tristan Glatard
class CbrainTask::FslMelodic < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties #:nodoc:
    { :use_parallelizer => true }
  end

  def self.default_launch_args #:nodoc:
    {
      :output_name => "melodic-output"
    }
  end
  
  def before_form #:nodoc:

    params   = self.params

    ids    = params[:interface_userfile_ids]

    params[:structural_file_ids] = Array.new
    params[:functional_file_ids] = Array.new

    # Checks input files
    ids.each do |id|
      u = Userfile.find(id) rescue nil
      cb_error "Error: input file #{id} doesn't exist." unless u
      cb_error "Error: '#{u.name}' does not seem to be a single file." unless u.is_a?(SingleFile)
      cb_error "Error: you must select a design file and a CSV file containing pairs of functional/structural Nifti file names, separated by commas (found a #{u.type})." unless ( u.is_a?(CSVFile) || u.is_a?(FSLDesignFile) || u.name.end_with?(".csv") || u.name.end_with?(".fsf") )
      if u.is_a?(FSLDesignFile) or u.name.end_with?(".fsf")
        cb_error "Error: you may select only 1 design file." unless params[:design_file_id].nil?
        params[:design_file_id] = id
      end
      if u.is_a?(CSVFile) or u.name.end_with?(".csv")
        cb_error "Error: you may select only 1 CSV file." unless params[:csv_file_id].nil?
        params[:csv_file_id] = id
      end
    end
    cb_error "Error: you must select a design file and a CSV file containing pairs of functional/structural Nifti file names, separated by commas (design file missing)." if params[:design_file_id].nil?
    cb_error "Error: you must select a design file and a CSV file containing pairs of functional/structural Nifti file names, separated by commas (CSV file missing)." if params[:csv_file_id].nil?

    # Parses CSV file
    csv_file = Userfile.find(params[:csv_file_id])
    csv_file.sync_to_cache unless csv_file.is_locally_synced?
    lines = CSVFile.new.create_csv_array("\"",",",csv_file) # third parameter needed when csv_file is not a CSVFile. Might be cleaner to define create_csv_array as a class method of CSVFile.
    lines.each do |line|
      cb_error "Error: lines in CSV file must contain two elements separated by a comma (wrong format: #{line})." unless line.size == 2
      line.each_with_index do |file_name,index|
        file_name.strip!
        # Checks files in line
        cb_error "Error: file #{file_name} (present in #{csv_file.name}) doesn't look like a Nifti or MINC file (must have a .mnc, .nii or .nii.gz extension)" unless file_name.end_with? ".nii" or file_name.end_with? ".nii.gz" or file_name.end_with? ".mnc"
        file_array = Userfile.where(:name => file_name)
        cb_error "Error: file #{file_name} (present in #{csv_file.name}) not found!" unless file_array.size > 0
        cb_error "Error: multiple files found for #{file_name} (present in #{csv_file.name})" if file_array.size > 1 # this shouldn't happen.
        # Assigns files
        file_id = file_array.first.id
        if index == 0
          params[:functional_file_ids] << file_id
        else
          params[:structural_file_ids] << file_id
        end
      end
      
    end
    ""
  end
  
  def after_form #:nodoc:
    output_name = (params[:output_name].strip.eql? "") ? output_name : params[:output_name].strip 
    ""
  end
  
  def final_task_list #:nodoc:
    mytasklist = []
    n_tasks    = params[:functional_file_ids].size-1
    (0..n_tasks).each do |i|
      task=self.dup # not .clone, as of Rails 3.1.10
      task.params[:functional_file_id] = params[:functional_file_ids]["#{i}"]
      task.params[:structural_file_id] = params[:structural_file_ids]["#{i}"]
      task.params[:task_file_ids] = [ params[:design_file_id], task.params[:functional_file_id], task.params[:structural_file_id] ]
      task.description = Userfile.find(task.params[:functional_file_id]).name if task.description.blank?
      # clean task parameters
      task.params.delete :functional_file_ids
      task.params.delete :structural_file_ids
      task.params.delete :interface_userfile_ids
      mytasklist << task
    end
    return mytasklist
  end
  
  def untouchable_params_attributes #:nodoc:
    { :inputfile_id => true, :output_name => true, :outfile_id => true}
  end
  
end

