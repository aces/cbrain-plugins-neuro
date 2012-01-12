
#
# CBRAIN Project
#
# CivetCombiner model
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of PortalTask to launch civet_combiner.
class CbrainTask::CivetCombiner < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.properties #:nodoc:
    { :no_presets => true }
  end

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

