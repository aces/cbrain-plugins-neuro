
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

# A subclass of CbrainTask to launch FslBedpostx.
class CbrainTask::FslBedpostx < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.default_launch_args #:nodoc:
    {
      :fibres  => "2",
      :weight  => "1",
      :burn_in => "1000"
    }
  end
  
  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids] || []

    messages = ""

    filtered_ids = []
    ids.each do |id|
      fc = FileCollection.find(id) rescue nil
      filtered_ids << fc.id.to_s if fc
    end

    cb_error "No appropriate FileCollection selected." if filtered_ids.size == 0

    if filtered_ids.size != ids.size
      messages = "Not all selected FileCollections seem available. Out of #{ids.size} we retained #{filtered_ids.size}."
    end

    params[:interface_userfile_ids] = filtered_ids

    messages
  end

  def final_task_list #:nodoc:
    ids    = params[:interface_userfile_ids] || []
    mytasklist = []
    ids.each do |id|
      task=self.clone
      task.params[:interface_userfile_ids] = [ id ]
      task.description = Userfile.find(id).name if task.description.blank?
      mytasklist << task
    end
    mytasklist
  end



  ################################################################
  # METHOD: untouchable_params_attributes
  ################################################################
  # This method is part of the advanced API.
  #
  # This method needs to be customized to return a hash table
  # whose keys are the attributes of params that are NOT to
  # be modified by the edit task mechanism. This is useful
  # so that attributes that encode fixed data objects that
  # are created by after_form() or final_task_list() but not
  # present in the task's form are not lost when the user edits
  # the task.
  ################################################################
  
  def untouchable_params_attributes #:nodoc:
    { :outfile_id => true }
  end

end

