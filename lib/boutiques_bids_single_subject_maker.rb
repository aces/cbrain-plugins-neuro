
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This is the name of the directory where we create
  # our fake BIDS dataset with a single subject.
  FakeBidsDirName = 'CbrainBidsSingleSubject'

  # This method overrides the one in BoutiquesClusterTask.
  # It does the normal stuff, but then afterwards it creates
  # the fake BIDS dataset with a symlink to the subject directory.
  def setup
    return false unless super

    # Note: we can't use the 'revision_info()' method
    # for getting the module's info.
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
    symlink_val = Pathname.new("..")            + subject_name

    if ! File.exists?(symlink_loc)
      File.symlink(symlink_val, symlink_loc)  # create "sub-123" -> "../sub-123" in FakeBidsDir
    end

    # Two other needed files in a BIDS dataset:
    desc_json_path        = Pathname.new(FakeBidsDirName) + "dataset_description.json"
    participants_tsv_path = Pathname.new(FakeBidsDirName) + "participants.tsv"

    # Create dataset_description.json
    if ! File.exists?(desc_json_path)
      File.open(desc_json_path,"w") { |fh| fh.write dataset_description_json(FakeBidsDirName) }
    end

    # Create participants.tsv
    if ! File.exists?(participants_tsv_path)
      File.open(participants_tsv_path,"w") { |fh| fh.write "participant_id\n#{subject_name}\n" }
    else
      # Append to existing participants.tsv.
      # For the sake of supporting the case where several participants are processed within the
      # same FakeBidsDirName, we will just append the subject name IF IT'S NOT ALREADY THERE.
      tsv_content = File.read(participants_tsv_path).split("\n")
      # This code will break if several processes are all trying to do this at the exact same time.
      if ! tsv_content.any? { |line| line == subject_name }
        File.open(participants_tsv_path,"a") { |fh| fh.write "#{subject_name}\n" }
      end
    end

    true
  end

  def dataset_description_json(name) #:nodoc:

    # Note: we can't use the 'revision_info()' method
    # for getting the module's info.
    basename = Revision_info.basename
    commit   = Revision_info.short_commit

    json = <<-DATASET_DESCRIPTION
{
    "Acknowledgements": "Fake single subject dataset created by #{basename} rev. #{commit}",
    "Authors": [
        "TODO"
    ],
    "BIDSVersion": "1.4.1",
    "DatasetDOI": "TODO",
    "Funding": [
        "TODO"
    ],
    "HowToAcknowledge": "TODO",
    "License": "TODO",
    "Name": "#{name}",
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
  #   "command-line": "bidsapptool CbrainBidsSingleSubject [OUTPUT] stuff"
  def descriptor_for_cluster_commands
    descriptor = super.dup
    inputid    = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    input      = descriptor.input_by_id(inputid)

    # The two strings we need
    command    = descriptor.command_line
    token      = input.value_key # e.g. '[BIDSDATASET]'

    # Make the substitution
    command = command.sub(token, FakeBidsDirName) # we replace only the first one
    descriptor.command_line = command

    descriptor
  end

  # Adjust the description for the input so that it says we expect
  # a single subject now.
  def descriptor_for_form
    descriptor = super.dup
    inputid    = descriptor.custom_module_info('BoutiquesBidsSingleSubjectMaker')
    input      = descriptor.input_by_id(inputid)

    # Adjust the description
    description  = input.description.presence || ""
    description += "\n" if description
    description += "(Note: this integration requires a BIDS single subject as input, a folder named like 'sub-xyz')"
    input.description = description

    descriptor
  end

end

