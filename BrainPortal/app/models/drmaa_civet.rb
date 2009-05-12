
#
# CBRAIN Project
#
# DrmaaTask models as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

class DrmaaCivet < DrmaaTask

  Revision_info="$Id$"

  def self.has_params?
    true
  end
  
  def self.get_default_params(params = {})
    file_ids = params[:ids]
    file_params = []
    civet_params = nil
    
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
    
      file_params << {
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
    
    civet_params = {
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
    
    {:file_params  => file_params, :civet_params  => civet_params}
  end
  
  def self.launch(params)
    civet_params = params[:civet_params]
    file_params = params[:file_params]
    flash = ""
    
    file_params.each do |file|
      mincfile_id   = file[:mincfile_id]
      mincfile = Userfile.find(mincfile_id)

      #flash[:error] = "This is a fake error."
      #render :action => 'edit'

      mj = DrmaaCivet.new
      mj.user_id = current_user.id
      mj.params = civet_params.merge(file)
      mj.save

      flash += "Started Civet on file '#{mincfile.name}'.\n"  
    end
    
    flash
  end
  
  def self.find_t2_pd_mask(t1name)
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

