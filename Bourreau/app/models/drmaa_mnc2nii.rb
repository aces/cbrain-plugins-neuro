#
# CBRAIN Project
#
# DrmaaTask subclass
#
# Original author: Mathieu Desrosiers
#
# $Id: drmaa_dcm2mnc.rb 216 2009-05-22 20:34:44Z angela $
#

#save pour les fichiers de sortie autre que .nii 

class DrmaaMnc2nii < DrmaaTask

  Revision_info="$Id: drmaa_dcm2mnc.rb 216 2009-05-22 20:34:44Z angela $"

  def setup
    params      = self.params
    minc_colid = params[:mincfile_id]  # the ID of a FileCollection
    minc_col   = Userfile.find(minc_colid)
    
    unless minc_col
      self.addlog("Could not find active record entry for file #{minc_colid}")
      return false
    end


#    unless minc_col.class.to_s == "FileCollection"
#      self.addlog("Error: ActiveRecord entry #{minc_colid} is not a file collection.")
#      return false
#    end

    vaultname = minc_col.vaultname
    File.symlink(vaultname,"minc_col.mnc")
    pre_synchronize_userfile(minc_col)

    true
  end

  def drmaa_commands
    params       = self.params
    data_type = params[:data_type]

    if data_type = "default"
      data_type = ""
    else
      data_type = "-#{data_type}"
    end

    file_format = params[:file_format] 
    file_format = "-#{file_format}"

    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "mnc2nii #{data_type} #{file_format} minc_col.mnc"
    ]
  end
  
  def save_results
    params      = self.params
    minc_colid = params[:mincfile_id]
    minc_col   = Userfile.find(minc_colid)
        
    user_id     = self.user_id

    out_files = Dir.glob("*.{img,hdr,nii,nia}")
    out_files.each do |file|
      self.addlog(file)
      niifile = SingleFile.new(
        :user_id   => user_id,
        :name      => File.basename(minc_col.vaultname,".mnc")+File.extname(file),
        :content   => File.read(file),
	:task      => "Mnc2nii" )
      if niifile.save
        niifile.move_to_child_of(minc_col)
        post_synchronize_userfile(niifile)
        self.addlog("Saved new Nifti file ")
      else
        self.addlog("Could not save back result file .")
      end
    end
  end
end
