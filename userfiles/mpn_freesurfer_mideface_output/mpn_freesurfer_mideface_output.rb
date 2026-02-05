
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

# A FileCollection to model the output of Mideface from FreeSurfer for MPn project
class MpnFreesurferMidefaceOutput < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => "Surface Viewer", :partial => :surface_viewer, :if => Proc.new { |u| u.is_locally_synced? && u.surfaces_objs.size >= 1 }

  def surfaces_objs #:nodoc:
    return @surfaces_objs unless @surfaces_objs.nil?

    surf_list = self.list_files.map(&:name).select { |n| n =~ /\.surf\z/ }
    surf_list.map!{|path| Pathname.new(path).relative_path_from(self.name).to_s }

    return surf_list
  end

  def self.pretty_type #:nodoc:
    "MPN FreeSurfer MiDeface Output"
  end

end


