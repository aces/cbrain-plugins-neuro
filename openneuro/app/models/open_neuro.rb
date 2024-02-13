
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# This model is not a database-backed model, at least
# not directly. It is a pair of a WorkGroup and
# a DataladDataProvider.
class OpenNeuro

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessor :name
  attr_accessor :version
  attr_accessor :work_group
  attr_accessor :data_provider

  attr_accessor :configured

  WORK_GROUP_OWNER    = User.admin
  DATA_PROVIDER_OWNER = User.admin
  USERFILES_OWNER     = User.admin

  DATALAD_REPO_URL_PREFIX = 'https://github.com/OpenNeuroDatasets'

  # Creates an OpenNeuro object that represents
  # the dataset internally as a pair, a WorkGroup
  # and a DataladDataProvider. The naming of these
  # two objects is critical; if the objects are found
  # in the database, the OpenNeuro objects is considered
  # "configured". Otherwise it is "unconfigured" and the
  # two internal objects are not yet saved.
  def self.find(name, version)

    # Note: name and version already validated by regexes in routes

    # For a OpenNeuro dataset to be considered 'configured already',
    # we need both the WorkGroup and the associated DataProvider to exist.
    groupquery = work_group_builder(name, version)
    group      = groupquery.first
    dpquery    = data_provider_builder(name, version, group&.id) # group.id can be nil
    dp         = dpquery.first

    self.new.tap do |open_neuro|
      open_neuro.name          = name
      open_neuro.version       = version
      open_neuro.work_group    = group || groupquery.new
      open_neuro.data_provider = dp    || dpquery.new
      open_neuro.configured    = (group.present? && dp.present?)
    end
  end

  # Returns true of the WorkGroup and
  # DataProvider for the dataset exist.
  def configured?
    self.configured
  end

  # Returns a progress string when userfile registertion
  # is progressing in background.
  def registration_progress
    self.data_provider.meta[:openneuro_registration_progress]
  end

  # Set the progress string when registration is
  # happening in the background.
  def registration_progress=(infostring)
    self.data_provider.meta[:openneuro_registration_progress] = infostring
  end

  # Returns the timestamp of the last time the
  # registration progress string was updated.
  def registration_progress_update_time
    self.data_provider.id.presence &&
    self.data_provider.meta.md_for_key(:openneuro_registration_progress)&.updated_at
  end

  # Returns true if all files have been registered
  def all_registered?
    self.configured? && self.registration_progress == 'Completed'
  end

  # Saves the WorkGroup and DataladDataProvider
  # associated with the OpenNeuro dataset, if
  # not already done. Does nothing if the
  # two already exist.
  def autoconfigure!
    return true if self.configured?
    self.work_group.save!
    self.data_provider.group_id = self.work_group.id
    self.data_provider.save!
    self.configured = true
  end

  # Register all the files found at the top level
  # of the OpenNeuro dataset. This is a synchronous
  # method and will return only at the end.
  def autoregister!
    return false unless self.configured?
    return true  if self.registration_progress.present? # already in progress, or finished

    self.registration_progress = "Getting file list"

    fis = self.data_provider
              .provider_list_all  # array of FileInfo objects, top level only
              .sort { |a,b| a.name <=> b.name }

    self.registration_progress = "Starting registration of #{fis.size} potential entries"

    registered = fis.each_with_index.map do |fi,idx|
      next unless Userfile.is_legal_filename?(fi.name)
      next unless fi.symbolic_type == :regular || fi.symbolic_type == :directory

      self.registration_progress = "Registering file #{idx+1}/#{fis.size}: #{fi.name}"

      # Try to assign a proper CBRAIN Userfile type
      suggested_klass = SingleFile     if fi.symbolic_type == :regular
      suggested_klass = FileCollection if fi.symbolic_type == :directory
      suggested_klass = suggested_klass.suggested_file_type(fi.name) || suggested_klass
      suggested_klass = TextFile if suggested_klass == SingleFile && fi.name =~ /README|CHANGE/

      userfile = suggested_klass.new(
        :name             => fi.name,
        :size             => (fi.symbolic_type == :regular ? fi.size : nil),
        :num_files        => (fi.symbolic_type == :regular ? 1       : nil),
        :user_id          => USERFILES_OWNER.id,
        :group_id         => self.work_group.id,
        :data_provider_id => self.data_provider.id,
        :immutable        => true,
        :group_writable   => false,
        :hidden           => false,
        :archived         => false,
      )

      next unless userfile.save # ignore errors?
      userfile.set_size
      userfile

    end.compact

    self.registration_progress = "Completed"

    Message.send_message(DATA_PROVIDER_OWNER,
      {
        :type          => :system,
        :header        => "OpenNeuro dataset populated",
        :description   => "An OpenNeuro dataset has been populated",
        :variable_text => "OpenNeuro Dataset Name: #{self.name}\n" +
                          "Populated: #{registered.size} CBRAIN entries / #{fis.size} entries on DP"
      }
    )

    true

  rescue => ex
    self.registration_progress = "Error during registration process. Admins notified."
    Message.send_internal_error_message(User.admin, "OpenNeuro File Registration Exception", ex)
    false
  end

  private

  # Returns a WorkGroup fetcher or constructor
  # representing an OpenNeuro dataset. (ActiveRecord query)
  def self.work_group_builder(name, version)
    WorkGroup.where(
      :creator_id     => WORK_GROUP_OWNER.id,
      :name           => work_group_name_builder(name, version),
      :public         => true,
      :not_assignable => true,
      :invisible      => false,
      :track_usage    => true,
    )
  end

  # Returns a DataladDataProvider fetcher or constructor
  # representing an OpenNeuro dataset. (ActiveRecord query)
  def self.data_provider_builder(name, version, group_id)
    DataladDataProvider.where(
      :name                   => data_provider_name_builder(name, version),
      :user_id                => DATA_PROVIDER_OWNER.id,
      :group_id               => group_id,
      :datalad_repository_url => "#{DATALAD_REPO_URL_PREFIX}/#{name}",
      :containerized_path     => version,
      :online                 => true,
    )
  end

  # Generates the name of the WorkGroup that represents
  # the OpenNeuro dataset.
  #
  #   "OpenNeuro-ds123456-v1.2.3"
  def self.work_group_name_builder(name, version)
    "OpenNeuro-#{name}-#{version}"
  end

  # Generates the name of the DatalaDataProvider that represents
  # the OpenNeuro dataset.
  #
  #   "OpenNeuro-ds123456-v1_2_3"
  def self.data_provider_name_builder(name, version)
    "OpenNeuro-#{name}-#{version.gsub('.','_')}"
  end

end
