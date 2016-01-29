
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

# A subclass of PortalTask to launch civet_qc.
class CbrainTask::CivetQc < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  task_properties :no_presets

  def before_form #:nodoc:

    params   = self.params
    file_ids = params[:interface_userfile_ids]

    file_ids.each do |id|
      civetstudy = Userfile.find(id)
      unless civetstudy.is_a?(CivetStudy)
        cb_error "This program must be launched on one or several CivetStudy only."
      end
    end

    ""
  end

  def final_task_list #:nodoc:
    params   = self.params
    file_ids = params[:interface_userfile_ids]

    task_list = []

    file_ids.each do |id|
      civetstudy = CivetStudy.find(id)
      task = self.dup # not .clone, as of Rails 3.1.10
      task.description ||= civetstudy.name
      task.params[:study_id]               = civetstudy.id
      task.params[:interface_userfile_ids] = [ civetstudy.id ]
      task_list << task
    end

    task_list
  end

  def untouchable_params_attributes #:nodoc:
    { :study_id => true, :dsid_names => true, :prefix => true }
  end

end

