
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
             Proc.new { |u| u.size.present? &&
                            u.size < 400.megabytes &&
                            u.is_locally_synced?
                      }

  has_viewer :name => "Info & Headers", :partial => :info_header,             :if =>
             Proc.new { |u| u.class.has_minctools?([2,0,0],["mincinfo","mincheader","mincdump","mincexpand"]) && u.is_locally_synced? }

  has_viewer :name => "MincNavigator",  :partial => :minc_navigator,          :if =>
             Proc.new { |u| u.size.present? &&
                            u.size < 400.megabytes &&
                            u.is_locally_synced?
                      }

  has_content :method => :minc_content,        :type => :text

  def self.file_name_pattern #:nodoc:
    /\.mi?nc(\.gz|\.Z|\.bz2)?$/i
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
    else
      false
    end
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

  # Returns the mincfile itself; uncompressed if it is compressed on the DP.
  def minc_content
    if self.name =~ /(\.mgz|\.gz|\.Z)$/i
      IO.popen("gunzip -c #{self.cache_full_path.to_s.bash_escape}") { |fh| fh.read }
    elsif self.name =~ /(\.bz2)$/i
      IO.popen("bunzip2 -c #{self.cache_full_path.to_s.bash_escape}") { |fh| fh.read }
    else
      File.open(self.cache_full_path, "r").read
    end
  end

end

