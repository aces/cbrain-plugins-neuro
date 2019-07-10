
# Model code common to the Bourreau and Portal side for BidsAppHandler.
class CbrainTask::BidsAppHandler

  Common_Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # For a descriptor to be a proper BidsApp, we MUST have these inputs:
  RequiredBoutiquesInputs = %w( bids_dir analysis_level participant_label output_dir_name )

  # For a descriptor to be a proper BidsApp, we MUST have these outputs:
  RequiredBoutiquesOutputs = %w( output_dir )

  # We bypass the code and handle ourselves these inputs:
  HandledBoutiquesInputs  = RequiredBoutiquesInputs + %w( session_label )

  # Two variants of the descriptor are stored in the built subclasses:

  # 1) The method chain 'generated_from.descriptor' (provided by the Boutiques integrator)
  # returns the descriptor without BIDs inputs and without container info.

  # 2) This method returns the full descriptor
  class_attribute :full_descriptor

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev   = Revision_info        # will come from Portal or Bourreau side
    commonrev = Common_Revision_info
    self.addlog(  "Base #{baserev.basename  } rev. #{baserev.short_commit  }", :caller_level => 2)
    self.addlog("Common #{commonrev.basename} rev. #{commonrev.short_commit}", :caller_level => 2)
  end

  # Returns the single bids_dataset that we originally
  # selected from the form (first ID in params[:interface_userfile_ids])
  # Raise an exception if it's not right.
  def bids_dataset #:nodoc:
    return @bids_dataset if @bids_dataset
    if params[:_cb_bids_id].present?
      @bids_dataset = BidsDataset.find(params[:_cb_bids_id])
      return @bids_dataset
    end
    ids = params[:interface_userfile_ids] || []
    bids_datasets = BidsDataset.where(:id => ids)
    cb_error "This task requires a single BidsDataset as input" unless bids_datasets.count == 1
    @bids_dataset = bids_datasets.first
    params[:_cb_bids_id] = @bids_dataset.id
    params[:interface_userfile_ids]
      .reject! { |x| x.to_s == @bids_dataset.id.to_s }
    return @bids_dataset
  end

  # Returns the optional BidsAppOutput object that we can use as a baseline
  # for processing some steps. It's assumed the BidsAppOutput of course contains
  # all the necessary files that are required, but that's left to the user to
  # make sure of that.
  def bids_app_prepared_output #:nodoc:
    return @bids_app_prepared_output if @bids_app_prepared_output
    if params[:_cb_prep_output_id].present?
      @bids_app_prepared_output = BidsAppOutput.find(params[:_cb_prep_output_id])
      return @bids_app_prepared_output
    end
    ids = params[:interface_userfile_ids] || []
    bids_outputs = BidsAppOutput.where(:id => ids)
    return nil if bids_outputs.empty? # it's optional after all
    cb_error "This task requires at most ONE pre-existing BidsAppOutput as an input" unless bids_outputs.count == 1
    @bids_app_prepared_output = bids_outputs.first
    params[:_cb_prep_output_id] = @bids_app_prepared_output.id
    params[:interface_userfile_ids]
      .reject! { |x| x.to_s == @bids_app_prepared_output.id.to_s }
    return @bids_app_prepared_output
  end

  # Returns the participants that were selected by their checkboxes in the launch form
  def selected_participants #:nodoc:
    return self.bids_dataset.list_subjects if self.implicit_all_participants?
    select_hash  = params[:_cb_participants] || {}
    select_hash.keys.select { |sub| select_hash[sub] == '1' }.sort
  end

  # Returns the sessions that were selected by their checkboxes in the launch form
  def selected_sessions #:nodoc:
    select_hash  = params[:_cb_sessions] || {}
    select_hash.keys.select { |sub| select_hash[sub] == '1' }.sort
  end

  # Returns true if the BidsApp has a --session_label option
  def has_session_label_input?(descriptor = self.class.full_descriptor)
    descriptor['inputs'].detect { |struct| struct['id'] == 'session_label' }
  end

  # Returns the array of possible analysis levels for this task.
  # Typically something like [ "participant", "group" ] .
  def analysis_levels(descriptor = self.class.full_descriptor)
    # We can't cache here, cause we can provide the info
    # from any arbitrary descriptor
    input_analysis_level = analysis_levels_input_descriptor(descriptor)
    input_analysis_level["value-choices"].dup
  end

  def analysis_levels_input_descriptor(descriptor = self.class.full_descriptor) #:nodoc:
    descriptor['inputs'].detect { |struct| struct['id'] == 'analysis_level' }
  end

  # A kludge that that invoked the instance method
  # task_partial on a BidsAppHandler object, to get
  # our form partials.
  def self.bids_app_handler_partial(name) #:nodoc:
    self.new.task_partial(name)
  end

  def implicit_all_participants? #:nodoc:
    self.params[:_cb_implicit_all_participants] == '1'
  end

  def implicit_all_participants=(truefalse) #:nodoc:
    self.params[:_cb_implicit_all_participants] = (truefalse.present? && truefalse != '0') ? '1' : '0'
  end

  ###########################################################################
  # Boot-time loader methods
  #
  # (This could probably be put elsewhere)
  ###########################################################################

  def self.boutiques_json_loader(json_file) #:nodoc:
    bids_app_full_json = SchemaTaskGenerator.expand_json(json_file)
    self.validate_bids_app_json(bids_app_full_json)

    # Step 1, remove container info
    without_container = self.json_without_container_config(bids_app_full_json)

    # Step 2, remove BidsApp inputs that we handle ourselves
    partial_bids_app_json = self.json_without_bids_app_params(without_container)

    # Step 3, add superclass
    partial_bids_app_json["custom"] ||= {}
    partial_bids_app_json["custom"]['cbrain:inherits-from-class'] = self.name  # The generator will use self as superclass

    # OK, so this is the standard Boutiques integration, minus some
    # input and output params and with a new superclass
    schema = SchemaTaskGenerator.default_schema
    generated = SchemaTaskGenerator.generate(schema, partial_bids_app_json, true, json_file)
    subclass  = generated.integrate # this will be a subclass of self

    # Make adjustments to view rendering code (wrappers)
    subclass.adjust_boutiques_raw_partial

    # Store JSON original descriptor in our new subclass (using class_attribute)
    subclass.full_descriptor = bids_app_full_json

    subclass
  end

  def self.validate_bids_app_json(descriptor) #:nodoc:
    inputs = descriptor['inputs'] || []
    RequiredBoutiquesInputs.each do |id|
      raise "Descriptor missing '#{id}' in inputs." unless
        inputs.any? { |struct| struct['id'] == id }
    end
    outputs = descriptor['output-files'] || []
    RequiredBoutiquesOutputs.each do |id|
      raise "Descriptor missing '#{id}' in outputs." unless
        outputs.any? { |struct| struct['id'] == id }
    end
    containerinfo = descriptor['container-image']
    raise 'Descriptor missing singularity container info.' if containerinfo.blank?
    cont_type = containerinfo['type']
    raise "Descriptor has container type of #{cont_type} instead of singularity" if cont_type != 'singularity'
  end

  def self.json_without_bids_app_params(descriptor) #:nodoc:
    cleaned = descriptor.dup

    # Remove the inputs that we handle ourselves
    cleaned['inputs'] = cleaned['inputs'].reject do |struct|
      HandledBoutiquesInputs.include? struct['id']
    end

    #cleaned['output-files'] = cleaned['output-files'].reject do |struct|
    #  RequiredBoutiquesOutputs.include? struct['id']
    #end
    #cleaned.delete('output-files') if cleaned['output-files'].empty?

    # If the Boutiques dev configured a mutex grouping, we remove it too.
    if cleaned['groups'].present?
      cleaned['groups'] = cleaned['groups'].reject do |struct|
        members = struct['members'] || []
        members.sort ==  [ "output_dir_name", "participant_level_analysis_dir" ]
      end
      cleaned.delete('groups') if cleaned['groups'].empty? # spec says if it exists, it must include one entry
    end

    # Return a simplified description for the generator
    cleaned
  end

  def self.json_without_container_config(descriptor) #:nodoc:
    adjusted = descriptor.dup
    adjusted.delete('container-image')
    adjusted
  end

  def self.adjust_boutiques_raw_partial #:nodoc:
    generated = self.generated_from
    handler_view_dir = File.expand_path('../../views', __FILE__)

    dispatch_hash = {
      :orig_task_params => generated.source[:task_params],
      :orig_show_params => generated.source[:show_params],
      :edit_help        => generated.source[:edit_help]
    }
    %w( task_params show_params ).each do |myview|
      wrapper_view = File.read("#{handler_view_dir}/_#{myview}.html.erb") # our wrappers
      dispatch_hash[myview.to_sym] = wrapper_view
    end

    # We crush the Boutiques integrator raw_partial() method with our new one.
    self.define_singleton_method(:raw_partial) do |partial|
      dispatch_hash[partial]
    end
  end

end

#############################################################
# Pre-load all BidsApp JSON
#############################################################

1.times do
  bids_app_json_dir = File.expand_path('../../bids_app_descriptors', __FILE__)
  Dir
    .entries(bids_app_json_dir)
    .select { |x| x =~ /\.json$/ }
    .sort
    .each do |json_file|
      #puts "\e[31mDEBUG: Trying to integrate BidsApps JSON '#{json_file}'...\e[0m"
      full_path = Pathname.new(bids_app_json_dir) + json_file
      begin
        subclass = CbrainTask::BidsAppHandler.boutiques_json_loader( full_path.to_s )
        puts "C> #{subclass.superclass}: Integrated #{subclass}"
      rescue => ex
        puts "C> Skipping integrating BidsApp descriptor '#{json_file}': #{ex.class} #{ex.message}"
      end
    end
end

