
#
# CBRAIN Project
#
# DrmaaCivetCombiner model as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of DrmaaTask to launch civet_combiner.
class DrmaaCivetCombiner < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def self.has_args?
    true
  end
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil)
    { :civet_collection_ids => params[:file_ids] || [],
      :civet_study_name     => (saved_args && saved_args[:civet_study_name]) || "Study-#{Time.now.to_i}"
    }
  end

  #See DrmaaTask.
  def self.launch(params) 

    study_name           = params[:civet_study_name]     || "(unset?)"
    destroy_sources      = params[:destroy_sources]      || nil  # YeS to trigger it
    civet_collection_ids = params[:civet_collection_ids] || []

    unless Userfile.is_legal_filename?(study_name)
      return "The name for the study must be a legal CBRAIN filename."
    end

    return "No CivetCollection selected." unless civet_collection_ids.size > 0

    combiner = DrmaaCivetCombiner.new
    combiner.user_id          = params[:user_id]
    combiner.params = {
      :civet_study_name     => study_name,
      :civet_collection_ids => civet_collection_ids.join(","),
      :destroy_sources      => destroy_sources  # must be the string 'YeS' to trigger it
    }
    combiner.bourreau_id =
      params[:bourreau_id]      if params[:bourreau_id]
    combiner.params[:data_provider_id] =
      params[:data_provider_id] if params[:data_provider_id]
    combiner.description = params[:description]      if ! params[:description].blank?
    combiner.description = params[:civet_study_name] if   params[:description].blank?

    unless combiner.save
      return "Could not launch combiner task."
    end

    "Combiner task launched as '#{combiner.bname_tid}'."

  end
  
  #See DrmaaTask.
  def self.save_options(params)
    { :civet_study_name => params[:civet_study_name] || "Study-#{Time.now.to_i}" }
  end
end

