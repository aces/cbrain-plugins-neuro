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
  
  has_viewer :name  => "Jiv Viewer", :partial  => "jiv_file", :if  => Proc.new{ |u| u.has_format?(:jiv) && u.get_format(:jiv).is_locally_synced? }
  
  def format_name
    "MINC"
  end
  
end
