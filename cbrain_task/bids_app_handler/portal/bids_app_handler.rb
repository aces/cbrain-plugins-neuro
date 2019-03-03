
# A subclass of CbrainTask to launch BidsAppHandler.
class CbrainTask::BidsAppHandler < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    { #:_cb_pipeline     => [],
      #:_cb_sessions     => {},
      #:_cb_participants => {},
    }
  end

  def self.properties #:nodoc:
    {
       :no_submit_button                   => false, # view will not automatically have a submit button
       :i_save_my_task_in_after_form       => false, # used by validation code for detecting coding errors
       :i_save_my_tasks_in_final_task_list => true,  # used by validation code for detecting coding errors
       :no_presets                         => true,  # view will not contain the preset load/save panel
       :use_parallelizer                   => false,  # true or fixnum: turns on parallelization
    }
  end

  def refresh_form_regex #:nodoc:
    /refresh|adjust(ing) pipeline|add\/remove/i
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

    # Initialize the form's list of sessions
    params[:_cb_sessions] ||= {}
    self.bids_dataset.list_sessions.each do |ses|
      params[:_cb_sessions][ses] = '1'
    end

    params[:_cb_pipeline] ||= []

    ""
  end

  def after_form #:nodoc:
    params = self.params

    if self.params[:_cb_pipeline].empty?
      self.params_errors[:_cb_pipeline] = 'needs at least one processing step'
    end

    if selected_participants.empty?
      self.params_errors[:_cb_participants] = 'needs at least one of them selected'
    end

    if self.has_session_label_input? && selected_sessions.empty?
      self.params_errors[:_cb_sessions] = 'needs at least one of them selected'
    end

    # Remove keys needed during pipeline building UI
    self.params.reject! { |k,v| k =~ /^_cb_pipeaction_/ }

    ""
  end

  # Adjust the content of the pipeline list
  def refresh_form
    params = self.params

    to_remove = params.keys
      .select {   |k| k.to_s =~ /^_cb_pipeaction_remove_/ }
      .select {   |k| params[k] == '1' }
      .sort   { |a,b| b <=> a } # must be reverse sorted
      .map    {   |k| k =~ /(\d+)$/ ? Regexp.last_match[1].to_i : nil }
      .compact

    to_add = params.keys
      .select {   |k| k.to_s =~ /^_cb_pipeaction_add_/ }
      .select {   |k| params[k] == '1' }
      .map    {   |k| k =~ /(\d+)$/ ? Regexp.last_match[1].to_i : nil }
      .compact

    messages = ""
    params[:_cb_pipeline] ||= []
    self.params = params.reject { |k,v| k =~ /^_cb_pipeaction_(add|remove)/ }

    # Remove actions just remove one entry in the pipeline list.
    to_remove.each do |rank|
      if rank < params[:_cb_pipeline].size
        removed = params[:_cb_pipeline].slice!(rank,1)
        messages += "Removed stage '#{removed.first}'\n"
      end
    end

    # Add actions just take one of the available analysis_level and
    # append it to the pipeline list.
    to_add.each do |rank|
      to_append = self.analysis_levels[rank]
      next unless to_append.present?
      params[:_cb_pipeline] << to_append
      messages += "Added stage '#{to_append}'\n"
    end

    return messages
  end

  def final_task_list #:nodoc:
    mytasklist = []

    previous_save_task = nil
    batch_id           = nil

    # Each pipeline step can create:
    #   1- (Optionally) a list of subtasks
    #   2- (Mandatory)  a single save or processing task
    # They depend on the successfull completions of previous tasks at previous steps.
    self.params[:_cb_pipeline].each_with_index do |analysis_level,idx|
      step_number = idx + 1 # for pretty descriptions

      subtasklist        = []
      save_task          = nil

      if analysis_level =~ /participant/i
        subtasklist = generate_task_list_for_participants(step_number, analysis_level)
        save_task   = generate_save_task(step_number, analysis_level)
      elsif analysis_level =~ /group/i
        save_task   = generate_task_for_group(step_number, analysis_level)
      elsif analysis_level =~ /session/i
        subtasklist = generate_task_list_for_sessions(step_number, analysis_level)
        save_task   = generate_save_task(step_number, analysis_level)
      else # unknown analysis level?!? pretend it's group
        save_task   = generate_task_for_group(step_number, analysis_level)
      end

      # Create the task array
      subtasklist.each do |task|
        task.add_prerequisites_for_setup(previous_save_task) if previous_save_task
        task.status       = 'New'
        task.level        = idx # for pretty batch view in interface
        task.batch_id     = batch_id
        task.share_wd_tid = batch_id
        task.save!
        batch_id ||= task.id
      end

      # Create save task ; other tasks must be completed before save task runs
      subtasklist.each { |t| save_task.add_prerequisites_for_setup(t) }
      save_task.add_prerequisites_for_setup(previous_save_task) if subtasklist.empty? && previous_save_task
      save_task.status       = 'New'
      save_task.level        = idx # for pretty batch view in interface
      save_task.batch_id     = batch_id
      save_task.share_wd_tid = batch_id
      save_task.save!
      batch_id ||= save_task.id
      previous_save_task = save_task

      # Add to the full list
      mytasklist += subtasklist
      mytasklist << save_task
    end

    # For pretty display of the batch
    mytasklist.each_with_index { |t,cnt| t.update_column(:rank, cnt+1) }

    return mytasklist # just for info since we save them all here
  end

  def generate_task_list_for_participants(step_number, analysis_level) #:nodoc:
    cleaned_up_sessions = self.params[:_cb_sessions].select { |_,zero1| zero1 == '1' }
    tasklist = self.selected_participants.map do |part|
      task = self.dup
      task.params[:_cb_participants] = { part => '1' }
      task.params[:_cb_sessions]     = cleaned_up_sessions.dup
      task.params[:_cb_mode]         = 'participant'
      task.params[:_cb_pipeline]     = [ analysis_level ]
      task.description = "Step #{step_number}, #{analysis_level}: #{part}\n#{self.description}".strip
      task
    end
    tasklist
  end

  def generate_task_list_for_sessions(step_number, analysis_level) #:nodoc:
    cleaned_up_participants = self.params[:_cb_participants].select { |_,zero1| zero1 == '1' }
    tasklist = self.selected_sessions.map do |sess|
      task = self.dup
      task.params[:_cb_participants] = cleaned_up_participants.dup
      task.params[:_cb_sessions]     = { sess => '1' }
      task.params[:_cb_mode]         = 'session'
      task.params[:_cb_pipeline]     = [ analysis_level ]
      task.description = "Step #{step_number}, #{analysis_level}: #{sess}\n#{self.description}".strip
      task
    end
    tasklist
  end

  def generate_save_task(step_number, analysis_level) #:nodoc:
    task = self.dup
    task.params[:_cb_participants] = self.params[:_cb_participants].select { |_,zero1| zero1 == '1' }
    task.params[:_cb_sessions]     = self.params[:_cb_sessions].select     { |_,zero1| zero1 == '1' }
    task.params[:_cb_mode]         = 'save'
    task.params[:_cb_pipeline]     = [ analysis_level ]
    task.description = "Step #{step_number}, Save: #{analysis_level}\n#{self.description}".strip
    task
  end

  def generate_task_for_group(step_number, analysis_level) #:nodoc:
    task = self.dup
    task.params[:_cb_participants] = self.params[:_cb_participants].select { |_,zero1| zero1 == '1' }
    task.params[:_cb_sessions]     = self.params[:_cb_sessions].select     { |_,zero1| zero1 == '1' }
    task.params[:_cb_mode]         = 'group'
    task.params[:_cb_pipeline]     = [ analysis_level ]
    task.description = "Step #{step_number}, #{analysis_level}\n#{self.description}".strip
    task
  end

  def self.pretty_params_names #:nodoc:
    { :_cb_participants => 'List of participants',
      :_cb_pipeline     => 'Processing Pipeline'
    }
  end

  def untouchable_params_attributes #:nodoc:
    { :interface_userfile_ids => true,
      :_cb_mode               => true,
      :_cb_bids_id            => true,
      :_cb_prep_output        => true,
      :_cb_pipeline           => true,
    }
  end

  def unpresetable_params_attributes #:nodoc:
    { :interface_userfile_ids => true,
      :_cb_mode               => true,
      :_cb_bids_id            => true,
      :_cb_prep_output        => true,
      :_cb_pipeline           => true,
    }
  end


end

