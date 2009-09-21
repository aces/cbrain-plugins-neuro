
#A subclass of DrmaaTask to launch civet.
class DrmaaCivet < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def self.has_args?
    true
  end
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil)
    file_ids         = params[:file_ids]

    user_id          = params[:user_id]
    bourreau_id      = params[:bourreau_id]
    data_provider_id = params[:data_provider_id]

    raise "Error: CIVET can only be launched on one FileCollection." if
      file_ids.size != 1

    collection_id = file_ids[0]
    collection    = Userfile.find(collection_id)
    collection.sync_to_cache  # TODO costly!

    # Get the list of all files inside the collection; we only
    # look one level deep inside the directory.
    files_inside  = collection.list_files.select { |f| f !~ /\/\.*\// }
    files_inside  = files_inside.map { |f| f.sub(/^.*\//,"") }

    # Parse the list of all files and extract the MINC files.
    # We ignore everything else.
    minc_files = []
    files_inside.each do |basename|
      minc_files << basename if basename.match(/\.mnc(\.gz|\.Z)?$/i)
    end

    raise "There are no MINC files in this FileCollection!" unless minc_files.size > 0

    # From the list of minc files, try to identify files
    # that are clearly 't1' files, based on the filename.
    t1_files = []
    minc_files.each do |minc|
      t1_files << minc if minc.match(/_t1\b/i)
    end

    # If we have any, we remove them from the total list of minc files.
    minc_files = minc_files - t1_files

    # Prepare the structure for all the CIVET operation;
    # each CIVET has a mandatory t1, and optional t2, pd and mk.
    minc_groups = []  #  [ t1, t2, pd, mk ]

    # For properly named t1 files, try to also find
    # the optional t2, pd and masks files; if they are
    # found they are extracted from the list of minc files
    t1_files.each do |t1|
      (t2,pd,mk,minc_files) = extract_t2_pd_mask(t1,minc_files) # modifies array minc_files
      minc_groups << [ t1, t2, pd, mk ]
    end

    # For all remaining minc files, we assume they are t1s
    # and we process them without any t2, pd and mk.
    minc_files.each do |minc|
      next if minc.match(/_(t2|pd|mask)\b/i)  # ignore spurious t2s, pds, and masks
      minc_groups << [ minc, nil, nil, nil ]
    end
   
    # OK, build a arg structure for each minc group
    file_args = []
    minc_groups.each do |group|

      t1_name = group[0]
      t2_name = group[1]
      pd_name = group[2]
      mk_name = group[3]

      if t1_name.match(/(\w+)_(\w+)_t1\b/i)
        prefix = Regexp.last_match[1]
        dsid   = Regexp.last_match[2]
      else
        prefix = "prefix"
        dsid   = "dsid"
      end

      file_args << {
        :t1_name             => t1_name,
        :t2_name             => t2_name,
        :pd_name             => pd_name,
        :mk_name             => mk_name,

        :prefix              => prefix,      # -prefix
        :dsid                => dsid,        #
        
        :multispectral       => false,       # -multispectral for true
        :spectral_mask       => false,       # -spectral-mask for true
      }

    end

    civet_args = saved_args || {
          :make_graph          => false,       # -make-graph for true
          :make_filename_graph => false,       # -make-filename-graph for true
          :print_status_report => false,       # -print-status-report for true

          :template            => '1.00',      # -template
          :model               => 'icbm152nl', # -model
        
          :correct_pve         => false,       # -[no-]correct-pve
        
          :interp              => 'trilinear', # -interp
          :N3_distance         => 200,         # -N3-distance
          :lsq                 => '9',         # -lsq6, -lsq9, -lsq12
          :no_surfaces         => false,       # -no-surfaces
          :thickness_method    => 'tlink',     # -thickness method kernel
          :thickness_kernel    => 20,          #             "
          :resample_surfaces   => false,       # -[no-]resample-surfaces
          :combine_surfaces    => false,       # -[no-]combine-surfaces

          # Not yet implemented in interface
          :VBM                 => false,       # -[no-]VBM
          :VBM_fwhm            => 8,           # -VBM-fwhm
          :VBM_symmetry        => false,       # -[no-]VBM-symmetry
          :VBM_cerebellum      => true,        # -[no-]VBM-cerebellum

          # Not yet implemented in interface
          :animal              => false,       # -[no-]animal
          :atlas               => 'lobe'       # -symmetric-atlas or -lobe-atlas
          # TODO animal-atlas-dir

      }

    {  :file_args        => file_args,
       :civet_args       => civet_args,

       :collection_id    => collection_id,
       :data_provider_id => data_provider_id,
       :bourreau_id      => bourreau_id,
    }
  end
  
  #See DrmaaTask.
  def self.launch(params)
    civet_args = params[:civet_args]
    file_args  = params[:file_args]

    flash = ""

    if file_args.size > 3
      self.spawn do
        file_args.each do |file|
          self.launch_one(params,file,civet_args)
        end
      end
      flash += "Started CIVET on #{file_args.size} files.\n"  
    else
      file_args.each do |file|
        self.launch_one(params,file,civet_args)
        flash += "Started CIVET on file '#{file[:t1_name]}'.\n"  
      end
    end
    
    flash
  end

  def self.launch_one(params,one_file_args,civet_args)
    user_id          = params[:user_id]
    collection_id    = params[:collection_id]
    bourreau_id      = params[:bourreau_id]
    data_provider_id = params[:data_provider_id]

    collection      = FileCollection.find(collection_id)
    t1_name         = one_file_args[:t1_name]

    extended_args = civet_args.dup
    extended_args[:data_provider_id] = data_provider_id
    extended_args[:collection_id]    = collection_id

    # Create the object, send it to Bourreau
    civ = DrmaaCivet.new  # a blank ActiveResource object
    civ.user_id      = user_id
    civ.bourreau_id  = bourreau_id unless bourreau_id.blank?
    civ.params  = extended_args.merge(one_file_args)
    civ.save

    collection.addlog_context(self,"Sent '#{t1_name}' to CIVET, task #{civ.bname_tid}")
  end
  
  #See DrmaaTask.
  def self.save_options(params)
    params[:civet_args]
  end
  
  # TODO need ability to find these files even when they don't
  # belong to the user but are still 'accessible' by the user's groups
  #
  # DISABLED: NOT USED ANYMORE
  def self.disabled_find_t2_pd_mask(t1name,user_id) #:nodoc:
      if ! t1name.match(/_t1/)
          return [nil,nil,nil]
      end
      t2 = Userfile.find(:first, :conditions => { :name => t1name.sub(/_t1/,"_t2"), :user_id => user_id } )
      t2_id = t2 ? t2.id : nil

      pd = Userfile.find(:first, :conditions => { :name => t1name.sub(/_t1/,"_pd"), :user_id => user_id } )
      pd_id = pd ? pd.id : nil

      mk = Userfile.find(:first, :conditions => { :name => t1name.sub(/_t1/,"_mask"), :user_id => user_id } )
      mk_id = mk ? mk.id : nil

      [t2_id,pd_id,mk_id]
  end

  private

  # Run the associated block as a background process to avoid
  # blocking.
  #
  # Most of the code in this method comes from a blog entry
  # by {Scott Persinger}[http://geekblog.vodpod.com/?p=26].
  def self.spawn #:nodoc:
    dbconfig = ActiveRecord::Base.remove_connection
    pid = Kernel.fork do
      begin
        # Monkey-patch Mongrel to not remove its pid file in the child
        require 'mongrel'
        Mongrel::Configurator.class_eval("def remove_pid_file; puts 'child no-op'; end")
        ActiveRecord::Base.establish_connection(dbconfig)
        yield
      ensure
        ActiveRecord::Base.remove_connection
      end
      Kernel.exit!
    end
    Process.detach(pid)
    ActiveRecord::Base.establish_connection(dbconfig)
  end

  def self.extract_t2_pd_mask(t1,minclist)  #:nodoc:
    t2_name = nil
    pd_name = nil
    mk_name = nil

    expect = t1.sub("_t1","_t2")
    t2_name = expect if minclist.include?(expect)
      
    expect = t1.sub("_t1","_pd")
    pd_name = expect if minclist.include?(expect)
      
    expect = t1.sub("_t1","_mask")
    mk_name = expect if minclist.include?(expect)
      
    minclist = minclist - [ t2_name, pd_name, mk_name ]

    [ t2_name, pd_name, mk_name, minclist ]
  end

end

