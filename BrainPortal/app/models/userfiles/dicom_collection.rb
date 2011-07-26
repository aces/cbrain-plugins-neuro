
#
# CBRAIN Project
#
# Dicom collection model
# Essentially a file collection of DICOM files
#
# $Id$
#

class DicomCollection < FileCollection

  Revision_info=CbrainFileRevision[__FILE__]

  def self.pretty_type
    "DICOM file collection"
  end
  
end
