
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

# CbrainTask subclass for combining a set of partial
# CIVET results into a single larger CIVET result.
#
# Original author: Pierre Rioux
class CbrainTask::CivetCombiner < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params

    # List of CivetOutput IDs directly supplied
    civet_collection_ids = params[:civet_collection_ids] || [] # used to be string
    civet_ids            = civet_collection_ids.is_a?(Array) ? civet_collection_ids : civet_collection_ids.split(/,/)

    # Fetch list of CivetOutput IDs indirectly through task list
    task_list_ids        = params[:civet_from_task_ids] || ""
    task_ids             = task_list_ids.split(/,/)
    civet_collection_ids = [] if ! task_ids.empty? # with a task ID list, we ignore the original civet_collection_ids
    task_ids.each do |tid|
      task    = CbrainTask.find(tid)
      tparams = task.params
      cid     = tparams[:output_civetcollection_id]  # old a single id
      cids    = tparams[:output_civetcollection_ids] # new, an array
      cb_error "Could not find any CIVET output IDs from task '#{task.bname_tid}'." if cid.blank? && cids.blank?
      civet_ids << cid  unless cid.blank?
      civet_ids += cids unless cids.blank?
    end

    # Save back full list of all CivetOutput IDs into params
    civet_ids = civet_ids.map(&:to_s).uniq.sort
    params[:civet_collection_ids] = civet_ids

    # Get each source CivetOutput
    cols = []
    civet_ids.each do |id|
      col = Userfile.find(id.to_i)
      unless col && (col.is_a?(CivetOutput)) # || col.is_a?(CivetStudy))
        self.addlog("Error: cannot find CivetOutput with ID=#{id}")
        return false
      end
      cols << col
    end

    if cols.empty?
      self.addlog("Error: no valid CivetOutputs supplied?")
      return false
    end

    # Synchronize them all
    self.addlog("Synchronizing collections to local cache")
    cols.each_with_index do |col,idx|
      self.addlog("Synchronizing '#{col.name}'") unless cols.size > 50
      col.sync_to_cache
      self.addlog("Synchronized #{idx+1}/#{cols.size} collections...") if cols.size > 50 && (idx % 50 == 49 || idx == cols.size - 1)
    end
    self.addlog("Synchronization finished.")

    # Choose a DP id if none was supplied; we pick the first collections' DP.
    self.results_data_provider_id ||= cols[0].data_provider_id

    # Check that all CIVET outputs have
    # 1) the same 'prefix'
    # 2) a distinct 'dsid'
    self.addlog("Checking collections: prefix and dsid...")
    seen_prefix = {}
    seen_dsid   = {}
    cols.each do |col|
      prefix = col.prefix
      dsid   = col.dsid
      if prefix.blank?
        self.addlog("Could not find PREFIX for CivetOutput '#{col.name}'.")
        return false
      end
      if dsid.blank?
        self.addlog("Could not find DSID for CivetOutput '#{col.name}'.")
        return false
      end
      seen_prefix[prefix]   = true
      seen_dsid[dsid]     ||= 0
      seen_dsid[dsid]      += 1
    end

    if seen_prefix.size != 1
      self.addlog("Error, found more than one PREFIX in the CIVET outputs: #{seen_prefix.keys.sort.join(', ')}")
      return false
    end

    prefix = seen_prefix.keys[0]

    if seen_dsid.values.select { |v| v > 1 }.size > 0
      reports = seen_dsid.map { |dsid,count| count > 1 ? "'#{dsid}' x #{count}" : "" }
      self.addlog("Error, found some DSIDs represented more than once: #{reports.sort.join(', ')}")
      return false
    end

    self.addlog("Ready to combine outputs; PREFIX=#{prefix}, DSIDs=#{seen_dsid.keys.sort.join(', ')}")

    # Just record the PREFIX in the task's params.
    params[:prefix] = prefix

  end

  def cluster_commands #:nodoc:
    nil   # Special case: no cluster job.
  end

  def save_results #:nodoc:
    params       = self.params
    provid       = self.results_data_provider_id
    newname      = params[:civet_study_name]
    prefix       = params[:prefix] # set in setup() above

    # Virtual studies are now default, but as an option
    # we still support full copies.
    fullcopy    = params[:copy_files].presence == 'Yes'

    # Create new CivetStudy object to hold them all
    # and in the darkness bind them
    # Two modes: create a CivetVirtualStudy (shallow copies),
    # or copy files in a CivetStudy (deep copies)
    klass        = fullcopy ? CivetStudy : CivetVirtualStudy

    # Create new CivetStudy object to hold them all
    # and in the darkness bind them
    newstudy = safe_userfile_find_or_new(klass,
      :name             => newname,
      :data_provider_id => provid
    )

    civet_collection_ids = params[:civet_collection_ids] || [] # used to be string
    civet_ids            = civet_collection_ids.is_a?(Array) ? civet_collection_ids : civet_collection_ids.split(/,/)

    # Save back full list of all collection IDs into params
    civet_ids = civet_ids.map(&:to_s).uniq.sort
    params[:civet_collection_ids] = civet_ids

    # Find the CivetOutputs themselves
    cols = civet_ids.map { |id| Userfile.find(id) }

    # Now let's fill the new CivetStudy with everything in
    # the original outputs.
    self.addlog("Preparing #{newstudy.class.to_s} ...")
    newstudy.save!
    newstudy.cache_prepare
    coldir = newstudy.cache_full_path
    Dir.mkdir(coldir) unless File.directory?(coldir)

    # Add CivetOutputs depending on mode
    self.addlog("Adding CivetOutputs ...")
    if newstudy.is_a?(CivetVirtualStudy)
      newstudy.set_civet_outputs(cols)
    else # fullcopy == true
      copy_civet_outputs(newstudy,cols) # use rsync to make full copies
    end

    # Save the content and DB model
    self.addlog("Syncing #{newstudy.class} '#{newstudy.name}' (ID=#{newstudy.id}) to its Data Provider...")
    newstudy.sync_to_provider
    newstudy.set_size
    newstudy.save

    # Some provenance information.
    params[:output_civetstudy_id] = newstudy.id
    subjects = cols.map(&:dsid).compact.sort
    newstudy.addlog("Subjects are: #{subjects.join(", ")}")
    self.addlog_to_userfiles_these_created_these(cols,[newstudy],"with prefix '#{prefix}'")

    # Option: destroy the original sources; only allowed when doing full copies.
    if fullcopy && params[:destroy_sources] && params[:destroy_sources].to_s == 'Yes'
      cols.each do |col|
        self.addlog("Destroying source #{col.class.to_s} '#{col.name}'")
        col.destroy rescue true
      end
    end

    true
  end



  protected

  # Makes a full copy of a bunch of CivetOutputs inside
  # the content of the study, using rsync; the CivetOutputs
  # are assumed to be already synchronized.
  #
  # This should be implemented in some sort of set_civet_outputs() in the CivetStudy model
  def copy_civet_outputs(newstudy,civetoutputs) #:nodoc:
    errfile      = self.stderr_cluster_filename
    coldir       = newstudy.cache_full_path

    # Issue rsync commands to combine the files
    civetoutputs.each_with_index do |col,idx|
      dsid   = col.dsid
      if civetoutputs.size <= 50
        self.addlog("Adding #{col.class.to_s} '#{col.name}'")
      end
      colpath  = col.cache_full_path.to_s
      dsid_dir = (coldir + dsid).to_s
      Dir.mkdir(dsid_dir) unless File.directory?(dsid_dir)
      rsyncout = IO.popen("rsync -a -l #{colpath.bash_escape}/ #{dsid_dir.bash_escape} 2>&1 | tee -a #{errfile.to_s.bash_escape}","r") do |fh|
        fh.read
      end
      unless rsyncout.blank?
        cb_error "Error running rsync; rsync returned '#{rsyncout}'"
      end
      if civetoutputs.size > 50 && (idx % 50 == 49 || idx == civetoutputs.size - 1)  # group the log entries by batches of 50
        subjslice_start = 50*(idx/50)
        subjslice_names = subjects[subjslice_start,50].join(", ")
        self.addlog("Added #{subjslice_names}")
      end
    end
  end

end

