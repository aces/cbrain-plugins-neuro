
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

# Model for BIDS datasets.
class BidsDataset < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => "BIDS Validator",  :partial => :bids_validator

  def self.pretty_type #:nodoc:
    "BIDS dataset"
  end

  def self.file_name_pattern #:nodoc:
    /\.bids$/i
  end

  # This method is meant to be as compatible as possible
  # to the FmriStudy API; NYI: any options!
  def list_subjects(options = {})
    all_subjects
  end

  private

  def all_subjects #:nodoc:
    @_subjects ||= list_files(:top, :directory)
                   .map    { |e| Pathname.new(e.name).basename.to_s }
                   .select { |n| n =~ /^sub-/ }
                   .map    { |n| n[4,999] } # I hope no subject is longer than that!
  end


end
