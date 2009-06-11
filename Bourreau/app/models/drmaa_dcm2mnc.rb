
#
# CBRAIN Project
#
# DrmaaTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

class DrmaaDcm2mnc < DrmaaTask

  Revision_info="$Id$"

  def setup
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

    params[:data_provider_id] ||= dicom_col.data_provider.id

    pre_synchronize_userfile(dicom_col)
    vaultname = dicom_col.cache_full_path.to_s
    File.symlink(vaultname,"dicom_col")
    Dir.mkdir("results",0700)

    true
  end

  def drmaa_commands
    params       = self.params
    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "dcm2mnc dicom_col results",
    ]
  end

  def save_results
    params      = self.params
    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)
    user_id     = self.user_id

    io = IO.popen("find results -type f -name \"*.mnc\" -print")

    numfail = 0

    io.each_line do |file|
      next unless file.match(/\.mnc\s*$/)
      file = file.sub(/\n$/,"")
      basename = File.basename(file)
      mincfile = SingleFile.new(
        :user_id          => user_id,
        :name             => basename,
        :content          => File.read(file),
	:task             => "Dcm2mnc",
        :data_provider_id => params[:data_provider_id]
      )
      if mincfile.save
        mincfile.move_to_child_of(dicom_col)
        post_synchronize_userfile(mincfile)
        self.addlog("Saved new MINC file #{basename}")
      else
        numfail += 1
        self.addlog("Could not save back result file '#{basename}'.")
      end
    end

    io.close

    return(numfail == 0 ? true : false)
  end

end

