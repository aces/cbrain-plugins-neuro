
# Model code common to the Bourreau and Portal side for BidsAppHandler.
class CbrainTask::BidsAppHandler

  Common_Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  HandledBoutiquesInputs  = %w( bids_dir analysis_level participant_label output_dir_name )
  HandledBoutiquesOutputs = %w( output_dir )

  # Two variants of the descriptor are stored in the built subclasses:

  # 1) The method 'generated_from' (provided by the Boutiques integrator) returns the
  # descriptor without BIDs inputs and without container info.

  # 2) This method returns the full descriptor
  class_attribute :full_descriptor

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info # will come from Portal or Bourreau side
    self.addlog("Base #{baserev.basename} rev. #{baserev.short_commit}", :caller_level => 2)
    commonrev = Common_Revision_info
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
    ids    = params[:interface_userfile_ids] || []
    bids_datasets = BidsDataset.where(:id => ids)
    cb_error "This task requires a single BidDataset as input" unless bids_datasets.count == 1
    @bids_dataset = bids_datasets.first
    params[:_cb_bids_id] = @bids_dataset.id
    params[:interface_userfile_ids] = params[:interface_userfile_ids].reject { |x| x.to_s == @bids_dataset.id.to_s }
    return @bids_dataset
  end

  # Returns the participants that were selected by their checkboxes in the launch form
  def selected_participants #:nodoc:
    select_hash  = params[:_cb_participants] || {}
    select_hash.keys.select { |sub| select_hash[sub] == '1' }
  end

  def untouchable_params_attributes #:nodoc:
    { :_cb_bids_id => true }
  end

  def unpresetable_params_attributes #:nodoc:
    { :_cb_bids_id => true }
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
    HandledBoutiquesInputs.each do |id|
      raise "Descriptor missing '#{id}' in inputs." unless
        inputs.any? { |struct| struct['id'] == id }
    end
    outputs = descriptor['output-files'] || []
    HandledBoutiquesOutputs.each do |id|
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
    #  HandledBoutiquesOutputs.include? struct['id']
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

