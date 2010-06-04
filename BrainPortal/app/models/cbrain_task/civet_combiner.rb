
#
# CBRAIN Project
#
# CivetCombiner model
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::PortalTask to launch civet_combiner.
class CbrainTask::CivetCombiner < CbrainTask::PortalTask

  Revision_info="$Id$"

  def self.default_launch_args #:nodoc:
    { :civet_collection_ids => [],
      :civet_study_name     => "Study-#{Time.now.to_i}"
    }
  end

  def after_form #:nodoc:
    params = self.params

    civet_collection_ids = params[:civet_collection_ids] || []
    cb_error "No CivetCollection selected." unless civet_collection_ids.size > 0
    params[:civet_collection_ids] = civet_collection_ids.join(",") # to string TODO change to array

    study_name           = params[:civet_study_name]     || "(unset?)"
    unless Userfile.is_legal_filename?(study_name)
      cb_error "The name for the study must be a legal CBRAIN filename."
    end

    self.description ||= study_name
    ""
  end

end

