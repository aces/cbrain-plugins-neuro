
# A subclass of CbrainTask to launch BidsAppHandler.
class CbrainTask::BidsAppHandler < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    { :_cb_launch_group => '1' }
  end

  def before_form #:nodoc:
    params = self.params
    if self.bids_dataset.list_subjects.empty?
      cb_error "This BidDataset doesn't seem to contain any subjects?"
    end

    # Initialize the form's list of participants
    params[:_cb_participants] ||= {}
    self.bids_dataset.list_subjects.each do |sub|
      params[:_cb_participants][sub] = '1'
    end

    ""
  end

  def after_form #:nodoc:
    params = self.params

    if selected_participants.blank?
      self.params_errors[:_cb_participants] = 'need at least one of them selected'
    end

    # If editing a non-participant-level task and the checkbox for group level was changed,
    # adjust to make a group or save level accordingly.
    if ! self.new_record? && params[:_cb_mode] =~ /save|group/
      params[:_cb_mode] = (params[:_cb_launch_group] == '1') ? 'group' : 'save'
    end

    ""
  end

  def self.properties #:nodoc:
    {
       :no_submit_button                   => false, # view will not automatically have a submit button
       :i_save_my_task_in_after_form       => false, # used by validation code for detecting coding errors
       :i_save_my_tasks_in_final_task_list => false, # used by validation code for detecting coding errors
       :no_presets                         => true,  # view will not contain the preset load/save panel
       :use_parallelizer                   => true,  # true or fixnum: turns on parallelization
    }
  end

  def final_task_list #:nodoc:
    mytasklist = []

    selected_participants.each do |sub|
      task=self.dup # not .clone!
      task.params[:_cb_participants] = { sub => '1' } # replace
      task.params[:_cb_mode]         = 'participant'
      task.params[:_cb_launch_group] = "0" # fixed, just to be clean
      task.description               = "Participant: #{sub}\n#{self.description}".strip
      task.share_wd_tid              = -1 # this tells the framework to share all workdirs
      mytasklist << task
    end

    return mytasklist
  end

  def after_final_task_list_saved(tasklist) #:nodoc:

    # Find a sample task amonf the list
    one_part_task = tasklist.detect { |t| t.class == self.class }

    # Template for the final task
    final_task = self.dup

    # Other tasks must be completed before final task runs
    tasklist.each { |t| final_task.add_prerequisites_for_setup(t) }

    # Mode and description
    if params[:_cb_launch_group] == '1'
      final_task.params[:_cb_mode]  = 'group'
      final_task.description        = "Group stage and save\n#{self.description}"
    else
      final_task.params[:_cb_mode]  = 'save'
      final_task.description        = "Final save task\n#{self.description}"
    end

    # Other properties
    final_task.status       = 'New'
    final_task.rank         = tasklist.size + 1
    final_task.level        = 1
    final_task.batch_id     = one_part_task.batch_id
    final_task.share_wd_tid = one_part_task.id

    final_task.save!

    ""
  end

  def self.pretty_params_names #:nodoc:
    { :_cb_participants => 'List of participants' }
  end

  def untouchable_params_attributes #:nodoc:
    { :interface_userfile_ids => true, :_cb_mode => true }
  end

end

