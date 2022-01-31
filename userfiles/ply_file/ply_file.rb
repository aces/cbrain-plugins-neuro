
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

# Model for a PLY file.
class PlyFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => "PLY Viewer",  :partial => :ply_viewer, :if =>
             Proc.new { |u| u.size.present? &&
                            u.size < 500.megabytes &&
                            u.is_locally_synced?
                      }

  has_content :method => :ply_content, :type => :text

  def self.file_name_pattern #:nodoc:
    /\.ply(\.gz|\.Z|\.bz2)?$/i
  end

  # Returns the ply file itself; uncompressed if it is compressed on the DP.
  def ply_content
    if self.name =~ /(\.gz|\.Z)$/i
      IO.popen("gunzip -c #{self.cache_full_path.to_s.bash_escape}") { |fh| fh.read }
    elsif self.name =~ /(\.bz2)$/i
      IO.popen("bunzip2 -c #{self.cache_full_path.to_s.bash_escape}") { |fh| fh.read }
    else
      File.open(self.cache_full_path, "r").read
    end
  end

end

