
#
# CBRAIN Project
#
# MgzFile model
#
# Original author: Natacha Beck
#
# $Id$
#

class MgzFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__]
  
  def self.file_name_pattern #:nodoc:
    /\.mgz$/i
  end

  def self.pretty_type #:nodoc:
      "MGZ Structural File"
  end
  
end
