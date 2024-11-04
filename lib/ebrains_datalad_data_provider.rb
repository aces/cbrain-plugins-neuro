
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# This class implements a DataProvider that can
# fetch files and directories from a Ebrains-aware Datalad
# remote storage. At the DP level, here, a token
# must be provided in the attribute cloud_storage_client_token
class EbrainsDataladDataProvider < DataladDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.pretty_category_name #:nodoc:
    "EbrainsDataladProvider"
  end

  private

  # Returns a DataladRepository handler that provides
  # an api to a file system instance of a datalad install tree
  def datalad_repo
    userfile_for_datalad_cache.sync_to_cache
    @datalad_repo ||= DataladRepository.new(
      userfile_for_datalad_cache.cache_full_path,
      self.cloud_storage_client_token
    )
  end

end

