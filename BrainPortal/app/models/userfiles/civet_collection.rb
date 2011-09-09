
#
# CBRAIN Project
#
# Civet collection model
# Essentially a file collection with some methods for handling civet output
#
# Original author: Tarek Sherif
#
# $Id$
#

#This class represents a FileCollection meant specifically to represent the output
#of a *civet* run (see CbrainTask::Civet). The instance methods are all meant to 
#provide simple access to the contents of particular directories in the
#directory tree produced by *civet*.
class CivetCollection < FileCollection
  Revision_info=CbrainFileRevision[__FILE__]

  reset_viewers
  has_viewer    :civet_collection
  has_viewer    :partial => "civet_collection/obj_viewer_launcher", :name => "brainbrowser",  :if  => Proc.new { |u| u.is_locally_synced? }
  
  def qc_images
    self.list_files("verify").select { |f| f.name =~ /\.png$/ }
  end

end
