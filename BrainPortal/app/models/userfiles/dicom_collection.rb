
#
# CBRAIN Project
#
# Dicom collection model
# Essentially a file collection of DICOM files
#
# $Id$
#

class DicomCollection < FileCollection

  Revision_info="$Id$"

  def self.pretty_type
    "DICOM file collection"
  end
  
end
