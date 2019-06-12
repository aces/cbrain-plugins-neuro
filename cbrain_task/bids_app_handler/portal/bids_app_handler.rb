
# A subclass of CbrainTask to launch BidsAppHandler.
class CbrainTask::BidsAppHandler < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.default_launch_args #:nodoc:
    { #:_cb_pipeline     => [],
      #:_cb_sessions     => {},
      #:_cb_participants => {},
      :_cb_output_renaming_pattern => '{bids_name}-Step{step}-{analysis_level}-{task_id}-{run_number}',
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

    # An set of structures that contains a list of analysis_levels, and whether to save the intermediate results
    # { :name => 'analysis_level_name', :save => truefalse, :savename => 'mytempout' }
    # Keys are string numbers "0", "1", "2" etc
    params[:_cb_pipeline]                  ||= {}

    # The desription shown to user initially; when task
    # arrays are created, more info will be added to it.
    self.description = self.bids_dataset.name if self.description.blank?

    ""
  end

  def after_form #:nodoc:

    if self.params[:_cb_pipeline].blank?
      self.params_errors[:_cb_pipeline] = 'needs at least one processing step'
    end
    self.params[:_cb_pipeline] ||= {}

    if selected_participants.empty?
      self.params_errors[:_cb_participants] = 'needs at least one of them selected'
    end

    if self.has_session_label_input? && self.bids_dataset.list_sessions.present? && selected_sessions.empty?
      self.params_errors[:_cb_sessions] = 'needs at least one of them selected'
    end

    # When editing a task that can save, we copy the global output_renaming_pattern
    # to the local save name.
    if (! self.new_record?) && (params[:_cb_pipeline]["0"][:save] == '1')
      params[:_cb_pipeline]["0"][:savename] = params[:_cb_output_renaming_pattern]
    end

    # Verify valid names
    self.params[:_cb_pipeline].each do |idx,struct|
      savename = struct[:savename]
      next if savename.blank?
      # This is cumbersome, but it's the only way to test the
      # validity of the file name, because the code is in a stupid model validator
      # Note: we replace a leading curly bracket '{' for a 'X' because the curly bracket
      # is legal in a filename pattern even though it's not in a filename (they're ok
      # later in the string though).
      fake_userfile = FileCollection.new(:name => savename.sub(/\A\{/,"X"))
      fake_userfile.validate
      if fake_userfile.errors[:name].present?
        self.params_errors["_cb_pipeline[#{idx}][savename]"] = 'contains invalid characters in file name'
      end
    end

    # If editing a 'save' task for participants or sessions, then adjust prerequisites
    if (! self.new_record?) && (params[:_cb_mode] == 'save')
      adjust_prerequisites()
    end

    # Remove keys only needed during pipeline building UI
    self.params.reject! { |k,v| k =~ /^_cb_pipeaction_/ }

    # Make sure last stage has "save" option set!
    if self.errors.empty?
      lastkey = self.params[:_cb_pipeline].keys.sort { |a,b| a.to_i <=> b.to_i }.last
      if self.params[:_cb_pipeline][lastkey]['save'] != '1'
        self.params[:_cb_pipeline][lastkey]['save'] = '1'
        self.addlog "Information: forced 'save' option for last step '#{self.params[:_cb_pipeline][lastkey]['name']}'."
      end
    end

    "" # api requires empty string, or a message when in error
  end

  # Adjust the content of the pipeline list
  def refresh_form
    params = self.params

    to_remove = params.keys
      .select {   |k| k.to_s =~ /^_cb_pipeaction_remove_/ }
      .select {   |k| params[k] == '1' }
      .sort   { |a,b| b <=> a } # must be reverse sorted
      .map    {   |k| k =~ /(\d+)$/ ? Regexp.last_match[1] : nil }
      .compact

    to_add = params.keys
      .select {   |k| k.to_s =~ /^_cb_pipeaction_add_/ }
      .select {   |k| params[k] == '1' }
      .map    {   |k| k =~ /(\d+)$/ ? Regexp.last_match[1] : nil }
      .compact

    messages = ""
    params[:_cb_pipeline]                  ||= {}
    self.params = params.reject { |k,v| k =~ /^_cb_pipeaction_(add|remove)/ }

    # Remove actions just remove one entry in the pipeline list.
    to_remove.each do |rank| # rank is a string such as "0" or "12"
      removed = params[:_cb_pipeline].delete(rank)
      messages += "Removed stage '#{removed[:name]}'\n" if removed
    end

    # Add actions just take one of the available analysis_level and
    # append it to the pipeline list.
    to_add.each_with_index do |rank,idx| # rank is a string such as "0" or "12"
      to_append = self.analysis_levels[rank.to_i]
      next unless to_append.present?
      params[:_cb_pipeline][(1000+idx).to_s] =  { # we temporarily give it a large key such as "1001"
        :name     => to_append,
        :save     => '0',
        :savename => '',
      }
      messages += "Added stage '#{to_append}'\n"
    end

    # Rehash the pipeline list so the we get consecutive numbers in the string keys. Aaaargh.
    ordered_structs = params[:_cb_pipeline].keys.sort { |a,b| a.to_i <=> b.to_i }.map do |strnum|
      params[:_cb_pipeline][strnum]
    end
    self.params[:_cb_pipeline] = {}
    ordered_structs.each_with_index do |struct,idx|
      self.params[:_cb_pipeline][idx.to_s] = struct
    end

    return messages
  end

  def self.override_final_task_list #:nodoc:
    true
  end

  def final_task_list #:nodoc:
    mytasklist = []

    previous_save_task = nil
    batch_id           = nil

    # Remove the BidsDataset name from the description if it's still there.
    # It will be reinserted later in each tasks of the arrays.
    bids_name = self.bids_dataset.name
    desc = self.description.presence || ""
    desc[bids_name] = '' if desc.index(bids_name) # zap substring
    self.description = desc.strip

    # Each pipeline step can create:
    #   1- (Optionally) a list of subtasks
    #   2- (Mandatory)  a single save or processing task
    # They depend on the successfull completions of previous tasks at previous steps.
    self.params[:_cb_pipeline].keys.sort { |a,b| a.to_i <=> b.to_i }.each_with_index do |strnum,idx|
      analysis_struct = self.params[:_cb_pipeline][strnum]
      analysis_level  = analysis_struct[:name]
      step_number     = idx + 1 # for pretty descriptions

      subtasklist        = []
      save_task          = nil

      if analysis_level =~ /participant/i
        subtasklist = generate_task_list_for_participants(step_number, analysis_struct)
        cb_error "Unexpectedly, created an empty list of tasks for participants." if subtasklist.blank?
        save_task   = generate_save_task(step_number, analysis_struct) if subtasklist.size > 1
      elsif analysis_level =~ /group/i
        save_task   = generate_task_for_analysis(step_number, analysis_struct, 'group')
      elsif analysis_level =~ /session/i
        subtasklist = generate_task_list_for_sessions(step_number, analysis_struct)
        # Note: the case where subtasklist.size == 1 is handled below
        if subtasklist.size > 1 # means we could select multiple sessions
          save_task = generate_save_task(step_number, analysis_struct)
        elsif subtasklist.size == 0 # a more generic handler, a single 'session' task when no session names are selectable
          save_task = generate_task_for_analysis(step_number, analysis_struct, 'session')
        end
      else # unknown analysis level?!? just schedule it and hope for the best
        save_task   = generate_task_for_analysis(step_number, analysis_struct, 'direct')
      end

      # In the case where subtasklist contains only one task, and
      # save task is nil, then the task in subtasklist BECOMES the save task.
      if subtasklist.size == 1 && save_task.nil?
        save_task = subtasklist.pop # empties subtasklist too
        save_task.params[:_cb_pipeline]["0"]["save"] = "1"
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

  def generate_task_list_for_participants(step_number, analysis_struct) #:nodoc:
    bids_name      = self.bids_dataset.name
    no_save_struct = analysis_struct.dup
    no_save_struct[:save] = '0'
    tasklist = self.selected_participants.map do |part|
      task = self.dup
      task.params[:_cb_participants] = { part => '1' }
      task.params[:_cb_sessions]     = cleaned_up_sessions
      task.params[:_cb_mode]         = 'participant'
      task.params[:_cb_pipeline]     = { "0" => no_save_struct }
      task.description = "#{bids_name} step #{step_number}, #{analysis_struct[:name]}: #{part}\n#{self.description}".strip
      adjust_task_output_names_patterns(task)
      task
    end
    tasklist
  end

  def generate_task_list_for_sessions(step_number, analysis_struct) #:nodoc:
    bids_name      = self.bids_dataset.name
    no_save_struct = analysis_struct.dup
    no_save_struct[:save] = '0'
    tasklist = self.selected_sessions.map do |sess|
      task = self.dup
      task.params[:_cb_participants] = cleaned_up_participants
      task.params[:_cb_sessions]     = { sess => '1' }
      task.params[:_cb_mode]         = 'session'
      task.params[:_cb_pipeline]     = { "0" => no_save_struct }
      task.description = "#{bids_name} step #{step_number}, #{analysis_struct[:name]}: #{sess}\n#{self.description}".strip
      adjust_task_output_names_patterns(task)
      task
    end
    tasklist
  end

  def generate_save_task(step_number, analysis_struct) #:nodoc:
    bids_name = self.bids_dataset.name
    task      = self.dup
    task.params[:_cb_participants] = cleaned_up_participants
    task.params[:_cb_sessions]     = cleaned_up_sessions
    task.params[:_cb_mode]         = 'save' # no setup, no cluster commands, just save
    task.params[:_cb_pipeline]     = { "0" => analysis_struct.dup }
    task.description = "#{bids_name} step #{step_number}, Save: #{analysis_struct[:name]}\n#{self.description}".strip
    adjust_task_output_names_patterns(task)
    task
  end

  def generate_task_for_analysis(step_number, analysis_struct, mode = 'direct') #:nodoc:
    bids_name = self.bids_dataset.name
    task      = self.dup
    task.params[:_cb_participants] = cleaned_up_participants
    task.params[:_cb_sessions]     = cleaned_up_sessions
    task.params[:_cb_mode]         = mode # 'direct' means just invoke this as-is
    task.params[:_cb_pipeline]     = { "0" => analysis_struct.dup }
    task.description = "#{bids_name} step #{step_number}, #{analysis_struct[:name]}\n#{self.description}".strip
    adjust_task_output_names_patterns(task)
    task
  end

  # Ugly helper to make sure we get the same value in the
  # local vs global name pattern entries. Necessary for editing tasks.
  def adjust_task_output_names_patterns(task) #:nodoc:
    local_name  = task.params[:_cb_pipeline]["0"][:savename].presence
    global_name = task.params[:_cb_output_renaming_pattern].presence
    if local_name
      task.params[:_cb_output_renaming_pattern]  = (local_name  || "") # crush global name
    else
      task.params[:_cb_pipeline]["0"][:savename] = (global_name || "")
    end
  end

  # When editing a save task, if the user checked or unchecked
  # a participant or session label, we need to adjust the corresponding
  # subtask prerequisites. A special 'AnyGo' prereq allow is to make
  # this task no longer care about a previous task, yet we maintain
  # the relationship in the prerequisites table, so that if the user
  # turns it back on, we can care again.
  def adjust_prerequisites #:nodoc:
    prerequs = (self.prerequisites.presence || {})[:for_setup]
    return unless prerequs.present?
    my_participants = cleaned_up_participants.keys
    my_sessions     = cleaned_up_sessions.keys
    tids = prerequs.keys.map { |tid| tid.sub(/^T/,"") } # [ '123', '124' etc ]
    tids.each do |tid|
      subtask = CbrainTask.find_by_id(tid)
      if subtask.nil?
        self.addlog("Warning: one prerequisite subtask has disappeared: task ##{tid}")
        self.remove_prerequisites_for_setup(tid)
        next
      end
      subtask_mode = subtask.params[:_cb_mode]
      next unless subtask_mode == 'participant' ||  subtask_mode == 'session'
      if ( # yikes
           ((subtask_mode == 'participant') && (subtask.cleaned_up_participants.keys & my_participants).empty?) ||
           ((subtask_mode == 'session')     && (subtask.cleaned_up_sessions.keys     & my_sessions    ).empty?)
         )
        self.add_prerequisites_for_setup(tid, 'AnyGo') # this can either change it or leave it the same
      else
        self.add_prerequisites_for_setup(tid, 'Completed') # this can either change it or leave it the same
      end
    end
  end

  def self.pretty_params_names #:nodoc:
    { :_cb_participants               => 'List of participants',
      :_cb_sessions                   => 'List of sessions',
      :_cb_pipeline                   => 'Processing Pipeline',
      # This is ugly but in our params framework this method is class method
      # configuration instead of an object configuration.
      '_cb_pipeline[0][savename]'  => 'Output name of step 1',
      '_cb_pipeline[1][savename]'  => 'Output name of step 2',
      '_cb_pipeline[2][savename]'  => 'Output name of step 3',
      '_cb_pipeline[3][savename]'  => 'Output name of step 4',
      '_cb_pipeline[4][savename]'  => 'Output name of step 5',
      '_cb_pipeline[5][savename]'  => 'Output name of step 6',
      '_cb_pipeline[6][savename]'  => 'Output name of step 7',
    }
  end

  def untouchable_params_attributes #:nodoc:
    { :interface_userfile_ids        => true,
      :_cb_mode                      => true,
      :_cb_bids_id                   => true,
      :_cb_prep_output_id            => true,
      :_cb_pipeline                  => true,
    }
  end

  def unpresetable_params_attributes #:nodoc:
    { :interface_userfile_ids        => true,
      :_cb_mode                      => true,
      :_cb_bids_id                   => true,
      :_cb_prep_output_id            => true,
      :_cb_pipeline                  => true,
    }
  end

  def cleaned_up_participants #:nodoc:
    self.params[:_cb_participants].select              { |_,zero1| zero1 == '1' }
  end

  def cleaned_up_sessions #:nodoc:
    (self.params[:_cb_sessions].presence || {}).select { |_,zero1| zero1 == '1' }
  end

end

