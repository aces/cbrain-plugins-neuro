
# A subclass of CbrainTask to launch BidsExample.
class CbrainTask::BidsExample < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    {}
  end

  # Used by form, mostly
  def bids_dataset #:nodoc:
    return @bids_dataset if @bids_dataset
    ids    = params[:interface_userfile_ids] || []
    bid    = ids[0] || -1
    @bids_dataset = BidsDataset.where(:id => bid).first
    cb_error "This task requries a single BidDataset as input" unless @bids_dataset.present?
    @bids_dataset
  end

  def before_form #:nodoc:
    params = self.params
    if self.bids_dataset.list_subjects.empty?
      cb_error "This BidDataset doesn't seem to contain any subjects?"
    end
    params[:proc] ||= {}
    self.bids_dataset.list_subjects.each do |sub|
      params[:proc][sub] = '1'
    end
    ""
  end

  def after_form #:nodoc:
    params = self.params
    # Nothing for the moment
    ""
  end

  def self.properties #:nodoc:
    {
       :no_submit_button                   => false, # view will not automatically have a submit button
       :i_save_my_task_in_after_form       => false, # used by validation code for detecting coding errors
       :i_save_my_tasks_in_final_task_list => false, # used by validation code for detecting coding errors
       :no_presets                         => false, # view will not contain the preset load/save panel
       :use_parallelizer                   => false  # true or fixnum: turns on parallelization
    }
  end

  def final_task_list #:nodoc:
    return [ self ] # default behavior
    # An example: launch ten tasks that differs in params[:count]
    mytasklist = []
    10.times do |count|
      task=self.dup # not .clone, as of Rails 3.1.10
      task.params[:count] = count
      mytasklist << task
    end
    mytasklist
  end

  def after_final_task_list_saved(tasklist) #:nodoc:
    ""
  end

  def untouchable_params_attributes #:nodoc:
    { :interface_userfile_ids => true }
  end

end

