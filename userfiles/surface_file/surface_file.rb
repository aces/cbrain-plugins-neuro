
#
# CBRAIN Project
#
# Copyright (C) 2008-2026
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

# Abstract class for Surface file readable by BrainBrowser surface viewer
# like *.surf, *.obj...
class SurfaceFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => "Surface Viewer",  :partial => :surface_viewer, :if =>
             Proc.new { |u| u.size.present? &&
                            u.size < 5000.megabytes &&
                            u.is_locally_synced?
                      }

  has_content :method => :raw_content, :type => :text

  # Returns the obj file itself; uncompressed if it is compressed on the DP.
  def raw_content
    if self.name =~ /(\.mgz|\.gz|\.Z)$/i
      IO.popen([ "gunzip",  "-c", self.cache_full_path.to_s ], "r", :binmode => true ) { |fh| fh.read }
    elsif self.name =~ /(\.bz2)$/i
      IO.popen([ "bunzip2", "-c", self.cache_full_path.to_s ], "r", :binmode => true ) { |fh| fh.read }
    else
      File.open(self.cache_full_path, "r", :binmode => true).read
    end
  end

end

