
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

# A subclass of CbrainTask to launch Mnc22mnc1.
#
# Original author: Natacha Beck
class CbrainTask::MincConvert < PortalTask

 Revision_info=CbrainFileRevision[__FILE__]


  def self.properties
    { :use_parallelizer => true }
  end
 
  def self.default_launch_args #:nodoc:
    {
      :to_minc2 => "false",
    }
  end

  
  def self.pretty_params_names #:nodoc:
    {
      :to_minc2 => "Convertion way ",
      :template => "Template file ",
      :compress => "Compression level ",
      :chunk    => "Target block size for chunking ",
    }
  end
  
  def before_form
    params   = self.params

    ids    = params[:interface_userfile_ids]
    
    ids.each do |id|                                
      u = Userfile.find(id) rescue nil
      cb_error "Error: the input file for this task doesn't exist anymore." unless u
      cb_error "Error: '#{u.name}' does not seem to be a Minc file."        unless u.is_a?(MincFile)
    end
    ""
  end

  def after_form #:nodoc:
    params = self.params

    # Checks compress
    compress = params[:compress].to_i
    self.params_errors.add(:compress , "must be between -1 and 9" ) unless
      compress.present? && (compress >= -1 && compress <= 9 )
    
    
    # Checks chunk
    chunk = params[:chunk].to_i
    self.params_errors.add(:chunk , "must be greater or equal to -1" ) unless
      chunk.present? && chunk >= -1

    # Checks files types.  
    to_minc2  = params[:to_minc2] == "true" ? true : false
    ids       = params[:interface_userfile_ids] || []

    valid_ids   = []
    list = ""
    ids.each do |id|                                        
      file = Userfile.find(id)
      list += "file #{file.name} MINC2? = #{file.is_a?(Minc2File)} MINC1? = #{file.is_a?(Minc1File)}\n"
      if ( (file.is_a?(Minc2File) && to_minc2 == false) || (file.is_a?(Minc1File) && to_minc2 == true))
        valid_ids << file.id.to_s
      end
    end
    params[:valid_ids] = valid_ids
    
    invalid_files = ""
    invalid_ids = ids - valid_ids
    self.addlog("valid_ids #{valid_ids} invalid_ids #{invalid_ids}" )
    if invalid_ids.size > 0
      invalid_files += "\nThe following files are ignored they seem to already be in the right format:\n "
      invalid_files += (Userfile.find(invalid_ids).map &:name).join(", ")
      invalid_files += "."
    end
    
    "#{invalid_files}"
  end

  def final_task_list #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids] || []
    
    valid_ids = params[:valid_ids] || []
    task_list  = []
    valid_ids.each do |id|
      task=self.clone
      task.params[:inputfile_id]           = id
      task.params[:interface_userfile_ids] = [ id ]
      task.description = Userfile.find(id).name if task.description.blank?
      task_list << task
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :inputfile_id => true, :valid_ids => true, :outfile_id => true, :output_name => true }
  end
  
end

