
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

# A subclass of CbrainTask to launch ReconAllLongi.
class CbrainTask::ReconAllLongi < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.default_launch_args #:nodoc:
    {
    }
  end

  def before_form #:nodoc:
    params = self.params
   
    collection_ids  = params[:interface_userfile_ids] || []
    collections     = Userfile.find_all_by_id(collection_ids)
    if collections.size < 2
      cb_error "Error: this task requires at least two input collections of type #{ReconAllCrossSectionalOutput.pretty_type}."
    end
    collections.each do |collection|
      cb_error "Error: this task can only run on collections of type #{ReconAllCrossSectionalOutput.pretty_type}." unless 
        collection.is_a?(ReconAllCrossSectionalOutput)
    end

    return ""
  end

  def after_form #:nodoc:
    params = self.params

    self.params_errors.add(:base_output_name, "provided contains some unacceptable characters.") unless params[:base_output_name].blank? || is_legal_base_name?(params[:base_output_name])
      
    return ""
  end
  
  def untouchable_params_attributes
    { :long_outputs_names => true, :base_output_id => true , :long_outputs_ids => true}
  end
  
end

