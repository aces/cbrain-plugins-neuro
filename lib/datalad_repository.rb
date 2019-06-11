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

# Implements a DataProvider that can get files from a Datalad Repository
#
# To explore a Datalad Repository, a separate cached version of the repo
# with the git annex links is to be maintained separately so that we can
# explore it to find the file metadate.
#
# This library will create that cache and use it separately to maintain
# the file metadata and initiate any datalad or git annex calls that are
# needed to facilitate the data provider capability

require 'fileutils'

class DataladRepository

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Establish a connection and install the initial image of the datalad repo in a
  # Temporary cache directory
  def initialize(datalad_repository_url, datalad_relative_path, dp_id, cr_id)
    @base_url     = datalad_repository_url
    @url_rel_path = datalad_relative_path
    @dp_id        = dp_id
    @cr_id        = cr_id
    self
  end

  def connected?
    cmd_string = "curl --head -f --connect-timeout 20 #{@base_url.bash_escape} > /dev/null 2> /dev/null"
    system(cmd_string)
  rescue
    false
  end



  ####################################################################
  # Browsing Support
  ####################################################################

  def url_for_browsing
    File.join(@base_url, @url_rel_path)
  end

  def name_of_cache_for_browsing
    "Datalad.rr=#{@cr_id}.dp=#{@dp_id}"
  end

  def install_subset_for_browsing
    cache_browsing = DataladSystemSubset.find_or_create_as_scratch(
      :name => name_of_cache_for_browsing()
    ) do |cache_dir|
      retcode = run_datalad_commands(cache_dir,
        "datalad install -s #{url_for_browsing} BrowseTop || exit 41"
      )
      cb_error "Could not run datalad install for browsing."                    if retcode == 41
      cb_error "Error occured when running datalad script: retcode=#{retcode}"  if retcode > 0
    end
    # We need to return on more level of directory after install.
    cache_browsing.cache_full_path.join('BrowseTop')
  end



  ####################################################################
  # Provider-side support for examining remote userfile
  ####################################################################

  def url_for_userfile(userfile)
    File.join(url_for_browsing,userfile.name)
  end

  def name_of_cache_for_userfile(userfile)
    name_of_cache_for_browsing() + ".f=#{userfile.id}"
  end

  def install_subset_for_userfile(userfile)
    url = url_for_userfile(userfile)
    cache_userfile = DataladSystemSubset.find_or_create_as_scratch(
      :name => name_of_cache_for_userfile(userfile)
    ) do |cache_dir|
      retcode = run_datalad_commands(cache_dir,
        "datalad install -r -s #{url.bash_escape} #{userfile.name.bash_escape} || exit 41"
      )
      cb_error "Could not run datalad install for subset userfile ##{userfile.id}." if retcode == 41
      cb_error "Error occured when running datalad script: retcode=#{retcode}"      if retcode > 0
    end
    # We need to return on more level of directory after install.
    File.join(cache_userfile.cache_full_path,userfile.name)
  end



  ####################################################################
  # Provider-side support for fully downloading a userfile
  ####################################################################

  def download_userfile_to_cache(userfile)
    userfile.cache_prepare
    cache_loc = userfile.cache_full_path
    parent    = cache_loc.parent.to_s
    url       = url_for_userfile(userfile)
    retcode = run_datalad_commands(parent, "
      datalad install -r -g -s #{url.bash_escape} #{userfile.name.bash_escape} || exit 41
      cd #{userfile.name.bash_escape}                                          || exit 42
      git annex uninit                                                         || exit 51
      rm -rf .git .datalad
      true
      "
    )
    cb_error "Could not run datalad install for caching userfile ##{userfile.id}." if retcode == 41
    cb_error "Could not chdir to #{cache_loc}"                                     if retcode == 42
    cb_error "git annex uninit failed in #{cache_loc}"                             if retcode == 51
    cb_error "Error occured when running datalad script: retcode=#{retcode}"       if retcode > 0
    cb_error "Could not download data for userfile" unless Dir.exist?(cache_loc.to_s)
    true
  end



  ####################################################################
  # Listing files
  ####################################################################

  # This method scans a local dirctory containing a datalad subset
  # and returns small objects for each entries in it, with
  # three components: :name, :size_in_bytes, and :type .
  # Since a datalad subset is a git annex structure it will
  # query information using git-annex when a symlink is found
  # and then pretend that it is a normal file.
  def self.list_contents_from_dataset(path,recursive=false)
    dllist = []

    glob_string = recursive ? "#{path}/**/*": "#{path}/*"

    Dir.glob(glob_string) do |fname|
      bname = File.basename(fname)
      dname = File.dirname(fname)
      name  = fname.sub("#{path}/","")

      next if name == "." || name == ".." || name == ".datalad" || name =~ /^\.git/

      # get metadata that you can only get from git-annex
      stat = File.lstat(fname)
      type = stat.symlink? ? :symlink : stat.ftype.to_sym rescue nil
      size = 0
      size = stat.size.to_i if type.to_sym == :file

      if type == :symlink
        ## This seems the most stable wy to get this stuff, go to the directory and git annex info it there
        git_annex_json_text = IO.popen("cd #{dname.bash_escape}; git annex info #{bname.bash_escape} --fast --json --bytes") { |fh| fh.read }
        git_annex_json = JSON.parse(git_annex_json_text) rescue {}
        type = :gitannexlink               if git_annex_json.has_key?("key")
        size = git_annex_json['size'].to_i if git_annex_json.has_key?("size")
      end

      dllist << {:name => name, :size_in_bytes => size,:type => type}
    end

    dllist
  end



  ####################################################################
  # Internal methods
  ####################################################################

  private

  # Runs one or more bash +commands+ from within the directory +indir+.
  # The directory will be created as needed. The commands are
  # likely going to invoke the "datalad" command, which can sometimes
  # be implemented as a singularity container, so we make sure to
  # set up the proper environment to maximize the chances of this working.
  #
  # We have to make sure that:
  # 1) the pwd is set to the parent of where the datalad command will create files
  # 2) we provide a FULL path for the destination too (this must be true in +commands+ too)
  # 3) we HOPE the singularity setup has 'overlay' support to mount the
  #    pwd too using the SINGULARITY_BINDPATH environment variable.
  #
  # This may seem excessive but datalad in singularity is very brittle.
  def run_datalad_commands(indir, commands)
    indir = Pathname.new(indir).realdirpath.to_s # make full; last component may not exist
    retcode = with_modified_env('SINGULARITY_BINDPATH' => indir) do
      system("
              mkdir -p #{indir.bash_escape} || exit 31
              cd       #{indir.bash_escape} || exit 32
              #{commands}
             ")
      $?.exitstatus
    end
    cb_error "Could not mkdir '#{indir}'" if retcode == 31
    cb_error "Could not chdir '#{indir}'" if retcode == 32
    retcode
  end


end



