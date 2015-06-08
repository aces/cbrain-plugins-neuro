
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Model for a MINC file (either MINC1 or MINC2).
class MincFile < SingleFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  has_viewer :name => "Volume Viewer",  :partial => :volume_viewer,           :if =>
             Proc.new { |u| u.class.has_minctools?([2,0,0]) && u.is_locally_synced? && u.size.present? && u.size < 80.megabytes }

  has_viewer :name => "Info & Headers", :partial => :info_header,             :if =>
             Proc.new { |u| u.class.has_minctools?([2,0,0],["mincinfo","mincheader","mincdump","mincexpand"]) && u.is_locally_synced? }

  has_content :method => :get_headers_to_json, :type => :text
  has_content :method => :get_raw_data,        :type => :text

  def self.file_name_pattern #:nodoc:
    /\.mi?nc(\.gz|\.Z|\.gz2)?$/i
  end

  # Returns true only if the current system PATH environment
  # can invoke tools (default: 'mincinfo' and 'minctoraw').
  def self.has_minctools?(min_version, which_tools=["mincinfo", "minctoraw"])
    if which_tools.all? { |tool| system("bash","-c","which #{tool.to_s.bash_escape} >/dev/null 2>&1") }
      IO.popen("mincinfo -version | grep \"program\" | cut -d \":\" -f 2") do |fh|
        version = fh.readlines.join.strip.split(".").map {|num| num.to_i}
        if (min_version[0] <= (version[0] || 0) && min_version[1] <= (version[1] || 0)  && min_version[2] <= (version[2] || 0))
          return true
        else
          return false
        end
      end
    end
  end

  def minc_get_headers #:nodoc:

    return @headers if @headers
    cb_error "Call to minc_get_headers() when minctools not installed!" unless self.class.has_minctools? [2,0,0]

    cache_path   = self.cache_full_path
    escaped_path = cache_path.to_s.bash_escape

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

  #For content
  def get_headers_to_json
    minc_get_headers.to_json
  end

  # The raw binary data, in short integers
  def get_raw_data #:nodoc:
    cb_error "Call to raw_data() when minctools not installed!" unless self.class.has_minctools? [2,0,0]
    return @raw_data if @raw_data
    cache_path   = self.cache_full_path
    escaped_path = cache_path.to_s.bash_escape
    @raw_data = IO.popen("minctoraw -byte -unsigned -normalize #{escaped_path}") { |fh| fh.readlines.join }
  end

  def minc_get_data #:nodoc:
    @data ||= self.raw_data.unpack('v*') #Unpack is used here to convert 4 byte(char) to a short unsigned integer
  end

  def minc_get_data_string #:nodoc:
    @data_string ||= self.data.join(" ") #making a space delimited array of the data (useful to send to server)
  end

  #This method return the version of MINC file ('MINC1' or 'MINC2').
  #To do this, they invoke the command file, which is why it is necessary
  #that the file is synchronized when this method is called.
  #If it can't determine the type, it returns 'UNKNOWN'.
  def which_minc_version
    type = :unknown
    return type unless File.exist?(self.cache_full_path)
    IO.popen("file #{self.cache_full_path.to_s.bash_escape}") do |fh|
      first_line = fh.readline
      if first_line =~ /NetCDF/i
        type =  :minc1
      elsif first_line =~ /Hierarchical/i
        type = :minc2
      end
    end
    return type
  rescue
    :unknown
  end

end

