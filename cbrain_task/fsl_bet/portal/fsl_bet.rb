
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
# Original author: Natacha Beck
class CbrainTask::FslBet < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties #:nodoc:
    { :use_parallelizer => true }
  end

  def self.default_launch_args #:nodoc:
    {
      :output_name          => "brain",
      :fractional_intensity => 0.5,
      :vertical_gradient    => 0.0,
    }
  end

 def before_form #:nodoc:
    params   = self.params

    ids    = params[:interface_userfile_ids]
    ids.each do |id|
      u = Userfile.find(id) rescue nil
      cb_error "Error: the input file for this task doesn't exist anymore." unless u
      cb_error "Error: '#{u.name}' does not seem to be a single file." unless u.is_a?(SingleFile)
    end
    ""
  end

  def after_form #:nodoc:
    params = self.params

    # Check fractional_intensity option
    fractional_intensity = params[:fractional_intensity]
    self.params_errors.add(:fractional_intensity, "threshold must be between 0 and 1.") unless
      fractional_intensity.present? && fractional_intensity.to_f >= 0 && fractional_intensity.to_f <= 1

    # Check vertical_gradient
    vertical_gradient = params[:vertical_gradient]
    params[:vertical_gradient] = vertical_gradient.to_s
    self.params_errors.add(:vertical_gradient, "in fractional intensity threshold mut be between -1 and 1.") unless
      vertical_gradient.present? && vertical_gradient.to_f >= -1 && vertical_gradient.to_f <= 1

    ""
  end

  def final_task_list #:nodoc:
    ids    = params[:interface_userfile_ids] || []

    mytasklist = []
    ids.each do |id|
      task=self.dup # not .clone, as of Rails 3.1.10
      task.params[:interface_userfile_ids] = [ id ]
      task.params[:inputfile_id]           = id
      task.description = Userfile.find(id).name if task.description.blank?
      mytasklist << task
    end

    mytasklist
  end

  def untouchable_params_attributes #:nodoc:
    { :inputfile_id => true, :final_output_name => true, :outfile_id => true}
  end

end

