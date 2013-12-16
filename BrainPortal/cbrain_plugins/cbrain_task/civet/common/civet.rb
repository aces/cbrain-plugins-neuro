
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

# A subclass of CbrainTask to launch bet of Civet.
class CbrainTask::Civet

  # Used in order to compare CIVET version:
  # Return -1 if v1 <  v2 for example v1 = "1.1.11" and v2 = "1.1.12"
  # Return 0  if v1 == v2 for example v1 = "1.1.11" and v2 = "1.1.11"
  # Return 1  if v1 >  v2 for example v1 = "1.1.12" and v2 = "1.1.11"
  def self.compare_versions(v1,v2)
    v1 = $1 if v1 =~ /(\d+(\.\d+){2,})/
    v2 = $1 if v2 =~ /(\d+(\.\d+){2,})/
    raise "Cannot extract version number for comparison" if
      v1.blank? || v2.blank?

    v1 = v1.split(".").map &:to_i
    v2 = v2.split(".").map &:to_i

    while (v1.size < v2.size) do v1.push(0) end
    while (v2.size < v1.size) do v2.push(0) end

    0.upto(v1.size-1) do |i|
      next if v1[i] ==  v2[i]
      return  v1[i] <=> v2[i]
    end

    return 0  # everything is equal
  end

end
