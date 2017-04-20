
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

  def surfaces_dir #:nodoc:
    "surfaces"
  end

  def thickness_dir #:nodoc:
    "thickness"
  end

  def surfaces_objs #:nodoc:
    return @surfaces_objs unless @surfaces_objs.nil?
    surfaces_dir         = self.surfaces_dir
    surfaces_objs        = self.list_files(surfaces_dir).map(&:name).select { |n| n =~ /\.obj\z/ }
    rsl_surfaces_objs    = surfaces_objs.select { |name| name =~ /_rsl_/ }
    no_rsl_surfaces_objs = surfaces_objs - rsl_surfaces_objs
    surfaces_objs        = no_rsl_surfaces_objs.sort + rsl_surfaces_objs.sort
    surfaces_objs        = surfaces_objs.map { |file| Pathname.new(file).basename }
    @surfaces_objs       = surfaces_objs
  end

  def overlays #:nodoc:
    return @overlays unless @overlays.nil?
    # Extract all the overlays
    # 1. thickness
    thickness_dir           = self.thickness_dir
    thickness_txts          = self.list_files(thickness_dir).map(&:name).select { |n| n =~ /\.txt\z/ }
    rsl_thickness_txts      = thickness_txts.select { |name| name =~ /_rsl_/ }
    no_rsl_thickness_txts   = thickness_txts - rsl_thickness_txts
    thickness_txts          = no_rsl_thickness_txts.sort + rsl_thickness_txts.sort
    thickness_txts          = thickness_txts.map { |file| Pathname.new(file).basename }
    thickness_txts_for_select = []
    thickness_txts.each do |path|
      full_path = "#{self.name}/#{thickness_dir}/#{path}"
      thickness_txts_for_select << [path, full_path]
    end
    # 2. surfaces
    surfaces_txts         = self.list_files(surfaces_dir).map(&:name).select { |n| n =~ /\.txt\z/ }
    rsl_surfaces_txts     = surfaces_txts.select { |name| name =~ /_rsl_/ }
    no_rsl_surfaces_txts  = surfaces_txts - rsl_surfaces_txts
    surfaces_txts         = no_rsl_surfaces_txts.sort + rsl_surfaces_txts.sort
    surfaces_txts         = surfaces_txts.map { |file| Pathname.new(file).basename }
    surfaces_txts_for_select = []
    surfaces_txts.each do |path|
      full_path = "#{self.name}/#{surfaces_dir}/#{path}"
      surfaces_txts_for_select << [path, full_path]

    end
    # 3. Combine
    @overlays             = thickness_txts_for_select + surfaces_txts_for_select
  end

  # Returns the CIVET prefix used for this CivetOutput; the value
  # is read from the YAML file stored in the output after creation.
  # Once read in, the value is cached in an object instance variable @prefix
  # AND ALSO in the meta data store (as :prefix).
  def prefix
    @prefix ||= self.meta[:prefix]
    return @prefix if @prefix.present?

    civet_params   = read_cbrain_yaml
    file_args      = civet_params[:file_args] || { "0" => {} }
    file0          = file_args["0"] || {}
    myprefix       = file0[:prefix] || civet_params[:prefix] # new convention || old convention

    @prefix = self.meta[:prefix] = myprefix
  end

  # Returns the CIVET dsid (subject ID) used for this CivetOutput; the value
  # is read from the YAML file stored in the output after creation.
  # Once read in, the value is cached in an object instance variable @dsid
  # AND ALSO in the meta data store (as :dsid).
  def dsid
    @dsid ||= self.meta[:dsid]
    return @dsid if @dsid.present?

    civet_params   = read_cbrain_yaml
    file_args      = civet_params[:file_args] || { "0" => {} }
    file0          = file_args["0"] || {}
    mydsid         = file0[:dsid] || civet_params[:dsid] # new convention || old convention

    @dsid = self.meta[:dsid] = mydsid
  end

  private

  def read_cbrain_yaml #:nodoc:
    return @civet_params if @civet_params.present?
    ymltext        = File.read(self.cache_full_path + "CBRAIN.params.yml")
    @civet_params  = YAML.load(ymltext).with_indifferent_access
  end

end
