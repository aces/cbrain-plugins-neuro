
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
class CivetVirtualStudy < CivetStudy

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => 'CIVET Virtual Study', :partial => :civet_virtual_study

  # Sync the CivetVirtualStudy, with the CivetOutputs if deep=true
  def sync_to_cache(deep=true)
    super()
    if deep
      civet_outputs = get_civet_outputs
      make_cache_symlinks(civet_outputs)
    end
  end

  # Load the list of CivetOutputs from the CbrainFileList
  def get_civet_outputs
    self.sync_to_cache(false)

    civet_outputs = CivetOutput.find(subject_ids)
  end

  def subject_ids
    self.sync_to_cache(false)
    full_path = self.cache_full_path + "_civet_outputs.cbcsv"

    cbfl = CbrainFileList.new
    cbfl.load_from_file(full_path)

    cbfl.ordered_raw_ids
  end

  # Create symbolic links within the study to the CivetOutput Userfile cache
  def make_cache_symlinks(civet_outputs)
    self.cache_writehandle do
      civet_outputs.each do |co|
        co.sync_to_cache

        link_path = self.cache_full_path + co.dsid
        File.symlink(co.cache_full_path, link_path) unless File.exist?(link_path)
      end
    end
  end

  # Link a set of CivetOutputs to this study
  def set_civet_outputs(userfiles)
    content = CbrainFileList.create_csv_file_from_userfiles(userfiles)

    self.cache_writehandle do
      Dir.mkdir(self.cache_full_path) unless Dir.exist?(self.cache_full_path)
      File.write(self.cache_full_path + "_civet_outputs.cbcsv", content)
    end

    self.make_cache_symlinks(userfiles)
  end

end
