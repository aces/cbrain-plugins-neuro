
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

# Civet output model
# Essentially a file collection with some methods for handling civet output
#
# This class represents a FileCollection meant specifically to represent the output
# of a *civet* run (see CbrainTask::Civet). The instance methods are all meant to
# provide simple access to the contents of particular directories in the
# directory tree produced by *civet*.
class CivetOutput < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  reset_viewers # we invoke the FileCollection's viewer directly inside civet_output
  has_viewer    :name => "CIVET Output",   :partial => :civet_output
  has_viewer    :name => "Surface Viewer", :partial => :surface_viewer, :if  => Proc.new { |u| u.is_locally_synced? }

  def qc_images  #:nodoc:
    self.list_files("verify").select { |f| f.name =~ /\.png$/ }
  end

  def surface_dir
    "surfaces"
  end

  def thickness_dir
    "thickness"
  end

end
