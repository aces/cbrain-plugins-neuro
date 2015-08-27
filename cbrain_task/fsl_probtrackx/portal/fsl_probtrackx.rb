
# A subclass of CbrainTask to launch FslProbtrackx.
class CbrainTask::FslProbtrackx < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    {
      :num_samples  => 1000,
      :rseed        => 1,
      :curve_thresh => 0.2,
      :num_steps    => 2000,
      :step_length  => 0.5
    }
  end


  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids]

    userfiles = Userfile.find(ids)

    if userfiles.size == 1 && userfiles.first.is_a?(FileCollection)
      params[:collection_id] = userfiles.first.id
      return ""
    else
      cb_error "Probtrackx must be run on a single collection."
    end
  end

  def untouchable_params_attributes #:nodoc:
    {
      :collection_id => true
    }
  end

  def after_form #:nodoc:
    return ""
  end

end

