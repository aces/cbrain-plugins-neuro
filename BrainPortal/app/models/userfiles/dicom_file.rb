
#
# CBRAIN Project
#
# DicomFile model
#
# $Id$
#

class DicomFile < SingleFile

  Revision_info="$Id$"
  
  def self.file_name_pattern
    /\.(dcm|dicom)$/i
  end
  
end

