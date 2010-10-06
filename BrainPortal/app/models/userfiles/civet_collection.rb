
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
  
  has_viewer :civet_collection
      
  def content(options) #:nodoc
    if options[:collection_file]
      path = self.cache_full_path.parent + options[:collection_file]
      {:sendfile => path}
    else
      super
    end
  end

  #List files in the +native+ subdirectory.
  def list_native
    @native_list ||= get_full_subdir_listing('native')
  end
  
  #List files in the +classify+ subdirectory.
  def list_classify
    @classify_list ||= get_full_subdir_listing('classify')
  end
  
  #List files in the +final+ subdirectory.
  def list_final
    @final_list ||= get_full_subdir_listing('final')
  end
  
  #List files in the +logs+ subdirectory.
  def list_logs
    @logs_list ||= get_full_subdir_listing('logs')
  end
  
  #List files in the +surfaces+ subdirectory.
  def list_surfaces
    @surfaces_list ||= get_full_subdir_listing('surfaces')
  end
  
  #List files in the +temp+ subdirectory.
  def list_temp
    @temp_list ||= get_full_subdir_listing('temp')
  end
  
  #List files in the +thickness+ subdirectory.
  def list_thickness
    @thickness_list ||= get_full_subdir_listing('thickness')
  end
  
  #List files in the +transforms+/+linear+ subdirectory.
  def list_linear_transforms
    @linear_list ||= get_full_subdir_listing('transforms/linear')
  end
  
  #List files in the +transforms+/+nonlinear+ subdirectory.
  def list_non_linear_transforms
    @non_linear_list ||= get_full_subdir_listing('transforms/nonlinear')
  end
  
  #List files in the +transforms+/+surfreg+ subdirectory.
  def list_surfreg_transforms
    @surfreg_list ||= get_full_subdir_listing('transforms/surfreg')
  end
  
  #List files in the +verify+ subdirectory.
  def list_verify
    @verify_list ||= get_full_subdir_listing('verify')
  end
  
  # Returns a simple keyword identifying the type of
  # the userfile; used mostly by the index view.
  def pretty_type
    "(Civet)"
  end

end
