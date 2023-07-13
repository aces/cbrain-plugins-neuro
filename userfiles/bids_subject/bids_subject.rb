
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

# Model for BIDS a subject subdirectory inside a BIDS dataset.
class BidsSubject < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => "BIDS Validator",  :partial => :bids_validator, :if => Proc.new { |u| u.is_locally_synced? && u.validator_available? }

  def self.pretty_type #:nodoc:
    "BIDS subject"
  end

  def self.file_name_pattern #:nodoc:
    /^sub-\w+$/
  end

  # This method is meant to be as compatible as possible
  # to the FmriStudy API; NYI: any options!
  def list_sessions(options = {})
    @_sessions_for_subject ||=
      list_files(:top, :directory)
      .map    { |e| Pathname.new(e.name).basename.to_s }
      .select { |n| n =~ /^ses-/ }
      .map    { |n| n[4,999] } # Also I hope no session is longer than that.
  end

  ###########################################################
  # BIDS Dataset Validation Helpers
  ###########################################################

  def self.validator_available?
    return @_validator_available if ! @_validator_available.nil?
    @_validator_available = system("type -p bids-validator 1>/dev/null 2>/dev/null").present?
  end

  def validator_available?
    self.class.validator_available?
  end

  def dataset_name_for_validation
    "ValidatorBids#{self.id}"
  end

  def attributes_for_fake_bids_dataset
    # By default the method find_or_create_as_scratch will
    # assign user=admin, group=admin. This scratch file is not meant to
    # be directly accessible by the user.
    {
      :name => dataset_name_for_validation,
    }
  end

  def find_or_create_scratch_bids_dataset_for_validation
    bidsdataset   = usable_scratch_bids_dataset_for_validation
    bidsdataset ||= create_scratch_bids_dataset_for_validation
    bidsdataset
  end

  def find_scratch_bids_dataset_for_validation
    ScratchDataProvider.main.userfiles.where(attributes_for_fake_bids_dataset).first
  end

  def usable_scratch_bids_dataset_for_validation
    bidsdataset = find_scratch_bids_dataset_for_validation
    return nil if ! bidsdataset
    sync_status = bidsdataset&.local_sync_status
    return nil if ! sync_status
    last_access = sync_status.accessed_at
    return bidsdataset if sync_status.status == 'InSync' && last_access && last_access >= self.updated_at
    bidsdataset.provider_is_newer if sync_status.status == 'InSync' # invalidate old scratch cache
    nil
  end

  def create_scratch_bids_dataset_for_validation
    subj_path    = self.cache_full_path.to_s # assumes it's already synchronized

    # Prepare a fake BIDS dataset into SCRATCH/.../ValidatorBids9876
    bidsdataset  = BidsDataset.find_or_create_as_scratch(attributes_for_fake_bids_dataset) do |cache_path|
      Dir.mkdir(cache_path.to_s) unless File.directory?(cache_path.to_s)
      # Copy self ("sub-1234") into the SCRATCH/.../ValidatorBids9876/sub-1234
      rsyncout = bash_this("rsync -a -l --no-g --chmod=u=rwX,g=rX,Dg+s,o=r --delete #{subj_path.bash_escape}/ #{cache_path.to_s.bash_escape}/#{self.name.bash_escape} 2>&1")
      if rsyncout.present?
        cb_error "Failed to copy BidsSubject content for userfile #{self.id} into scratch space for validator. Rsync returned: #{rsyncout}"
      end

      # Create fake dataset_description.json
      File.open("#{cache_path}/dataset_description.json","w") do |fh|
        fh.write dataset_description_json_for_validation
      end
      # Create fake participants.tsv
      File.open("#{cache_path}/participants.tsv","w") do |fh|
        fh.write participants_tsv_for_validation
      end
      # Create fake README
      File.open("#{cache_path}/README","w") do |fh|
        fh.write file_README_for_validation
      end
    end

    bidsdataset
  end

  def run_bids_validator
    bidsdataset      = find_or_create_scratch_bids_dataset_for_validation
    bidspath         = bidsdataset.cache_full_path.to_s
    validator_capt   = bash_this("bids-validator --verbose #{bidspath.bash_escape} 2>&1")
puts_red "run: #{validator_capt.size} bytes"
    validator_capt.gsub!(/\e\[[\d;]+\S/,"")
    validator_capt
  end

  def dataset_description_json_for_validation
    <<-BIDS_DS_DESC
      {
          "Name": "#{self.dataset_name_for_validation}",
          "BIDSVersion": "1.7.0",
          "DatasetType": "raw",
          "Authors": [ "Internal CBRAIN Validator" ],
          "HowToAcknowledge": "This is not a real BIDS dataset",
          "Funding": [
              "Artificial transient dataset created by CBRAIN"
          ],
          "ReferencesAndLinks": [
              "https://github.com/aces/cbrain"
          ],
          "SourceDatasets": [
              {
                  "URL": "https://github.com/aces/cbrain"
              }
          ]
      }
    BIDS_DS_DESC
  end

  def participants_tsv_for_validation
    "participant_id\n#{self.name.sub(/sub-/,"")}\n"
  end

  def file_README_for_validation
    "This is not a real BIDS dataset\n"
  end

  # This utility method runs a bash +command+ , captures the output
  # and returns it. The user of this method is expected to have already
  # properly escaped any special characters in the arguments to the
  # command.
  def bash_this(command) #:nodoc:
    fh = IO.popen(command,"r")
    output = fh.read
    fh.close
    output
  end

end
