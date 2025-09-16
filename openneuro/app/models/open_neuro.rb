
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
  GITHUB_VALIDATION_URL   = 'https://api.github.com/repos/OpenNeuroDatasets/:name/git/ref/tags/:version'

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

    # Save information for tracking progress
    self.registration_progress = "Getting file list"

    # List of everything at the top of the DP
    fis = self.data_provider
              .provider_list_all  # array of FileInfo objects, top level only
              .sort { |a,b| a.name <=> b.name }

    # Save information for tracking progress
    self.registration_progress = "Starting registration of #{fis.size} potential entries"
    self.raw_file_count = fis.size

    # Prepare an array of [ 'type-basename', 'type-basename' ... ]
    items = fis.map do |fi|
      fname, ftype = fi.name, fi.symbolic_type
      next unless Userfile.is_legal_filename?(fname)
      next unless ftype == :regular || ftype == :directory
      suggested_klass = SingleFile     if ftype == :regular
      suggested_klass = FileCollection if ftype == :directory
      suggested_klass = suggested_klass.suggested_file_type(fname) || suggested_klass
      suggested_klass = TextFile if suggested_klass == SingleFile && fname =~ /README|CHANGE/i
      "#{suggested_klass}-#{fname}"
    end.compact

    # More information for tracking progress
    self.to_register_file_count = items.size

    # Create the BackgroundActivity object
    bac = BackgroundActivity::RegisterFile.local_new(
      User.admin.id, items, nil,
      { # options hash
        :src_data_provider_id => self.data_provider.id,
        :group_id             => self.work_group.id,
        :as_user_id           => USERFILES_OWNER.id,
        :immutable            => true,
      }
    )
    bac.save!

    # For tracking progress
    self.registration_bac_id = bac.id

    return true

  rescue => ex
    self.registration_progress = "Error during registration process. Admins notified."
    Message.send_internal_error_message(User.admin, "OpenNeuro File Registration Exception", ex)
    false
  end

  # Instance method of the class method of the same name
  def valid_name_and_version?
    self.class.valid_name_and_version?(self.name,self.version)
  end

  ############################################################
  # Meta data persistence helpers; here we store and retrieve
  # miscellanous values used for tracking the progress of
  # the registration BAC. All of the key-values are stored in
  # the metadata of the DataProvider associated with the ON dataset.
  ############################################################

  # Set the progress string when registration is
  # happening in the background.
  def registration_progress=(infostring)
    self.data_provider.meta[:openneuro_registration_progress] = infostring
  end

  # Returns a progress string when userfile registration
  # is progressing in background.
  #
  # The complicated logic is necessary to support the case of the
  # asynchronous BAC object disappearing after registration is completed,
  # or even while it was happening (leaving it partial).
  def registration_progress
    # Not started yet
    return nil         if self.data_provider.meta[:openneuro_registration_progress].blank?
    # Quickest check; this is permanent once everything is finished.
    return 'Completed' if self.data_provider.meta[:openneuro_registration_progress] == 'Completed'

    # Check the BAC for 'Completed'.
    bac = self.registration_bac # eventually it can disappear
    bac_status = bac&.status&.underscore&.humanize
    if bac_status == 'Completed'
      self.data_provider.meta[:openneuro_registration_progress] = 'Completed'
      self.send_final_message # notify admin
      self.record_openneuro_description
      return 'Completed'
    end

    # If the BAC is in progress in any way, report that.
    if bac_status.present? # BAC exists, but not finished yet
      donecount = bac.current_item
      expcount  = self.to_register_file_count || "Unknown"
      message = "#{bac_status} #{donecount}/#{expcount}"
      self.data_provider.meta[:openneuro_registration_progress] = message
      return message
    end

    # No BAC at all? It could have finished properly.
    donecount = self.data_provider.userfiles.count
    expcount  = self.to_register_file_count || "Unknown" # default chosen to not match
    if donecount.to_s == expcount.to_s
      self.data_provider.meta[:openneuro_registration_progress] = 'Completed'
      self.send_final_message
      self.record_openneuro_description
      return 'Completed'
    end

    # Woh, something went wrong. The BAC disappeared and we can't find all the files.
    message = "Crashed at #{donecount}/#{expcount}"
    self.data_provider.meta[:openneuro_registration_progress] = message
    return message
  end

  def send_final_message
    dp_files      = self.data_provider.userfiles
    num_userfiles = dp_files.count
    num_files     = dp_files.sum(:num_files)
    tot_size      = dp_files.sum(:size)
    raw_files     = self.raw_file_count || "unknown"
    pretty_bytes  = tot_size.to_s.reverse.gsub(/(\d\d\d)/,'\1,').reverse # turns 1234567 into 1,234,567
    pretty_files  = num_files.to_s.reverse.gsub(/(\d\d\d)/,'\1,').reverse
    Message.send_message(DATA_PROVIDER_OWNER,
      {
        :type          => :system,
        :header        => "OpenNeuro dataset populated",
        :description   => "An OpenNeuro dataset has been populated",
        :variable_text => "OpenNeuro Dataset Name: #{self.name}\n" +
                          "Populated: #{num_userfiles} CBRAIN entries (#{pretty_files} files, #{pretty_bytes} bytes) / #{raw_files} entries in OpenNeuro dataset"
      }
    )
    self.to_register_file_count = nil # zap metadata, no longer useful
    self.raw_file_count         = nil # zap metadata, no longer useful
    self.registration_bac_id    = nil # zap metadata, no longer useful
  end

  # Given a 'dataset_description.json' file has been registered,
  # will populate, if needed, the description field of the data
  # provider and the workgroup with the 'Name' found in there.
  def record_openneuro_description
    return false if self.work_group.description.present?
    ddj = self.data_provider.userfiles.where(:type => JsonFile, :name => 'dataset_description.json').first
    return false unless ddj
    ddj.sync_to_cache
    dd = JSON.parse(File.read(ddj.cache_full_path))
    desc = dd['Name']
    return false if desc.blank?
    self.work_group   .update_attribute(:description, desc)
    self.data_provider.update_attribute(:description, desc)
    true
  rescue
    false # just give up
  end

  # Returns the timestamp of the last time the
  # registration progress string was updated.
  def registration_progress_update_time
    bac = self.registration_bac
    return bac.updated_at if bac
    self.data_provider.id.presence &&
    self.data_provider.meta.md_for_key(:openneuro_registration_progress)&.updated_at
  end

  # Returns true if all files have been registered
  def all_registered?
    self.configured? && self.registration_progress == 'Completed'
  end

  def registration_bac
    bac_id = self.data_provider.meta[:openneuro_registration_bac_id]
    BackgroundActivity::RegisterFile.where(:id => bac_id).first
  end

  def registration_bac_id=(bac_id)
    self.data_provider.meta[:openneuro_registration_bac_id] = bac_id
  end

  def raw_file_count
    self.data_provider.meta[:open_neuro_raw_file_count]
  end

  def raw_file_count=(val)
    self.data_provider.meta[:open_neuro_raw_file_count] = val
  end

  def to_register_file_count
    self.data_provider.meta[:open_neuro_to_register_file_count]
  end

  def to_register_file_count=(val)
    self.data_provider.meta[:open_neuro_to_register_file_count] = val
  end


  ############################################################

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

  # Validation of a pair [ dataset, version ] performed with:
  #
  #   curl -H "Accept: application/vnd.github+json"
  #        -H "X-GitHub-Api-Version: 2022-11-28"
  #        "https://api.github.com/repos/OpenNeuroDatasets/ds004906/git/ref/tags/2.4.0"
  #
  # The typical response is like this:
  #
  #   {
  #     "ref": "refs/tags/2.4.0",
  #     "node_id": "REF_kwDOK8fpRq9yZWZzL3RhZ3MvMi40LjA",
  #     "url": "https://api.github.com/repos/OpenNeuroDatasets/ds004906/git/refs/tags/2.4.0",
  #     "object": {
  #       "sha": "1aa6d3a098d16009d39adde6a7abe1c34d4b07d6",
  #       "type": "commit",
  #       "url": "https://api.github.com/repos/OpenNeuroDatasets/ds004906/git/commits/1aa6d3a098d16009d39adde6a7abe1c34d4b07d6"
  #     }
  #   }
  #
  # The method just returns true or false.
  def self.valid_name_and_version?(name, version)
    return false unless name    =~ /\Ads\d+\z/
    return false unless version =~ /\A[a-z0-9][\w\.\-]+\z/

    validation_url = GITHUB_VALIDATION_URL
      .sub(':name',    name   )
      .sub(':version', version)

    github_json = Rails.cache.fetch(validation_url, expires_in: 2.days) do
      IO.popen(
        [
          "curl",
          "-s",
          "--connect-timeout", "10",
          "--max-time",        "10",
          "-H", "Accept: application/vnd.github+json",
          "-H", "X-GitHub-Api-Version: 2022-11-28",
          validation_url
        ], "r"
      ) { |fh| fh.read }
    end

    return false if github_json.blank?

    response = JSON.parse(github_json) rescue nil
    return false if response.nil?

    return true if response["ref"].present?
    false
  rescue
    return false
  end

end
