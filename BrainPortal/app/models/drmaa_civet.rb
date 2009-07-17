
#A subclass of DrmaaTask to launch civet.
class DrmaaCivet < DrmaaTask

  Revision_info="$Id$"

  #See DrmaaTask.
  def self.has_args?
    true
  end
  
  #See DrmaaTask.
  def self.get_default_args(params = {}, saved_args = nil)
    file_ids = params[:file_ids]
    file_args = []
    civet_args = nil
    
    file_ids.each do |mincfile_id|
      # This block of code is executed only once in an edit
      # session, when we first enter the page
        mincfile      = Userfile.find(mincfile_id)
        basename      = mincfile.name
        if basename.match(/([^\/]+)_(\w+)_t1(_\w+)?\.mnc(\.gz|.Z)?$/)
          prefix = Regexp.last_match[1]
          dsid   = Regexp.last_match[2]
        else
          prefix = "prefix"
          dsid   = "dsid"
        end

        # These three Userfile IDs are for (the optional) t2, pd and mask files
        # associated with the main t1 file.
        (t2_id,pd_id,mk_id) = find_t2_pd_mask(basename)
    
      file_args << {
        :mincfile_id         => mincfile_id,
        :t2_id               => t2_id,
        :pd_id               => pd_id,
        :mk_id               => mk_id,

        :prefix              => prefix,      # -prefix
        :dsid                => dsid,        #
        
        :multispectral       => false,       # -multispectral for true
        :spectral_mask       => false,       # -spectral-mask for true
      }  
    end
        
    if saved_args
      civet_args = saved_args
    else
      civet_args = {
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
    end
    
    
    {:file_args  => file_args, :civet_args  => civet_args}
  end
  
  #See DrmaaTask.
  def self.launch(params)
    civet_args = params[:civet_args]
    file_args = params[:file_args]
    flash = ""
    
    file_args.each do |file|
      mincfile_id   = file[:mincfile_id]
      mincfile = Userfile.find(mincfile_id, :include  => :user)

      #flash[:error] = "This is a fake error."
      #render :action => 'edit'
  
      mj = DrmaaCivet.new
      mj.user_id = mincfile.user.id
      mj.params = civet_args.merge(file)
      mj.save

      flash += "Started Civet on file '#{mincfile.name}'.\n"  
    end
    
    flash
  end
  
  #See DrmaaTask.
  def self.save_options(params)
    params[:civet_args]
  end
  
  def self.find_t2_pd_mask(t1name) #:nodoc:
      if ! t1name.match(/_t1/)
          return [nil,nil,nil]
      end
      t2 = Userfile.find_by_name(t1name.sub(/_t1/,"_t2"))
      t2_id = t2 ? t2.id : nil

      pd = Userfile.find_by_name(t1name.sub(/_t1/,"_pd"))
      pd_id = pd ? pd.id : nil

      mk = Userfile.find_by_name(t1name.sub(/_t1/,"_mask"))
      mk_id = mk ? mk.id : nil

      [t2_id,pd_id,mk_id]
  end
end

