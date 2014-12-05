
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

# This class represents a FileCollection meant specifically
# to represent the output of several *CIVET* runs (see CbrainTask::Civet).
#
# API to come later.
class CivetStudy < FileCollection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'CIVET Study', :partial => :civet_study

  #Returns a list of the ids of the subjects contained in this study.
  def subject_ids
    @subject_id ||= self.list_files(".", :directory).map{ |s| s.name.sub(/^#{self.name}\//, "") }.reject{ |s_id| s_id == "QC" }
  end

end
