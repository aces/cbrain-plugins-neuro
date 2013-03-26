
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

# A subclass of ClusterTask to run dcm2nii.
class CbrainTask::Dcm2nii < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include RestartableTask
  include RecoverableTask

  def setup #:nodoc:
    params      = self.params
    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)

    unless dicom_col
      self.addlog("Could not find active record entry for file collection #{dicom_colid}")
      return false
    end

    unless dicom_col.is_a?(FileCollection)
      self.addlog("Error: ActiveRecord entry #{dicom_colid} is not a file collection.")
      return false
    end

    self.results_data_provider_id ||= dicom_col.data_provider_id

    dicom_col.sync_to_cache   
    cachename = dicom_col.cache_full_path.to_s
    safe_symlink(cachename, dicom_col.name)

    true
  end

  def job_walltime_estimate #:nodoc:
    1.hours
  end
  
  def cluster_commands #:nodoc:
    params      = self.params

    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)

    additional_opts = ""
    additional_opts << " -a N" if params[:anonymize] == "0"
    additional_opts << " -d N" if params[:date] == "0"
    additional_opts << " -e N" if params[:events] == "0"
    additional_opts << " -g N" if params[:gzip] == "0"
    additional_opts << " -i N" if params[:id] == "0"
    additional_opts << " -p N" if params[:protocol] == "0"

    safe_mkdir(result_dir,0700)
    cmd_dcm2nii = "dcm2nii #{additional_opts} -o #{result_dir.to_s.bash_escape} #{dicom_col.name.bash_escape}"

    cmds = []
    cmds << "echo Starting dcm2nii"
    cmds << "echo Running #{cmd_dcm2nii}"
    cmds << "#{cmd_dcm2nii}"

    cmds
  end
  
  def save_results #:nodoc:
    params      = self.params
    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)

    relpaths = []
    IO.popen("find #{result_dir.to_s.bash_escape} -type f -print","r") do |io|
      io.each_line do |relpath|
        relpath.strip!
        next unless relpath.match(/\.nii(.gz)?$/i) || 
                    relpath.match(/\.bval$/i)      ||
                    relpath.match(/\.bvec$/i)
        relpaths << relpath
      end
    end

    orig_basenames = relpaths.map { |relpath| File.basename(relpath) }
    params[:orig_niifile_basenames] = orig_basenames # to help user debug renaming problems

    numfail = 0
    numok   = 0

    niifiles       = []
    FileUtils.remove_dir("renamed", true) rescue true
    safe_mkdir("renamed",0700)

    relpaths.each do |relpath|
      newrelpath   = rename_by_pattern(dicom_col.name,relpath)
      basename     = File.basename(newrelpath)
      niifile      = safe_userfile_find_or_new(NiftiFile,
        :name             => basename,
        :data_provider_id => self.results_data_provider_id
      )
      niifile.cache_copy_from_local_file(newrelpath)
      if niifile.save
        niifile.move_to_child_of(dicom_col)
        numok += 1
        self.addlog("Saved new NIfTI file #{basename}")
        niifiles       << niifile
      else
        numfail += 1
        self.addlog("Could not save back result file '#{basename}'.")
      end
    end

    old_niifile_ids = params[:created_niifile_ids] || []
    new_niifile_ids = niifiles.map &:id

    if params[:erase_old_results] == "1" && numok > 0 && numfail == 0
      old_niifile_ids -= new_niifile_ids
      old_niifile_ids.each do |id|
        u = Userfile.find(id) rescue nil
        next unless u
        u.destroy rescue true
        self.addlog("Erasing old result niifile '#{u.name}'")
      end
    end
    
    params[:created_niifile_ids]    = new_niifile_ids

    self.addlog_to_userfiles_these_created_these([dicom_col],niifiles)

    return true if numok > 0 && numfail == 0
    false
  end

  private

  def rename_by_pattern(dicom_name,orig_nii_relpath) #:nodoc:
    pattern = self.params[:output_filename_pattern] || ""
    pattern.strip!
    if pattern.blank?
      return orig_nii_relpath # nothing to do really
    end

    # Create standard keywords
    now = Time.zone.now
    components = {
      "date"       => now.strftime("%Y-%m-%d"),
      "time"       => now.strftime("%H:%M:%S"),
      "task_id"    => self.id.to_s,
      "run_number" => self.run_number.to_s
    }

    # Add {dicom-N} keywords
    dcm_comps = dicom_name.split(/([a-z0-9]+)/i)
    1.step(dcm_comps.size-1,2) do |i|
      keyword = "dicom-#{(i-1)/ 2+1}"
      components[keyword] = dcm_comps[i]
    end

    # Add {nii-N} keywords
    nii_name = File.basename(orig_nii_relpath)
    nii_comps = nii_name.split(/([a-z0-9]+)/i)
    1.step(nii_comps.size-1,2) do |i|
      keyword = "nii-#{(i-1)/ 2+1}"
      components[keyword] = nii_comps[i]
    end

    # Create new basename
    final = pattern.pattern_substitute(components) # in cbrain_extensions.rb

    # Append .nii or .nii.gz if necessary
    final.sub!(/\.nii(\.gz)?$/i,"")
    extension = orig_nii_relpath.scan(/\.[^\.]+$/).last
    if orig_nii_relpath =~ /\.nii\.gz$/i
      final += ".nii.gz"
    else 
      final += "#{extension}"
    end

    # Validate it
    cb_error "Pattern for new filename produces an invalid filename: '#{final}'." unless
      Userfile.is_legal_filename?(final)

    # Create hard link with new name
    new_relpath = "renamed/#{final}"
    if File.exist?(new_relpath)
      cb_error "Error: it seems this task's renaming pattern mapped several of dcm2nii's output niifiles to the same new name '#{final}'."
    end

    File.link(orig_nii_relpath,new_relpath)

    return new_relpath

  end

  def result_dir
    "result_#{self.run_number}"
  end

end
