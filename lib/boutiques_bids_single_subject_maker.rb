
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# This module provides wrapping code for the descriptor
# of a BIDS application so that a single BIDS subject is
# acceptable as the main input. When a tool is given a
# BIDS subject (a folder of a BIDS dataset), the module will
# automatically create in the task's work directory a fake
# BIDS dataset with the single subject in it, complete with
# the needed json and tsv files.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#     "cbrain:integrator_modules": {
#       "BoutiquesBidsSingleSubjectMaker": {
#         "dataset_input_id":  "my_input1",
#         "subjects_input_id": "my_input2",
#         "keep_sub_prefix": false
#       }
#     }
#   }
#
# The "dataset_input_id" property is mandatory,
# while "subjects_input_id" and "keep_sub_prefix"
# are optional.
#
# In the example above, any BidsSubject file "sub-1234"
# selected by the user for the Boutiques File input "my_input1" will
# be put into a fake BIDS dataset, as a symbolic link.
#
# If the boutiques ID of String input is provided with
# subjects_input_id, the value of that input will be populated
# automatically with "1234" or "sub-1234" based on the
# name of the BidsSubject. The presence or removal
# of the "sub-" prefix is controlled by the "keep_sub_prefix"
# option, which default to false, and thus "1234" is
# the default participant name format.
#
# At execution time, the "command-line" of the descriptor
# will be modified so the program is invoked on the
# fake BIDS dataset (by replacing the first occurence
# of the input's "value-key" with the name of the fake
# BIDS dataset).
#
# Backwards compatibility note: old versions of this
# module used only a string to identify the dataset_input_id
# in this way:
#
#   "custom": {
#     "cbrain:integrator_modules": {
#       "BoutiquesBidsSingleSubjectMaker": "my_input1"
#     }
#   }
#
# This is deprecated, but functionally it means the same
# as the object { "dataset_input_id": "my_input1" }. There
# is one slight difference in how the command-line is
# modified, in that the "command-line-flag" is NOT inserted
# within the command, in that particular configuration
# (this is because that's how the old module worked).
module BoutiquesBidsSingleSubjectMaker

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This is the name of the directory where we create
  # our fake BIDS dataset with a single subject.
  FakeBidsDirName = 'CbrainBidsSingleSubject'

  # Default max BIDS dataset size; can be overriden
  # by setting up an ENV variable in the ToolConfig
  # object with the same name. Value is in Gb
  CBRAIN_MAX_BIDS_DATASET_GB=20



  ############################################
  # Portal Side Modifications
  # The form contains a new input file for
  # an optional participants.tsv
  ############################################

  # Adjust the description for the input so that it says we expect
  # a single subject now. Also adds new input fields
  # for the three optional dataset-level files.
  def descriptor_with_adjusted_form(descriptor)
    descriptor = descriptor.dup
    return descriptor if ! is_ssm_module_configured?(descriptor)
    ds_input  = dataset_btq_input(descriptor)
    sub_input = subjects_btq_input(descriptor)

    # Adjust the Dataset input description
    ds_description  = ds_input.description.presence || ""
    ds_description += "\n"
    ds_description += "Note: this integration works with either a full BidsDataset (a folder that can be named anything), or a single BidsSubject (a folder named like 'sub-xyz').\n"
    if sub_input
      sample_subid = strip_sub_prefix?(descriptor) ? 'xyz' : 'sub-xyz'
      ds_description += "If you provide a BidsSubject, the other field '#{sub_input.name}' where you normally put a subject name will be filled for you automatically with a value in the format '#{sample_subid}'."
    end
    ds_input.description = ds_description.strip

    # Adjust participant ID description, if any
    if sub_input
      sub_description  = sub_input.description.presence || ""
      sub_description += "\n"
      sub_description += "Note: if you are providing a BidsSubject as the main input in the other field '#{ds_input.name}', then you can leave this field blank. It will be populated automatically."
      sub_input.description = sub_description.strip
    end

    # Add several new File inputs for a bunch of files related to the BIDS dataset
    descriptor = descriptor_with_extra_files_for_dataset(descriptor)

    descriptor
  end

  def descriptor_for_form #:nodoc:
    descriptor_with_adjusted_form(super)
  end

  def descriptor_for_before_form #:nodoc:
    descriptor_with_adjusted_form(super)
  end

  def descriptor_for_after_form #:nodoc:
    descriptor_with_adjusted_form(super)
  end

  def descriptor_for_show_params #:nodoc:
    descriptor_with_adjusted_form(super)
  end

  # Override the main method from the CBRAIN framework.
  # Here we just decides if the module is even configured,
  # and if so, whether a BidsDataset or BidsSubject was
  # selected by the user. And we make a few validations
  # accordingly.
  def after_form
    descriptor = descriptor_for_after_form
    return super if ! is_ssm_module_configured?(descriptor) # do nothing else if this module is not even active

    ds_input   = dataset_btq_input(descriptor)
    ds_file_id = self.invoke_params[ds_input.id]
    return super if ds_file_id.blank? # nothing to do if left blank
    userfile   = Userfile.find(ds_file_id)

    return super if userfile.is_a?(CbrainFileList) # when launching task arrays, skip the initial check

    if ! (userfile.is_a?(BidsSubject) || userfile.is_a?(BidsDataset))
      add_invoke_params_error(ds_input.id, "must be either a BidsDataset or a BidsSubject", descriptor)
    end

    # Validate params when given a BidsDataset
    # Basically, three File inputs must have been left blank
    if userfile.is_a?(BidsDataset)
      %w( cbrain_participants_tsv dataset_description_json cbrain_bids_ignore ).each do |fid|
        if self.invoke_params[fid].present?
          add_invoke_params_error(fid, "must be left blank when using a BidsDataset as the main input file", descriptor)
        end
      end
    end

    # Check the size of a BidsDataset
    if userfile.is_a?(BidsDataset)
      max_gb = ssm_max_bids_dataset_gb()
      if userfile.size > max_gb.gigabytes
        add_invoke_params_error(ds_input.id, "was given a BidsDataset but this configuration does not allow it to exceed a size of #{max_gb} GBs; contact the administators if you need a higher limit.", descriptor)
      end
    end

    if userfile.is_a?(BidsSubject)
      adjust_bids_subject_name(descriptor)
    end

    return super
  end

  # If we have been given the ID of an input where
  # subject name(s) can be provided, we extract the
  # name string from the BidsSubject's name (with or without "sub-")
  # and place it as a value in the invoke params (as a single
  # string or as an array with a single string, depending on
  # the "list" attribute of the input object)
  def adjust_bids_subject_name(descriptor) #:nodoc:
    return false if ! is_ssm_module_configured?(descriptor) # do nothing else if this module is not even active

    ds_input   = dataset_btq_input(descriptor)
    ds_file_id = self.invoke_params[ds_input.id]
    userfile   = Userfile.find(ds_file_id)
    return false unless userfile.is_a?(BidsSubject)

    subinput = subjects_btq_input(descriptor)
    return false if ! subinput

    sub_name = userfile.name # "sub-1234"
    sub_name.sub!(/\Asub-/,"") if strip_sub_prefix?(descriptor)
    sub_value = subinput.list ? [ sub_name ] : sub_name
    self.invoke_params[subinput.id] = sub_value
    true
  end

  # Overrides the task array generator method.
  # We just remove some invoke params, and reinsert them
  # back after the task array is generated.
  def final_task_list #:nodoc:
    # We need to remove the special file IDs from the
    # interface_userfile_ids, now that's they've been assigned to
    # fields in the invoke structure. Otherwise, the final_task_list
    # method might want to create a task for them too.
    tsv_input_file_id = self.invoke_params[:cbrain_participants_tsv]
    dd_input_file_id  = self.invoke_params[:dataset_description_json]
    ign_input_file_id = self.invoke_params[:cbrain_bids_ignore]
    original_interface_userfile_ids = self.params[:interface_userfile_ids].dup
    self.params[:interface_userfile_ids].reject! do |v|
       v.to_s == tsv_input_file_id.to_s ||
       v.to_s == dd_input_file_id.to_s  ||
       v.to_s == ign_input_file_id.to_s
    end

    # Standard task array generator code
    task_array = super

    # Now re-insert the IDs of the special files; this will help in case
    # the user does a "edit params"
    descriptor = descriptor_for_after_form
    task_array.each do |task|
      task.params[:interface_userfile_ids]          = original_interface_userfile_ids.dup
      task.invoke_params[:cbrain_participants_tsv]  = tsv_input_file_id if tsv_input_file_id
      task.invoke_params[:dataset_description_json] = dd_input_file_id  if dd_input_file_id
      task.invoke_params[:cbrain_bids_ignore]       = ign_input_file_id if ign_input_file_id
      task.adjust_bids_subject_name(descriptor)
    end

    return task_array
  end



  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # We need the extended descriptor so the standard setup() will
  # synchronize the special three Dataset-level files, if any.
  def descriptor_for_setup #:nodoc:
    descriptor_with_extra_files_for_dataset(super)
  end

  # This method overrides the one in BoutiquesClusterTask.
  # It does the normal stuff, but then afterwards if
  # the current mode of operation is to use a BidsSubject, it
  # creates a fake BIDS dataset, and installs a copy of the
  # subject directory the main input.
  def setup
    return false unless super # do normal code first; if normal code fails, do nothing else
    descriptor = self.descriptor_for_setup
    return true if ! is_ssm_module_configured?(descriptor) # do nothing else if this module is not even active

    ds_input   = dataset_btq_input(descriptor)
    ds_file_id = self.invoke_params[ds_input.id]
    userfile   = Userfile.find(ds_file_id)

    basename = Revision_info.basename
    commit   = Revision_info.short_commit
    self.addlog("#{basename} rev. #{commit}")

    if userfile.is_a?(BidsDataset)
      self.addlog "BoutiquesBidsSingleSubject: preparing task for a BidsDataset"
      setup_for_bids_dataset()
    elsif userfile.is_a?(BidsSubject)
      self.addlog "BoutiquesBidsSingleSubject: preparing task for a BidsSubject"
      setup_for_bids_subject()
    else
      cb_error "This task was given a CBRAIN file of unknown type: #{userfile.class} ##{userfile.id}"
    end

    true
  end

  def setup_for_bids_dataset #:nodoc:
    true # no special code needed for the moment
  end

  def setup_for_bids_subject #:nodoc:

    # Extract the descriptor, module config, and input name
    descriptor   = self.descriptor_for_setup

    ds_input     = dataset_btq_input(descriptor)
    userfile_id  = invoke_params[ds_input.id]
    userfile     = Userfile.find(userfile_id)
    subject_name = userfile.name # 'sub-1234'

    if ! File.directory?(FakeBidsDirName)
      self.addlog("BoutiquesBidsSingleSubject: Creating fake BIDS dataset '#{FakeBidsDirName}'")
      Dir.mkdir(FakeBidsDirName)
    end

    # Make a copy of the subject data
    copy_loc = Pathname.new(FakeBidsDirName) + subject_name
    verb     = File.exists?(copy_loc.to_s) ? "Updating" : "Copying" # helps identifying what happens when restarting
    self.addlog("BoutiquesBidsSingleSubject: #{verb} subject data '#{subject_name}'")
    rsyncout = ssm_bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{subject_name.bash_escape}/ #{copy_loc.to_s.bash_escape}")
    cb_error "Failed to rsync '#{subject_name}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?

    # Three other needed files in a BIDS dataset:
    desc_json_path        = Pathname.new(FakeBidsDirName) + "dataset_description.json"
    participants_tsv_path = Pathname.new(FakeBidsDirName) + "participants.tsv"
    ign_path              = Pathname.new(FakeBidsDirName) + ".bidsignore" # optional

    # Create dataset_description.json
    if ! File.exists?(desc_json_path)
      self.addlog("BoutiquesBidsSingleSubject: installing dataset_description.json")
      File.open(desc_json_path,"w") { |fh| fh.write read_or_make_dataset_description(FakeBidsDirName) }
    end

    # Create participants.tsv
    tsv_header, tsv_record = read_or_make_tsv_for_subject(subject_name)
    if ! File.exists?(participants_tsv_path)
      self.addlog "BoutiquesBidsSingleSubject: Creating new participants.tsv file for subject #{subject_name}"
      File.open(participants_tsv_path,"w") { |fh| fh.write "#{tsv_header}\n#{tsv_record}\n" }
    else
      # Append to existing participants.tsv.
      # For the sake of supporting the case where several participants are processed within the
      # same FakeBidsDirName, we will just append the subject name IF IT'S NOT ALREADY THERE.
      tsv_content = File.read(participants_tsv_path).split("\n")
      # This code will break if several processes are all trying to do this at the exact same time.
      if ! tsv_content.any? { |line| line.sub(/[\s,].*/,"") == subject_name }
        self.addlog "BoutiquesBidsSingleSubject: Appending record for #{subject_name} to participants.tsv"
        File.open(participants_tsv_path,"a") { |fh| fh.write "#{tsv_record}\n" }
      end
    end

    # Create optional .bidsignore file if any
    bidsignore_content = read_bidsignore_file()
    if ! File.exists?(ign_path) && bidsignore_content.present?
      self.addlog("BoutiquesBidsSingleSubject: installing .bidsignore file")
      File.open(ign_path,"w") { |fh| fh.write bidsignore_content }
    end

    true
  end

  # This method returns a TSV header and a single
  # tsv record for the +subject_name+ ; if the user
  # provided a TSV file in the special input file,
  # the header and record will be fetched from there.
  # Otherwise a dummy simply header and record (with
  # only the participant_id field) will be returned.
  def read_or_make_tsv_for_subject(subject_name) #:nodoc:
    tsv_input_file_id = self.invoke_params[:cbrain_participants_tsv]

    # In the case there is no specific participants.tsv file provided
    # in input, we return the info to create a simple one.
    if tsv_input_file_id.blank?
      self.addlog "BoutiquesBidsSingleSubject: participants.tsv file will contain only the subject name"
      return [ "participant_id", subject_name ] # TSV contains only participant ID
    end

    # Ok, so there is a participants.tsv file, let's read its
    # header and find the line for our subject.
    # setup() has already synced it to the cache.
    cached_tsv_path = Userfile.find(tsv_input_file_id).cache_full_path
    tsv_content  = File.read(cached_tsv_path.to_s).split("\n")
    tsv_header   = tsv_content[0].presence || "participant_id"
    tsv_record   = tsv_content.detect { |line| line.sub(/[\s,].*/,"") == subject_name }
    if tsv_record.present?
      self.addlog "BoutiquesBidsSingleSubject: participants.tsv record for #{subject_name} extracted from supplied file"
    else
      self.addlog "BoutiquesBidsSingleSubject: Warning: no record for #{subject_name} found in participants.tsv file"
      tsv_record = subject_name
    end
    [ tsv_header, tsv_record ]
  end

  # Returns the content of the JSON file for the dataset description,
  # as a single string. The content either comes from a file explicitely
  # selected by the user, or a fake content is generated otherwise.
  def read_or_make_dataset_description(name) #:nodoc:
    dd_input_file_id = self.invoke_params[:dataset_description_json]

    # Create a fake JSON file
    if dd_input_file_id.blank?
      return fixed_dataset_description_json(name)
    end

    # Read the content of the file selected by the user
    cached_dd_path = Userfile.find(dd_input_file_id).cache_full_path
    dd_content     = File.read(cached_dd_path)
    dd_content
  end

  # Returns the content of the .bidsignore file selected by the user, if any.
  # This assumes the file has already been synchronized.
  def read_bidsignore_file #:nodoc:
    ign_input_file_id = self.invoke_params[:cbrain_bids_ignore]
    return nil unless ign_input_file_id

    # Read the content of the ignore file selected by the user
    cached_ign_path = Userfile.find(ign_input_file_id).cache_full_path
    ign_content     = File.read(cached_ign_path)
    ign_content
  end

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands(); we remove the keys for the
  # special files that are installed within the Dataset structure
  # but are not real parameters of the tool.
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    super
      .reject do |k,v|
         k.to_s == "cbrain_participants_tsv"  or
         k.to_s == "dataset_description_json" or
         k.to_s == "cbrain_bids_ignore"
      end # returns a dup()
  end

  # Returns a fixed JSON for the BIDS dataset description.
  def fixed_dataset_description_json(name) #:nodoc:

    basename = Revision_info.basename
    commit   = Revision_info.short_commit

    json = <<-DATASET_DESCRIPTION
{
    "Name": "#{name}",
    "BIDSVersion": "1.4.1",
    "Acknowledgements": "Fake single subject dataset created by #{basename} rev. #{commit}",
    "GeneratedBy": [
      {
        "Name": "BoutiquesBidsSingleSubjectMaker",
        "Version": "#{commit}"
      }
    ],
    "Authors": [
        "TODO"
    ],
    "DatasetDOI": "TODO",
    "Funding": [
        "TODO"
    ],
    "HowToAcknowledge": "TODO",
    "License": "TODO",
    "ReferencesAndLinks": [
        "TODO"
    ]
}
    DATASET_DESCRIPTION

    json
  end

  def descriptor_for_cluster_commands #:nodoc:
    descriptor = super
    return descriptor if ! is_ssm_module_configured?(descriptor)

    ds_input     = dataset_btq_input(descriptor)
    userfile_id  = invoke_params[ds_input.id]
    userfile     = Userfile.find(userfile_id)

    if userfile.is_a?(BidsSubject)
      return descriptor_for_cluster_commands_with_BidsSubject(descriptor)
    else # presumably BidsDataset
      return descriptor_for_cluster_commands_with_BidsDataset(descriptor)
    end
  end

  def descriptor_for_cluster_commands_with_BidsDataset(descriptor) #:nodoc:
    return descriptor # no modifications needed for the moment
  end

  # This method overrides the one in BoutiquesClusterTask
  # It adjusts the command-line of the descriptor so that
  # the token for the BIDS dataset is replaced by the constant
  # name for the fake BIDS directory we create in setup(). E.g.
  # From:
  #
  #   "command-line": "bidsapptool [BIDSDATASET] [OUTPUT] stuff"
  #
  # To:
  #
  #   "command-line": "true [BIDSDATASET]; bidsapptool [maybe_option_flag_here] CbrainBidsSingleSubject [OUTPUT] stuff"
  #
  # The reason a dummy true statement is prefixed at the beginning of the command
  # is so that bosh won't complain if it can't find the token [BIDSDATASET] anywhere
  # in the string.
  def descriptor_for_cluster_commands_with_BidsSubject(descriptor) #:nodoc:
    descriptor = descriptor.dup

    ds_input     = dataset_btq_input(descriptor)
    userfile_id  = invoke_params[ds_input.id]
    userfile     = Userfile.find(userfile_id) # a BidsSubject

    # The two strings we need
    command    = descriptor.command_line
    token      = ds_input.value_key # e.g. '[BIDSDATASET]'

    # Make the substitution; in a standard situation we build a string
    # like "-bids CbrainFakeBidsDataset" where "-bids" is whatever flag
    # is defined in the input for the BIDS dataset, if any. In backwards compatibility
    # mode it will be just "CbrainFakeBidsDataset" no matter what.
    dataset_command_substring  = "#{ds_input.command_line_flag} " # e.g. "-bids " for some tools
    dataset_command_substring  = "" if is_ssm_module_in_backwards_compatible_mode?(descriptor) # zap it back
    dataset_command_substring += FakeBidsDirName
    command = command.sub(token, dataset_command_substring.strip) # we replace only the first one

    # In order to prevent bosh from complaining if the value-key is no longer found
    # anywhere in the command-line, we re-instert a dummy no-op bash statement at the
    # beginning of the command with at least one use of that value-key. It will look
    # like e.g.
    #
    #   "true [BIDSDATASET] ; real command here"
    #
    # In bash, the 'true' statement doesn't do anything and ignores all arguments.
    if ! command.include? token
      command = "true #{token} ; #{command}"
    end

    descriptor.command_line = command
    descriptor
  end



  ########################################################
  # Modifications common to both Portal and Bourreau sides
  ########################################################

  # This method takes a descriptor and adds three new
  # File inputs, in a group at the bottom of all the other
  # input groups. The inputs allow the user to provide:
  #
  # 1. the dataset_description.json file
  # 2. the participants.tsv file
  # 3. the .bidsignore file
  #
  # All of these files can be named something other
  # than the name they will be installed as (in fact,
  # this is necessary for the .bidsignore file, since in
  # CBRAIN no files can start with a period).
  def descriptor_with_extra_files_for_dataset(descriptor)
    descriptor = descriptor.dup
    inputid    = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    return descriptor if inputid.blank? # nothing to do

    # Add new input for dataset_description.json
    new_input_dd = BoutiquesSupport::Input.new(
      "name"          => "BIDS 'dataset_description.json' file",
      "id"            => "dataset_description_json",
      "description"   => "If set, provides a separate 'dataset_description.json' file. If not set, a plain JSON file will be generated with dummy data. Your file doesn't have to be named exactly 'dataset_description.json' by the way, CBRAIN will install it with the proper name.",
      "type"          => "File",
      "optional"      => true,
    )
    descriptor.inputs <<= new_input_dd

    # Add new input for participants.tsv
    new_input_part = BoutiquesSupport::Input.new(
      "name"          => "BIDS dataset 'participants.tsv' file",
      "id"            => "cbrain_participants_tsv",
      "description"   => "If set, provides a separate 'participants.tsv' file. Must contain at least the subject being processed. If not set, a plain participants.tsv file will be generated with only the subject ID in it. Your file itself doesn't have to be named exactly 'participants.tsv' by the way, CBRAIN will install it with the proper name.",
      "type"          => "File",
      "optional"      => true,
    )
    descriptor.inputs <<= new_input_part

    # Add new input for .bidsignore
    new_input_ign = BoutiquesSupport::Input.new(
      "name"          => "BIDS dataset '.bidsignore' file",
      "id"            => "cbrain_bids_ignore",
      "description"   => "If set, provides a separate .bidsignore file that will be installed within the BIDS dataset. Within CBRAIN, files cannot be named with a leading period, but the text file you provide can actually be named anything you want: CBRAIN will install it with the proper name.",
      "type"          => "File",
      "optional"      => true,
    )
    descriptor.inputs <<= new_input_ign

    # Add new group with that input
    groups       = descriptor.groups.dup || []
    cb_mod_group = groups.detect { |group| group.id == 'cbrain_bids_extensions' }
    if cb_mod_group.blank?
      cb_mod_group = BoutiquesSupport::Group.new(
        "name"        => 'CBRAIN BIDS Extensions',
        "id"          => 'cbrain_bids_extensions',
        "description" => 'Special options for BIDS data files.\nMost of these options only apply when running the tool with a BIDS Subject as the main input file.',
        "members"     => [],
      )
      groups.unshift cb_mod_group
    end
    cb_mod_group.members <<= new_input_dd.id
    cb_mod_group.members <<= new_input_part.id
    cb_mod_group.members <<= new_input_ign.id

    descriptor.groups = groups
    descriptor
  end



  ########################################################
  # Configuration information methods
  ########################################################
  #
  # See the comment black at the top of the module for
  # explanations. These methods are helpers.

  # This returns false if the module's not even
  # configured in the 'custom' section of the descriptor.
  # That would mean all methods in this file should
  # basically not do anything and just call super instead.
  def is_ssm_module_configured?(descriptor = self.boutiques_descriptor)
    info = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    return false if info.blank?
    return true  if info.is_a?(String) # old compatibility mode
    return true  if info["dataset_input_id"].present?
    false
  end

  # This method returns an object with the module's configuration.
  # To handle backwards compatibilty with previous versions of this
  # module, it handles gracefully the case where the config is
  # a single input ID as a string (how it was done before).
  # The returned value here is always nil if the module is
  # not configured, or a small struct.
  def custom_config(descriptor = self.boutiques_descriptor) #:nodoc:
    conf = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    return conf.with_indifferent_access if conf.is_a?(Hash)
    compatibility_conf = {
        :dataset_input_id => conf,
        :old_style        => true,  # backwards compatibility flag
    }.with_indifferent_access
    return compatibility_conf
  end

  # Returns out of the descriptor the Input object
  # for the main BIDS dataset input (the one that a user can
  # provide a BidsSubject instead).
  def dataset_btq_input(descriptor = self.boutiques_descriptor) #:nodoc:
    ds_input_id = custom_config[:dataset_input_id]
    descriptor.input_by_id(ds_input_id)
  end

  # Returns out of the descriptor the Input object
  # for the subject ID(s), if any.
  def subjects_btq_input(descriptor = self.boutiques_descriptor) #:nodoc:
    sub_input_id = custom_config[:subjects_input_id]
    return nil if sub_input_id.blank?
    descriptor.input_by_id(sub_input_id)
  end

  # Returns true if the module's configuration says
  # that the "sub-" prefix needs to be stripped before
  # being fed to the subject ID input string. This
  # is performed when a BidsSubject is provided as main
  # input.
  def strip_sub_prefix?(descriptor = self.boutiques_descriptor) #:nodoc:
    !(custom_config(descriptor)[:keep_sub_prefix].present?) # it's better to make the default to "strip it"
  end

  # Returns true if we are in the old compatibility mode
  # where the module was just configured with the ID
  # of the main input.
  def is_ssm_module_in_backwards_compatible_mode?(descriptor = self.boutiques_descriptor) #:nodoc:
    custom_config(descriptor)[:old_style].present?
  end



  ########################################################
  # Misc utility methods
  ########################################################

  def ssm_bash_this(command) #:nodoc:
    fh = IO.popen(command,"r")
    output = fh.read
    fh.close
    output
  end

  # Returns the configured allowed max size of a BIDS dataset, in GB
  def ssm_max_bids_dataset_gb #:nodoc:
    max_from_env = (self.tool_config.env_array || []).detect do |name,value|
      name == 'CBRAIN_MAX_BIDS_DATASET_GB'
    end
    max_gb = (max_from_env&.last || CBRAIN_MAX_BIDS_DATASET_GB)  # the default is the constant at the top of this file
    max_gb.to_i
  end

end

