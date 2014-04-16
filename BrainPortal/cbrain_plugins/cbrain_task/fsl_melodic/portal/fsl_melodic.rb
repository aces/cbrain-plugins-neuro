
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
      :sorted_structural_file_ids => {}, :sorted_functional_file_ids => {}, :output_name => "melodic-output"
    }
  end
  
  def before_form #:nodoc:

    params   = self.params

    ids    = params[:interface_userfile_ids]
    params[:design_file_id] = -1
    
    params[:structural_file_ids] = []
    params[:functional_file_ids] = []

    ids.each do |id|
      u = Userfile.find(id) rescue nil
      cb_error "Error: input file #{id} doesn't exist." unless u
      cb_error "Error: '#{u.name}' does not seem to be a single file." unless u.is_a?(SingleFile)
      cb_error "Error: you must select only Nifti or design file (found a #{u.type})." unless ( u.is_a?(NiftiFile) || u.is_a?(FSLDesignFile) )
      if u.is_a?(FSLDesignFile)
        cb_error "Error: you may select only 1 design file." unless params[:design_file_id] == -1
        params[:design_file_id] = id
      end
      if u.is_a?(NiftiFile)
        cb_error "Error: Nifti files must be functional or structural." unless u.is_a?(StructuralNiftiFile) || u.is_a?(FunctionalNiftiFile)
        if u.is_a?(StructuralNiftiFile)
          params[:structural_file_ids] << id
        end
        if u.is_a?(FunctionalNiftiFile)
          params[:functional_file_ids] << id
        end
      end
    end
    cb_error "Error: you must select a design file." unless params[:design_file_id] != 1
    cb_error "Error: you must select at least 1 functional Nifti file." unless params[:functional_file_ids].size > 0
    cb_error "Error: you must select an equal number of structural and functional files." unless params[:structural_file_ids].blank? || (params[:structural_file_ids].size == params[:functional_file_ids].size)
    params[:sorted_structural_file_ids] = params[:structural_file_ids].sort_by {|id| u = Userfile.find(id); u.name;}
    params[:sorted_functional_file_ids] = params[:functional_file_ids].sort_by {|id| u = Userfile.find(id); u.name;}
    ""
  end
  
  def after_form #:nodoc:
    output_name = (params[:output_name].strip.eql? "") ? output_name : params[:output_name].strip 
    ""
  end
  
  def final_task_list #:nodoc:
    
    mytasklist = []
    
    params[:sorted_functional_file_ids].each do |func_id|
      
      task=self.dup # not .clone, as of Rails 3.1.10
      task.params[:functional_file_id] = func_id[1]
      task.params[:structural_file_id] = params[:sorted_structural_file_ids].blank? ? nil : params[:sorted_structural_file_ids]["#{mytasklist.size}"]
      task.params[:task_file_ids] = task.params[:structural_file_id].blank? ? [ params[:design_file_id], task.params[:functional_file_id] ] : [ params[:design_file_id], task.params[:functional_file_id], task.params[:structural_file_id] ]
      task.description = Userfile.find(task.params[:functional_file_id]).name if task.description.blank?
      mytasklist << task
      
    end
    
    mytasklist
    
  end
  
  def untouchable_params_attributes #:nodoc:
    { :inputfile_id => true, :output_name => true, :outfile_id => true}
  end
  
end

