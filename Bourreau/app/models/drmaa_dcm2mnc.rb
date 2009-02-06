
#
# CBRAIN Project
#
# DrmaaTask subclass
#
# Original author: Pierre Rioux
#
# $Id: drmaa_minc2jiv.rb 96 2008-12-18 18:02:02Z prioux $
#

class DrmaaDcm2mnc < DrmaaTask

  Revision_info="$Id: drmaa_minc2jiv.rb 96 2008-12-18 18:02:02Z prioux $"

  def setup
    params        = self.params
    dicom_ids     = params[:dicom_ids].split(",")  # array of IDs

    Dir.mkdir("dicom",0700)
    Dir.mkdir("results",0700)

    dicom_ids.each do |id|
      dicomfile  = Userfile.find(id)
      unless dicomfile
        self.addlog("Could not find active record entry for userfile #{id}")
        return false
      end
      vaultname = dicomfile.vaultname
      basename  = File.basename(dicomfile.name)
      File.symlink(vaultname,"dicom/#{basename}")
    end

    true
  end

  def drmaa_commands
    params       = self.params
    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "dcm2mnc dicom results",
    ]
  end

  def save_results
    params       = self.params
    user_id      = self.user_id

    io = IO.popen("find results -type f -name \"*.mnc\" -print")

    numfail = 0

    io.each_line do |file|
      next unless file.match(/\.mnc\s*$/)
      file = file.sub(/\n$/,"")
      basename = File.basename(file)
      mincfile = Userfile.new(
        :user_id   => user_id,
        :name      => basename,
        :content   => File.read(file)
      )
      if mincfile.save
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

