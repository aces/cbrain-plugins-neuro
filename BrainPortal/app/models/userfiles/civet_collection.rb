
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

# Obsolete class for backward compatibility.
# The real class is CivetOutput
class CivetCollection < CivetOutput

  Revision_info=CbrainFileRevision[__FILE__]

  after_initialize :adjust_civet_collection_type

  private

  # Silently tries to adjust the type.
  # This can fail if the 'object' is actually
  # part of a join, so we move on.
  def adjust_civet_collection_type
    self.type = 'CivetOutput'
    self.save
    true
  rescue
    true
  end

end
