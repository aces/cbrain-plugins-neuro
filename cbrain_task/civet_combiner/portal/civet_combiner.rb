
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

# A subclass of PortalTask to launch civet_combiner.
class CbrainTask::CivetCombiner < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  task_properties :readonly_input_files, :no_presets

  def self.default_launch_args #:nodoc:
    { :civet_collection_ids => [],
      :civet_study_name     => "Study-#{Time.now.to_i}"
    }
  end

  def before_form #:nodoc:
    adjust_col_list
    ""
  end

  def after_form #:nodoc:
    params = self.params

    adjust_col_list

    civet_collection_ids = params[:civet_collection_ids] || []
    cb_error "No CivetOutput selected." unless civet_collection_ids.size > 0

    study_name           = params[:civet_study_name]     || "(unset?)"
    unless Userfile.is_legal_filename?(study_name)
      cb_error "The name for the study must be a legal CBRAIN filename."
    end

    params[:interface_userfile_ids] = civet_collection_ids # just copy over the clean list

    self.description ||= study_name
    ""
  end

  def untouchable_params_attributes #:nodoc:
    { :civet_collection_ids => true, :prefix => true, :dsids => true, :output_civetstudy_id => true } # Some are set on bourreau side
  end

  private

  # Compatibility transformation; the old param used
  # to store the IDs in a comma separated string
  def adjust_col_list #:nodoc:
    params = self.params

    if params[:civet_collection_ids].is_a?(String)
      params[:civet_collection_ids] = params[:civet_collection_ids].split(/,/)
    end
  end

end

