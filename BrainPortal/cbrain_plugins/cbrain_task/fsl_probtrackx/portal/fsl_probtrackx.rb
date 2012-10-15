
# A subclass of CbrainTask to launch FslProbtrackx.
class CbrainTask::FslProbtrackx < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ################################################################
  # For full documentation on how to write CbrainTasks,
  # read the file doc/CbrainTask.txt in the subversion trunk.
  #
  # The basic API consists in three methods that you need to
  # override:
  #   self.default_launch_args(), before_form() and after_form().
  #
  # The advanced API consists in four more methods, needed only
  # for more complex cases:
  #
  # self.properties(), final_task_list(),
  # after_final_task_list_saved(tasklist)
  # and untouchable_params_attributes().
  #
  # The advanced API is not included in this template since
  # you did not run the generator with the option --advanced.
  #
  # Please remove all the comment blocks before committing
  # your code. Provide proper RDOC comments just before
  # each method if you want to document them, but note
  # that normally all normal API methods are #:nodoc: anyway.
  ################################################################




  ################################################################
  # METHOD: self.default_launch_args()
  ################################################################
  # This method will be called before the form for your task is
  # rendered. It should return a hash table. This hash table will
  # be copied as-is into the task's params hash table.
  ################################################################

  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def self.default_launch_args #:nodoc:
    # Example: { :my_counter => 1, :output_file => "ABC.#{Time.now.to_i}" }
    { 
      :num_samples => 1000, 
      :rseed => 1,
      :curve_thresh => 0.2,
      :num_steps =>  2000,
      :step_length => 0.5
    }
  end
  


  ################################################################
  # METHOD: before_form()
  ################################################################
  # This method will be called before the form for your task is
  # rendered. For new tasks, the task object's params hash table
  # will contain the list of IDs selected in the userfile manager:
  #
  #   params[:interface_userfile_ids]
  #
  # You can filter and validate the IDs here.
  # You're free to add as much supplemental information as
  # you want in the params hash table too, but remember that
  # the form will ONLY send you back (in after_form()) what
  # is also covered by input tags in the view file.
  #
  # You must not save your new task object here.
  #
  # The method should return a string to inform the user of any
  # changes or notifications, and raise an exception for any
  # fatal errors.
  #
  # This method is also called when editing an existing task's
  # parameters; you can detect when this happens because the
  # task object will not be new (it will return false for
  # the method new_record()).
  ################################################################
  
  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
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
    { :collection_id => true }
  end


  ################################################################
  # METHOD: after_form()
  ################################################################
  # This method will be called after the form for your task has
  # been sunbmitted. The content of the task's attributes
  # (like :bourreau_id, :description, etc) will be filled in
  # by selection box already provided by the form. The params
  # hash table will contain the values of input tags contained
  # in the view (provided their variable names are properly
  # created with the to_la() methods). Note that any other
  # pieces of information stored in params() during before_form()
  # will be lost unless such input tags are present to preserve
  # them.
  #
  # You must not save your new task object here.
  #
  # The method should return a string to inform the user of any
  # changes or notifications, and raise an exception for any
  # fatal errors.
  #
  # This method is also called when editing an existing task's
  # parameters; you can detect when this happens because the
  # task object will not be new (it will return false for
  # the method new_record()).
  #
  # It's possible to design simple tasks where this method
  # is not necessary at all:
  #   - when there is no validation needed
  #   - the Bourreau side uses params[:interface_userfile_ids]
  #   - other options and values are stored in params by
  #     the view's input tags.
  ################################################################
  
  # RDOC comments here, if you want, although the method
  # is created with #:nodoc: in this template.
  def after_form #:nodoc:
    params = self.params
    #cb_error "Some error occurred."
    ""
  end

end

