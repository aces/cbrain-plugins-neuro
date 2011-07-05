
#
# CBRAIN Project
#
# DicomFile model
#
# $Id$
#

class DicomFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__]
  
  def self.file_name_pattern
    /\.(dcm|dicom)$/i
  end
  
end

