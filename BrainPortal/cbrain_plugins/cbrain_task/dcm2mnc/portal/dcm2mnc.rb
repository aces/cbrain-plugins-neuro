
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

#A subclass of PortalTask to launch dcm2mnc.
class CbrainTask::Dcm2mnc < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.properties #:nodoc:
    { :no_presets => true, :use_parallelizer => true }
  end
  
  def before_form #:nodoc:
    params   = self.params
    file_ids = params[:interface_userfile_ids]
    file_ids.each do |col_id|
      col = Userfile.find(col_id)
      cb_error "This program can only run on FileCollections." unless col && col.is_a?(FileCollection)
    end
    ""
  end
    
  def final_task_list #:nodoc:
    params   = self.params
    file_ids = params[:interface_userfile_ids]
    task_list = []
    file_ids.each do |col_id|
      task = self.clone
      task.params[:dicom_colid]            = col_id
      task.params[:interface_userfile_ids] = [ col_id ]
      task_list << task
    end
    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :dicom_colid => true, :created_mincfile_ids => true, :orig_mincfile_basenames => true }
  end

end

