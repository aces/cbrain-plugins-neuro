
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

# This module provides wrapping code for the descriptors
# of BIDS applications so that single BIDS subject are
# given in the main input. It will automatically create
# in the task's work directory a fake BIDS dataset with
# the single subject in it, complete with the needed
# json and tsv files.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesBidsSingleSubjectMaker": "my_input"
#       }
#   }
#
# In the example above, any userfile selected by the user
# (which should be a BIDS subject) for the Boutiques input
# "my_input" will be put into a fake BIDS dataset, as a
# symbolic link. The "command-line" of the descriptor
# will be modified so the program is invoked on the
# fake BIDS dataset too (by replacing the first occurence
# of the input's "value-key" with the name of the fake
# BIDS dataset).
#
# As a recommendation for people configuring this module
# in a descriptor, consider also using the other modules
# BoutiquesFileNameMatcher and BoutiquesFileTypeVerifier
# to force users to provide a proper BIDS subject in input.
module BoutiquesBidsSingleSubjectMaker

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This is the name of the directory where we create
  # our fake BIDS dataset with a single subject.
  FakeBidsDirName = 'CbrainBidsSingleSubject'



  ############################################
  # Portal Side Modifications
  # The form contains a new input file for
  # an optional participants.tsv
  ############################################

  # Adjust the description for the input so that it says we expect
  # a single subject now. Also adds the new input field
  # for the optional participants.tsv file.
  def descriptor_for_form
    descriptor = super.dup
    inputid    = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    input      = descriptor.input_by_id(inputid)

    # Adjust the description
    description  = input.description.presence || ""
    description += "\n" if description
    description += "(Note: this integration requires a BIDS single subject as input, a folder named like 'sub-xyz')"
    input.description = description

    # Add a new File input for the participants.tsv file
    descriptor = descriptor_with_participant_tsv_input_file(descriptor)

    descriptor
  end

  def descriptor_for_before_form #:nodoc:
    descriptor_for_form
  end

  def descriptor_for_after_form #:nodoc:
    descriptor_for_form
  end

  def descriptor_for_show_params #:nodoc:
    descriptor_for_form
  end

  def final_task_list #:nodoc:
    # We need to remove the special file IDs from the
    # interface_userfile_ids, now that's they've been assigned to
    # fields in the invoke structure. Otherwise, the final_task_list
    # method might want to create a task for them too.
    tsv_input_file_id = self.invoke_params[:cbrain_participants_tsv]
    dd_input_file_id  = self.invoke_params[:dataset_description_json]
    self.params[:interface_userfile_ids].reject! do |v|
       v.to_s == tsv_input_file_id.to_s || v.to_s == dd_input_file_id.to_s
    end
    super
  end

  ############################################
  # Bourreau (Cluster) Side Modifications
  ############################################

  # We need the extended descriptor so the standard setup() will
  # synchronize the participants.tsv file, is any.
  def descriptor_for_setup
    descriptor_with_participant_tsv_input_file(super)
  end

  # This method overrides the one in BoutiquesClusterTask.
  # It does the normal stuff, but then afterwards it creates
  # the fake BIDS dataset with a symlink to the subject directory.
  def setup
    return false unless super

    basename = Revision_info.basename
    commit   = Revision_info.short_commit

    # Extract the descriptor, module config, and input name
    descriptor   = self.descriptor_for_setup
    inputid      = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    userfile_id  = invoke_params[inputid]
    userfile     = Userfile.find(userfile_id)
    subject_name = userfile.name # 'sub-1234'

    if ! File.directory?(FakeBidsDirName)
      self.addlog("Creating fake BIDS dataset '#{FakeBidsDirName}'")
      self.addlog("#{basename} rev. #{commit}")
      Dir.mkdir(FakeBidsDirName)
    end

    symlink_loc = Pathname.new(FakeBidsDirName) + subject_name
    #symlink_val = Pathname.new("..")            + subject_name

    if ! File.exists?(symlink_loc.to_s)
      #File.symlink(symlink_val, symlink_loc)  # create "sub-123" -> "../sub-123" in FakeBidsDir
      #system("rsync","-a",(subject_name + "/"), symlink_loc.to_s) # need physical copy
      rsyncout = bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{subject_name.bash_escape}/ #{symlink_loc.to_s.bash_escape}")
      cb_error "Failed to rsync '#{subject_name}';\nrsync reported: #{rsyncout}" unless rsyncout.blank?
    end

    # Two other needed files in a BIDS dataset:
    desc_json_path        = Pathname.new(FakeBidsDirName) + "dataset_description.json"
    participants_tsv_path = Pathname.new(FakeBidsDirName) + "participants.tsv"

    # Create dataset_description.json
    if ! File.exists?(desc_json_path)
      File.open(desc_json_path,"w") { |fh| fh.write read_or_make_dataset_description(FakeBidsDirName) }
    end

    # Create participants.tsv
    tsv_header, tsv_record = read_or_make_tsv_for_subject(subject_name)
    if ! File.exists?(participants_tsv_path)
      self.addlog "Creating new participants.tsv file for subject #{subject_name}"
      File.open(participants_tsv_path,"w") { |fh| fh.write "#{tsv_header}\n#{tsv_record}\n" }
    else
      # Append to existing participants.tsv.
      # For the sake of supporting the case where several participants are processed within the
      # same FakeBidsDirName, we will just append the subject name IF IT'S NOT ALREADY THERE.
      tsv_content = File.read(participants_tsv_path).split("\n")
      # This code will break if several processes are all trying to do this at the exact same time.
      if ! tsv_content.any? { |line| line.sub(/[\s,].*/,"") == subject_name }
        self.addlog "Appending record for #{subject_name} to participants.tsv"
        File.open(participants_tsv_path,"a") { |fh| fh.write "#{tsv_record}\n" }
      end
    end

    true
  end

  # This method returns a TSV header and a single
  # tsv record for the +subject_name+ ; if the user
  # provided a TSV file in the special input file,
  # the header and record will be fetched from there.
  # Otherwise a dummy simply header and record (with
  # only the participant_id field) will be returned.
  def read_or_make_tsv_for_subject(subject_name)
    tsv_input_file_id = self.invoke_params[:cbrain_participants_tsv]

    # In the case there is no specific participants.tsv file provided
    # in input, we return the info to create a simple one.
    if tsv_input_file_id.blank?
      self.addlog "participants.tsv file will contain only the subject name"
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
      self.addlog "participants.tsv record for #{subject_name} extracted from supplied file"
    else
      self.addlog "Warning: no record for #{subject_name} found in participants.tsv file"
      tsv_record = subject_name
    end
    [ tsv_header, tsv_record ]
  end

  # Returns the content of the JSON file for the dataset description,
  # as a single string. The content either comes from a file explicitely
  # selected by the user, or a fake content is generated otherwise.
  def read_or_make_dataset_description(name)
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

  # Overrides the same method in BoutiquesClusterTask, as used
  # during cluster_commands()
  def finalize_bosh_invoke_struct(invoke_struct) #:nodoc:
    super
      .reject do |k,v|
         k.to_s == "cbrain_participants_tsv" or k.to_s == "dataset_description_json"
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
  #   "command-line": "true [BIDSDATASET]; bidsapptool CbrainBidsSingleSubject [OUTPUT] stuff"
  #
  # The reason a dummy true statement is prefixed at the beginning of the command
  # is so that bosh won't complain if it can't find the token [BIDSDATASET] anywhere
  # in the string.
  def descriptor_for_cluster_commands
    descriptor = super.dup
    inputid    = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    input      = descriptor.input_by_id(inputid)

    # The two strings we need
    command    = descriptor.command_line
    token      = input.value_key # e.g. '[BIDSDATASET]'

    # Make the substitution
    command = command.sub(token, FakeBidsDirName) # we replace only the first one

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

  # This method takes a descriptor and adds a new
  # File input, in a group at the bottom of all the other
  # input groups. This input recives, optionally, the
  # content of a participants.tsv file .
  def descriptor_with_participant_tsv_input_file(descriptor)
    descriptor = descriptor.dup

    # Add new input for dataset_description.json
    new_input_dd = BoutiquesSupport::Input.new(
      "name"          => "BIDS 'dataset_description.json' file",
      "id"            => "dataset_description_json",
      "description"   => "If set, provides a separate dataset_description.json file. If not set, a plain JSON file will be generated with dummy data.",
      "type"          => "File",
      "optional"      => true,
    )
    descriptor.inputs <<= new_input_dd

    # Add new input for participants.tsv
    new_input_part = BoutiquesSupport::Input.new(
      "name"          => "BIDS dataset 'participants.tsv' file",
      "id"            => "cbrain_participants_tsv",
      "description"   => "If set, provides a separate participants.tsv file. Must contain at least the subject being processed. If not set, a plain participants.tsv file will be generated with only the subject ID in it.",
      "type"          => "File",
      "optional"      => true,
    )
    descriptor.inputs <<= new_input_part

    # Add new group with that input
    groups       = descriptor.groups || []
    cb_mod_group = groups.detect { |group| group.id == 'cbrain_bids_extensions' }
    if cb_mod_group.blank?
      cb_mod_group = BoutiquesSupport::Group.new(
        "name"        => 'CBRAIN BIDS Extensions',
        "id"          => 'cbrain_bids_extensions',
        "description" => 'Special options for BIDS data files',
        "members"     => [],
      )
      groups.unshift cb_mod_group
    end
    cb_mod_group.members <<= new_input_dd.id
    cb_mod_group.members <<= new_input_part.id

    descriptor.groups = groups
    descriptor
  end

end

