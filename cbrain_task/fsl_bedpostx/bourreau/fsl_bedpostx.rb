
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

# A subclass of ClusterTask to run FslBedpostx.
class CbrainTask::FslBedpostx < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params       = self.params
    input_colid  = params[:interface_userfile_ids][0]
    collection   = FileCollection.find(input_colid)
    collection.sync_to_cache
    safe_symlink(collection.cache_full_path,"input")

    # TODO: replace with a call to program 'bedpostx_datacheck' ?
    expected_input = [ "bvecs", "bvals" ]
    errors = 0
    expected_input.each do |base|
      next if File.exist?("input/#{base}")
      self.addlog("Cannot proceed: we expected to find an entry '#{base}' in the input directory, but it's not there!")
      errors += 1
    end
    return false if errors > 0

    self.results_data_provider_id ||= collection.data_provider_id

    true
  end

  def job_walltime_estimate #:nodoc:
    12.hours
  end

  def cluster_commands #:nodoc:
    params       = self.params
    fibres       = params[:fibres]
    weight       = params[:weight]
    burn_in      = params[:burn_in]
    fibres       = "2"   if fibres.blank?
    weight       = "1"   if weight.blank?
    burn_in      = "100" if burn_in.blank?
    cb_error "Unexpected value '#{fibres}' for number fibres." if fibres.to_s !~ /^\d+(\.\d+)?$/ # TODO real?
    cb_error "Unexpected value '#{weight}' for weight."        if weight.to_s !~ /^\d+(\.\d+)?$/ # TODO real?
    cb_error "Unexpected value '#{burn_in}' for burn_in."      if burn_in.to_s !~ /^\d+$/
    command =  "bedpostx input -n #{fibres} -w #{weight} -b #{burn_in}"
    self.addlog("Command: #{command}")
    [
      command
    ]
  end

  def save_results #:nodoc:
    params       = self.params
    input_colid  = params[:interface_userfile_ids][0]
    collection   = FileCollection.find(input_colid)

    if ! File.exist?("input.bedpostX") || ! File.directory?("input.bedpostX")
      self.addlog("Could not find expected output directory 'input.bedpostX'.")
      return false
    end

    outfile = safe_userfile_find_or_new(FileCollection,
      :name             => "#{collection.name}.#{self.run_id}.bedpostX",
      :data_provider_id => self.results_data_provider_id
    )
    outfile.save!
    outfile.cache_copy_from_local_file("input.bedpostX")
    params[:outfile_id] = outfile.id

    # Log information
    self.addlog_to_userfiles_these_created_these([ collection ],[ outfile ])
    outfile.move_to_child_of(collection)
    self.addlog("Saved new BEDPOSTX result file #{outfile.name}.")
    true
  end

end

