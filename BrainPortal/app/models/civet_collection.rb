
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

class CivetCollection < FileCollection
  Revision_info="$Id$"
  
  def list_native
    @native_list ||= self.get_list('native')
  end
  
  def list_classify
    @classify_list ||= self.get_list('classify')
  end
  
  def list_final
    @final_list ||= self.get_list('final')
  end
  
  def list_logs
    @logs_list ||= self.get_list('logs')
  end
  
  def list_surfaces
    @surfaces_list ||= self.get_list('surfaces')
  end
  
  def list_temp
    @temp_list ||= self.get_list('temp')
  end
  
  def list_thickness
    @thickness_list ||= self.get_list('thickness')
  end
  
  def list_linear_transforms
    @linear_list ||= self.get_list('transforms/linear')
  end
  
  def list_non_linear_transforms
    @non_linear_list ||= self.get_list('transforms/nonlinear')
  end
  
  def list_surfreg_transforms
    @surfreg_list ||= self.get_list('transforms/surfreg')
  end
  
  def list_verify
    @verify_list ||= self.get_list('verify')
  end
  
  
  def get_list(directory)
    Dir.chdir(self.cache_full_path) do
      `find #{directory} -type f`.split("\n").map{ |name| name.sub(/^#{directory}\//, "") }
    end
  end

end
