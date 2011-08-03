
#
# CBRAIN Project
#
# MINC collection model
# Essentially a file collection of MINC files
#

class MincCollection < FileCollection

  Revision_info=CbrainFileRevision[__FILE__]

  def self.pretty_type
    "MINC file collection"
  end
  
end
