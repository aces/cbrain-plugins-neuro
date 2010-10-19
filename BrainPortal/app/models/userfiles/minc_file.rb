#
# CBRAIN Project
#
# MincFile model
#
# Original author: Tarek Sherif
#
# $Id$
#

class MincFile < SingleFile

  Revision_info="$Id$"
  
  has_viewer :partial  => "jiv_file", :if  => Proc.new{ |u| u.has_format?(:jiv) && u.get_format(:jiv).is_locally_synced? }
  
  def format_name
    "MINC"
  end
  
  def self.file_name_pattern
    /\.mi?nc(\.gz|\.Z|\.gz2)?$/i
  end
  
end
