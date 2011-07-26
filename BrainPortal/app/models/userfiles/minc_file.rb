
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

  Revision_info=CbrainFileRevision[__FILE__]
  
  has_viewer :partial => "jiv_file",          :if  => Proc.new{ |u| u.has_format?(:jiv) && u.get_format(:jiv).is_locally_synced? }
  has_viewer :partial => "html5_minc_viewer", :if  => Proc.new{ |u| u.class.has_minctools? && u.is_locally_synced? && u.size < 30.megabytes }

  def format_name #:nodoc:
    "MINC"
  end
  
  def self.file_name_pattern #:nodoc:
    /\.mi?nc(\.gz|\.Z|\.gz2)?$/i
  end
  
  def content(params) #:nodoc:
    if params["minc_headers"]
      return { :text => minc_get_headers.to_json }
    elsif params["raw_data"]
      return { :text => minc_get_raw_data }
    end    
  end

  # Returns true only if the current system PATH environment
  # can invoke the minc tools 'mincinfo' and 'minctoraw'.
  def self.has_minctools?
    return @_minctools_installed == :yes unless @_minctools_installed.blank?
    if system("bash","-c","which mincinfo >/dev/null 2>&1") &&
       system("bash","-c","which minctoraw >/dev/null 2>&1")
      @_minctools_installed = :yes
      return true
    else
      @_minctools_installed = :no
      return false
    end
  end

  def to_s #:nodoc:
    "Dimensions: \nxspace: #{@xspace[length]}\nyspace: #{@yspace[length]}\nzspace: #{@zspace[length]}\n"
  end

  def minc_get_headers #:nodoc:

    return @headers if @headers
    cb_error "Call to minc_get_headers() when minctools not installed!" unless self.class.has_minctools?
 
    cache_path   = self.cache_full_path
    escaped_path = shell_escape(cache_path)

    order = IO.popen("mincinfo -attval image:dimorder #{escaped_path}") {|fh| fh.readlines.join.strip.split(',')}        
    if !(order.size == 3 or order.size == 4)
      order = IO.popen("mincinfo -dimnames #{escaped_path}") {|fh| fh.readlines.join.strip.split(' ')}        
    end
    
    #Gets the attributes in the minc file that we need
    @headers = {
      :xspace => {
        :start        => IO.popen("mincinfo -attval    xspace:start #{escaped_path}") { |fh| fh.readlines.join.to_f },
        :space_length => IO.popen("mincinfo -dimlength xspace       #{escaped_path}") { |fh| fh.readlines.join.to_i },
        :step         => IO.popen("mincinfo -attval    xspace:step  #{escaped_path}") { |fh| fh.readlines.join.to_f }
      },
      :yspace => {
        :start        => IO.popen("mincinfo -attval    yspace:start #{escaped_path}") { |fh| fh.readlines.join.to_f },
        :space_length => IO.popen("mincinfo -dimlength yspace       #{escaped_path}") { |fh| fh.readlines.join.to_i },
        :step         => IO.popen("mincinfo -attval    yspace:step  #{escaped_path}") { |fh| fh.readlines.join.to_f }
      },
      :zspace => {
        :start        => IO.popen("mincinfo -attval    zspace:start #{escaped_path}") { |fh| fh.readlines.join.to_f },
        :space_length => IO.popen("mincinfo -dimlength zspace       #{escaped_path}") { |fh| fh.readlines.join.to_i },
        :step         => IO.popen("mincinfo -attval    zspace:step  #{escaped_path}") { |fh| fh.readlines.join.to_f }
      },

      :order => order
    }
    
    if order.length == 4 
      @headers[:time] = { 
        :start        => IO.popen("mincinfo -attval    time:start   #{escaped_path}") { |fh| fh.readlines.join.to_f },
        :space_length => IO.popen("mincinfo -dimlength time         #{escaped_path}") { |fh| fh.readlines.join.to_i }
      }
    end
    
    @headers
  end
  
  # The raw binary data, in short integers
  def minc_get_raw_data #:nodoc:
    cb_error "Call to raw_data() when minctools not installed!" unless self.class.has_minctools?
    return @raw_data if @raw_data
    cache_path   = self.cache_full_path
    escaped_path = shell_escape(cache_path)
    @raw_data = IO.popen("minctoraw -byte -unsigned -normalize #{escaped_path}") { |fh| fh.readlines.join }
  end

  def minc_get_data #:nodoc:
    @data ||= self.raw_data.unpack('v*') #Unpack is used here to convert 4 byte(char) to a short unsigned integer
  end
  
  def minc_get_data_string #:nodoc:
    @data_string ||= self.data.join(" ") #making a space delimited array of the data (useful to send to server)
  end

  private

  # This utility method escapes properly any string such that
  # it becomes a literal in a bash command; the string returned
  # will include the surrounding single quotes.
  #
  #   shell_escape("Mike O'Connor")
  #
  # returns
  #
  #   'Mike O'\''Connor'
  def shell_escape(s)
    "'" + s.to_s.gsub(/'/,"'\\\\''") + "'"
  end
  
end
 
