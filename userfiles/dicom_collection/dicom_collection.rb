
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

# Dicom collection model
# Essentially a file collection of DICOM files
class DicomCollection < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  VOLUME_VIEWER_MAX_SIZE = 500_000_000

  has_viewer Userfile::Viewer.new(MincFile,
    :name    => "Volume Viewer",
    :partial => :volume_viewer,
    :if      => Proc.new { |u| u.is_locally_synced? && u.size.present? && u.size <= VOLUME_VIEWER_MAX_SIZE }
  )

  def self.pretty_type #:nodoc:
    "DICOM file collection"
  end

  # Names of the files of the collection to send to the volume viewer,
  def dicom_file_names
    self.list_files(:all, :regular).map(&:name).sort
  end

  # A DicomCollection is shown as one volume
  def list_fake_files
    []
  end

end
