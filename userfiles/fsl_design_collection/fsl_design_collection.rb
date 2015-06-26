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

class FslDesignCollection < FileCollection
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.pretty_type #:nodoc:
    "Fsl design collection"
  end

  # *.mat
  def design_matrix_file  #:nodoc:
    cached_list_files.select { |f| f.name =~ /\.mat$/ }.first.try(:name)
  end

  # *.con
  def t_contrasts_file  #:nodoc:
    cached_list_files.select { |f| f.name =~ /\.con$/ }.first.try(:name)
  end

  # *.fts
  def f_contrasts_file  #:nodoc:
    cached_list_files.select { |f| f.name =~ /\.fts$/ }.first.try(:name)
  end

  # *.grp
  def exchangeability_matrix  #:nodoc:
    cached_list_files.select { |f| f.name =~ /\.grp$/ }.first.try(:name)
  end

  def cached_list_files
    @cached_list_files = self.list_files
  end



end
