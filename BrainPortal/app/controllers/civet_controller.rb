
#
# CBRAIN Project
#
# Civet interface controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id: tasks_controller.rb 96 2008-12-18 18:02:02Z prioux $
#

class CivetController < ApplicationController

  Revision_info="$Id: tasks_controller.rb 96 2008-12-18 18:02:02Z prioux $"

  before_filter :login_required

  # GET  /civet/edit/id             # initially
  # POST /civet/edit                # all subsequent edit sessions
  def edit

    @civet_params = params[:civet_params]    # can be nil at first

    mincfile_id   = params[:id]  # provided first time we enter the edit page

    # This block of code is executed only once in an edit
    # session, when we first enter the page
    if mincfile_id
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
    end

    @civet_params ||= {
        :mincfile_id         => mincfile_id,
        :t2_id               => t2_id,
        :pd_id               => pd_id,
        :mk_id               => mk_id,

        :prefix              => prefix,      # -prefix
        :dsid                => dsid,        #

        :make_graph          => false,       # -make-graph for true
        :make_filename_graph => false,       # -make-filename-graph for true
        :print_status_report => false,       # -print-status-report for true

        :template            => '1.00',      # -template
        :model               => 'icbm152nl', # -model
        :multispectral       => false,       # -multispectral for true
        :correct_pve         => false,       # -[no-]correct-pve
        :spectral_mask       => false,       # -spectral-mask for true
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

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @civet_params }
    end

  end

  def create
    @civet_params = params[:civet_params]

    mincfile_id   = @civet_params[:mincfile_id]
    mincfile = Userfile.find(mincfile_id)

    #flash[:error] = "This is a fake error."
    #render :action => 'edit'

    mj = DrmaaCivet.new
    mj.user_id = current_user.id
    mj.params = @civet_params
    mj.save

    flash[:notice] ||= ""
    flash[:notice] += "Started Civet on file '#{mincfile.name}'.\n"
    redirect_to :controller => :tasks, :action => :index

  end
  
  def find_t2_pd_mask(t1name)
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
