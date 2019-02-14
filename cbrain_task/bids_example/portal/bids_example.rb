
# A subclass of CbrainTask to launch BidsExample.
class CbrainTask::BidsExample < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    { :launch_group => '1' }
  end

  def before_form #:nodoc:
    params = self.params
    if self.bids_dataset.list_subjects.empty?
      cb_error "This BidDataset doesn't seem to contain any subjects?"
    end

    # Initialize the form's list of participants
    params[:participants] ||= {}
    self.bids_dataset.list_subjects.each do |sub|
      params[:participants][sub] = '1'
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
       :no_presets                         => true,  # view will not contain the preset load/save panel
       :use_parallelizer                   => true,  # true or fixnum: turns on parallelization
    }
  end

  def final_task_list #:nodoc:
    mytasklist = []

    selected_participants.each do |sub|
      task=self.dup # not .clone!
      task.params[:participants] = { sub => '1' } # replace
      task.params[:mode]          = 'participant'
      task.params.delete             :launch_group # just to be clean
      task.description            = "Part: #{sub}\n#{task.description}"
      mytasklist << task
    end

    mytasklist.each { |t| t.share_wd_tid = -1 } # this tells the framework to share all workdirs

    return mytasklist
  end

  def after_final_task_list_saved(tasklist) #:nodoc:

    one_part_task = tasklist.detect { |t| t.class == self.class } # the tasklist might contain Parallelizers too

    final_task = self.dup
    final_task.share_wd_tid = one_part_task.id
    tasklist.each { |t| final_task.add_prerequisites_for_setup(t) } # other tasks must be completed before final task runs
    final_task.params.delete :launch_group # just to be clean

    if params[:launch_group] == '1'
      final_task.params[:mode]  = 'group'
      final_task.description    = "Group stage and save\n#{self.description}"
    else
      final_task.params[:mode]  = 'save'
      final_task.description    = "Final save task\n#{self.description}"
    end

    final_task.save!

    ""
  end

  def untouchable_params_attributes #:nodoc:
    { :interface_userfile_ids => true, :mode => true }
  end

end

