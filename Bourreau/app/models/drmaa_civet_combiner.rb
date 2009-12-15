
#
# CBRAIN Project
#
# DrmaaCivetCombiner subclass for combining a set of partial
# CIVET results into a single larger CIVET result.
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of DrmaaTask to run civet_combiner.
class DrmaaCivetCombiner < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def setup
    params       = self.params
    user_id      = self.user_id

    user    = User.find(user_id)
    provid  = params[:data_provider_id]

    civet_collection_ids = params[:civet_collection_ids] || ""
    newname              = params[:civet_study_name]

    civet_ids = civet_collection_ids.split(/,/)

    # Get each source collection
    cols = []
    civet_ids.each do |id|
      col = Userfile.find(id.to_i)
      unless col && (col.is_a?(CivetCollection) || col.is_a?(CivetStudy))
        self.addlog("Error: cannot find Civet Collection or Study with ID=#{id}")
        return false
      end
      cols << col
    end

    # Synchronize them all
    self.addlog("Synchronizing collections to local cache")
    cols.each do |col|
      self.addlog("Synchronizing '#{col.name}'")
      col.sync_to_cache
    end

    # Create new CivetStudy object to hold them all
    # and in the darkness bind them
    newcol = CivetStudy.new(
      :name             => newname,
      :user_id          => user_id,
      :data_provider_id => provid,
      :group_id         => user.own_group.id
    )

    # Save the new CivetStudy object
    unless newcol.save
      self.addlog("Cannot create a new CivetStudy named '#{name}'.")
      return false
    end

    # Now let's fill the new CivetStudy with everything in
    # the original collections; if anything fails, we need
    # to destroy the incomplete newcol object.

    self.addlog("Combining collections...")
    newcol.addlog("Created by task #{self.bname_tid}")
    begin
      newcol.cache_prepare
      coldir = newcol.cache_full_path
      Dir.mkdir(coldir) unless File.directory?(coldir)
      errfile = self.stderrDRMAAfilename

      # Issue rsync command to combine the files
      cols.each do |col|
        self.addlog("Adding #{col.class.to_s} '#{col.name}'")
        newcol.addlog_context(self,"Adding #{col.class.to_s} '#{col.name}'")
        colpath = col.cache_full_path
        need_slash = col.is_a?(CivetStudy) ? "/" : "" # TODO update once a proper CIVET structure is designed
        rsyncout = IO.popen("rsync -a -l '#{colpath.to_s}#{need_slash}' #{coldir} 2>&1 | tee -a #{errfile}","r") do |fh|
          fh.read
        end
        unless rsyncout.blank?
          cb_error "Error running rsync; rsync returned '#{rsyncout}'"
        end
      end
      newcol.sync_to_provider
      newcol.set_size
      newcol.save

      # Option: destroy the original sources
      if params[:destroy_sources] && params[:destroy_sources].to_s == 'YeS'
        cols.each do |col|
          self.addlog("Destroying source #{col.class.to_s} '#{col.name}'")
          col.destroy rescue true
        end
      end

    rescue => itswrong
      newcol.destroy
      raise itswrong
    end

    true
  end

  #See DrmaaTask.
  def drmaa_commands
    params       = self.params
    user_id      = self.user_id

    nil   # Special case: no cluster job.
  end
  
  #See DrmaaTask.
  def save_results
    params       = self.params
    user_id      = self.user_id

    true  # Special case: nothing to do!
  end

end

