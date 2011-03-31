
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
  Revision_info="$Id$"

  reset_viewers
  has_viewer :civet_collection
      
  def content(options) #:nodoc
    if options[:collection_file]
      path = self.cache_full_path.parent + options[:collection_file]
      {:sendfile => path}
    else
      super
    end
  end
  
  def qc_images
    self.list_files("verify").select { |f| f.name =~ /\.png$/ }
  end

end