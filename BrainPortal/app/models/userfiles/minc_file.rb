#
# CBRAIN Project
#
# MincFile model
#
# Original author: Tarek Sherif
#
# $Id$
#

require 'minc'

class MincFile < SingleFile

  Revision_info="$Id$"
  
  has_viewer :partial  => "jiv_file", :if  => Proc.new{ |u| u.has_format?(:jiv) && u.get_format(:jiv).is_locally_synced? }
  
  has_viewer :partial => "html5_minc_viewer", :if  => Proc.new{ |u| u.is_locally_synced? && u.size < 30.megabytes}

  def format_name
    "MINC"
  end
  
  def self.file_name_pattern
    /\.mi?nc(\.gz|\.Z|\.gz2)?$/
  end
  
  def content(params) 
    minc = Minc.new(self.cache_full_path)
    if params["minc_headers"]
      return {:text => minc.headers.to_json}
    elsif params["raw_data"]
      return {:text => minc.raw_data}
    end    
  end

end
 
