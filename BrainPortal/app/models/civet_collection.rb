
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
#of a *civet* run (see DrmaaCivet). The instance methods are all meant to 
#provide simple access to the contents of particular directories in the
#directory tree produce by *civet*.
class CivetCollection < FileCollection
  Revision_info="$Id$"
  
  #List files in the +native+ subdirectory.
  def list_native
    @native_list ||= get_list('native')
  end
  
  #List files in the +classify+ subdirectory.
  def list_classify
    @classify_list ||= get_list('classify')
  end
  
  #List files in the +final+ subdirectory.
  def list_final
    @final_list ||= get_list('final')
  end
  
  #List files in the +logs+ subdirectory.
  def list_logs
    @logs_list ||= get_list('logs')
  end
  
  #List files in the +surfaces+ subdirectory.
  def list_surfaces
    @surfaces_list ||= get_list('surfaces')
  end
  
  #List files in the +temp+ subdirectory.
  def list_temp
    @temp_list ||= get_list('temp')
  end
  
  #List files in the +thickness+ subdirectory.
  def list_thickness
    @thickness_list ||= get_list('thickness')
  end
  
  #List files in the +transforms+/+linear+ subdirectory.
  def list_linear_transforms
    @linear_list ||= get_list('transforms/linear')
  end
  
  #List files in the +transforms+/+nonlinear+ subdirectory.
  def list_non_linear_transforms
    @non_linear_list ||= get_list('transforms/nonlinear')
  end
  
  #List files in the +transforms+/+surfreg+ subdirectory.
  def list_surfreg_transforms
    @surfreg_list ||= get_list('transforms/surfreg')
  end
  
  #List files in the +verify+ subdirectory.
  def list_verify
    @verify_list ||= get_list('verify')
  end
  

  private

  def get_list(directory)  #:nodoc:
    Dir.chdir(self.cache_full_path) do
      `find #{directory} -type f`.split("\n").map{ |name| name.sub(/^#{directory}\//, "") }
    end
  end

end
