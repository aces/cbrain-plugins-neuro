
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

end
