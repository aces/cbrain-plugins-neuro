
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

class DataladDataProvider < SshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  DATALAD_PREFIX = "http://datasets.datalad.org"

  def self.pretty_category_name #:nodoc:
    "Datalad.ORG"
  end

  def is_browsable?(by_user = nil) #:nodoc:
    true
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def content_storage_shared_between_users? #:nodoc:
    true
  end

  # Returns true: local data providers are considered fast syncing.
  def is_fast_syncing?
    false
  end

  def provider_full_path(userfile) #:nodoc:
    datalad_relative_path(userfile) + userfile.name
  end

  def impl_is_alive? #:nodoc:
    true
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    src         = provider_full_path(userfile)
    dest        = cache_full_path(userfile)
    cache       = dest.parent
    url_src     = Pathname.new(DATALAD_PREFIX) + src

    datalad_command = "datalad install -g -s #{url_src.to_s.bash_escape}  #{dest.to_s.bash_escape}"
    system(datalad_command)
    Dir.chdir(dest.to_s) do
      system("git-annex uninit")
    end
  end

  def impl_provider_erase(userfile)  #:nodoc:
    cb_error 'Erase not allowed'
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    cb_error 'Rename not allowed'
  end

  private

  def datalad_relative_path(userfile)
    base   = self.remote_dir.presence
    prefix = (userfile.meta[:datalad_path_prefix] || {})[self.id]
    path   = base ? Pathname.new(base) : Pathname.new("")
    path  += prefix if prefix
  end

  DATALAD_CACHE_DIR="/tmp/datalog_org"
  Dir.mkdir(DATALAD_CACHE_DIR) rescue nil

  def impl_provider_list_all(user = nil) # user ignored

    dirname = self.remote_dir

    system("datalad install -r --recursion-limit 1 -s #{DATALAD_PREFIX}/#{dirname} #{DATALAD_CACHE_DIR}/#{dirname}")

    json_text = IO.popen("cd #{DATALAD_CACHE_DIR}/#{dirname};datalad ls --json display","r") { |fh| fh.read }
    entries = JSON.parse(json_text)

    nodes = entries["nodes"] || []

    list = nodes.map do |node|
      name = node['name']
      type = node['type']
      size = node['size']['total'] || "0"
      size.sub!(/\s*kb/,"000")
      size.sub!(/\s*mb/,"000000")
      size.sub!(/\s*gb/,"000000000")
      size.sub!(/\s*tb/,"000000000000")
      size = size.to_i
      datetime = DateTime.parse(node['date'])

      next if name == "." || name == ".." # robust
      fileinfo = FileInfo.new

      fileinfo.name          = name
      fileinfo.symbolic_type = ( type == 'file' ? :regular :
                                 type =~ /uninitialized|dataset|directory|folder/i ? :directory :
                                 :unknown
                               )
      fileinfo.size          = size
      fileinfo.atime = fileinfo.ctime = fileinfo.mtime = datetime

      fileinfo
    end.compact

    list.sort! { |a,b| a.name <=> b.name }
    list
  end

end

