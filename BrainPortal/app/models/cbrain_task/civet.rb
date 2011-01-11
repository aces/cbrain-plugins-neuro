
#A subclass of PortalTask to launch civet.
class CbrainTask::Civet < PortalTask

  Revision_info="$Id$"

  StagesNames = %w(
    nuc_t1_native
    skull_masking_native
    stx_register
    stx_tal_to_7
    stx_tal_to_6
    tal_t1
    nuc_inorm_t1
    skull_removal
    nlfit
    mask_classify
    pve_curvature
    pve
    reclassify
    cls_volumes
    cortical_masking
    surface_classify
    artefact
    create_wm_hemispheres
    extract_white_surface_left
    extract_white_surface_right
    flip_right_hemi_obj_back
    slide_left_hemi_obj_back
    slide_right_hemi_obj_back
    calibrate_left_white
    calibrate_right_white
    laplace_field
    gray_surface_left
    gray_surface_right
    mid_surface_left
    mid_surface_right
    gyrification_index_left_gray
    dataterm_left_surface
    dataterm_right_surface
    gyrification_index_right_gray
    cerebral_volume
    surface_fit_error
    gyrification_index_left_white
    surface_registration_left
    verify_image_nlfit
    surface_registration_right
    verify_brain_mask
    classify_qc
    gyrification_index_right_white
    brain_mask_qc
    gyrification_index_left_mid
    thickness_tlink_20mm_right
    thickness_tlink_20mm_left
    gyrification_index_right_mid
    verify_image
    resample_right_thickness
    resample_left_thickness
    lobe_thickness_right
    lobe_thickness_left
    verify_clasp
  )

  # Returns the scientific parameters common to all the CIVET
  # jobs we're about to launch
  def self.default_launch_args #:nodoc:
    {
      :file_args           => {},

      :reset_from          => "",          # -reset-from

      :template            => '1.00',      # -template
      :model               => 'icbm152nl', # -model
        
      :interp              => 'trilinear', # -interp
      :N3_distance         => 200,         # -N3-distance
      :lsq                 => '9',         # -lsq6, -lsq9, -lsq12
      :no_surfaces         => false,       # -no-surfaces
      :thickness_method    => 'tlink',     # -thickness method kernel
      :thickness_kernel    => 20,          #             "
      :resample_surfaces   => false,       # -[no-]resample-surfaces
      :combine_surfaces    => false,       # -[no-]combine-surfaces

      # VBM options
      :VBM                 => false,       # -[no-]VBM
      :VBM_fwhm            => '8',         # -VBM-fwhm
      :VBM_symmetry        => false,       # -[no-]VBM-symmetry
      :VBM_cerebellum      => true,        # -[no-]VBM-cerebellum

    }
  end

  def before_form #:nodoc:
    params           = self.params

    # If we're editing a task already existing, nothing to do.
    if ! self.new_record?
      adjust_old_civet_structure # for back compatibility
      return ""
    end

    file_ids         = params[:interface_userfile_ids]

    userfiles = []
    file_ids.each do |id|
      userfiles << Userfile.find(id)
    end

    # MODE A, we have a single FileCollection in argument
    if userfiles.size == 1 && userfiles[0].is_a?(FileCollection)
      collection = userfiles[0]
      file_args = old_get_default_args_for_collection(collection)
      params[:collection_id] = collection.id
      params[:file_args]     = file_args
      return ""
    end

    # MODE B, we have one or many T1s in argument
    if userfiles.detect { |u| ! u.is_a?(SingleFile) }
      cb_error "Error: CIVET can only be launched on one FileCollection\n" +
               "or a set of T1 Minc files\n"
    end
    
    file_args = old_get_default_args_for_t1list(userfiles)
    params[:collection_id] = nil
    params[:file_args]     = file_args
    return ""
  end

  def after_form #:nodoc:
    params          = self.params

    # file_args is returned as a hash, so
    # transform it back into an array of records (in the values)
    file_args_hash  = params[:file_args] || {}
    file_args       = file_args_hash.values

    # Nothing to do when we're editing a task.
    if ! self.new_record?
      return ""
    end

    if file_args.empty?
      cb_error "No CIVET started, as no T1 file selected for launch!"
    end

    study_name = params[:study_name] || ""
    if ! study_name.blank? && ! Userfile.is_legal_filename?(study_name)
      cb_error "Sorry, but the study name provided contains some unacceptable characters."
    end

    return ""
  end

  def final_task_list #:nodoc:

    # Nothing to do if re-launching an existing task.
    return [ self ] unless self.new_record?

    params          = self.params

    file_args_hash  = params[:file_args] || {}
    file_args       = file_args_hash.values
    file_args       = file_args.select { |f| f[:launch].to_s == '1' }

    task_list = []
    file_args.each do |file|
      task_list << self.create_civet_for_one(file)
    end

    task_list
  end

  def after_final_task_list_saved(task_list) #:nodoc:

    # Nothing to do if re-launching an existing task.
    return "" if task_list.size == 1 && task_list[0] == self

    params = self.params

    study_name = params[:study_name] || ""
    qc_study   = params[:qc_study]   || ""

    messages = ""
    unless study_name.blank?
      tids = task_list.map &:id
      combiner = create_combiner(study_name,tids)
      combiner.save!
      messages += "Started CivetCombiner task '#{combiner.bname_tid}'\n"
      if qc_study.to_s == '1'
        qc = create_qc(combiner.id)
        qc.save!
        messages += "Started Civet QC task '#{qc.bname_tid}'\n"
      end
    end

    messages
  end

  def untouchable_params_attributes #:nodoc:
    { :file_args => true, :collection_id => true, :output_civetcollection_id => true }
  end


  #################################################
  # OLD API BELOW (+ modified)
  #################################################

  def old_get_default_args_for_collection(collection) #:nodoc:

    # TODO: Provide the link directly in the CIVET args page?
    state = collection.local_sync_status
    cb_error "Error: in order to process this collection, it must first have been synchronized.\n" +
          "In the file manager, click on the collection then on the 'synchronize' link." if
          ! state || state.status != "InSync"

    # Get the list of all files inside the collection; we only
    # look one level deep inside the directory.
    files_inside  = collection.list_files(:top).map(&:name)
    files_inside  = files_inside.map { |f| f.sub(/^.*\//,"") }

    # Parse the list of all files and extract the MINC files.
    # We ignore everything else.
    minc_files = []
    files_inside.each do |basename|
      minc_files << basename if basename.match(/\.mnc(\.gz|\.Z)?$/i)
    end

    cb_error "There are no MINC files in this FileCollection!" unless minc_files.size > 0

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
    file_args_array = []
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

      file_args_array << {
        :launch              => true,

        :t1_id               => nil, # we will use the collection_id instead

        :t1_name             => t1_name, # inside col
        :t2_name             => t2_name, # inside col
        :pd_name             => pd_name, # inside col
        :mk_name             => mk_name, # inside col

        :prefix              => prefix,      # -prefix
        :dsid                => dsid,        #
        
        :multispectral       => false,       # -multispectral for true
        :spectral_mask       => false,       # -spectral-mask for true
      }

    end

    file_args = {}
    file_args_array.each_with_index { |file,i| file_args[i.to_s] = file }
    return file_args
  end

  def old_get_default_args_for_t1list(userfiles) #:nodoc:

    user    = self.user

    all_files_I_can_access = Userfile.find_all_accessible_by_user(user)
    index_of_my_files      = all_files_I_can_access.index_by(&:name)

    file_args_array = []

    userfiles.each do |t1|

      t1_name = t1.name
      t1_id   = t1.id
      (t2_id, pd_id, mk_id) = find_t2_pd_mask(t1_name,index_of_my_files)

      if t1_name.match(/(\w+)_(\w+)_t1\b/i)
        prefix = Regexp.last_match[1]
        dsid   = Regexp.last_match[2]
      else
        prefix = "prefix"
        dsid   = "dsid"
      end

      file_args_array << {
        :launch              => true,

        :t1_name             => t1_name,

        :t1_id               => t1_id,
        :t2_id               => t2_id,
        :pd_id               => pd_id,
        :mk_id               => mk_id,

        :prefix              => prefix,      # -prefix
        :dsid                => dsid,        #
        
        :multispectral       => false,       # -multispectral for true
        :spectral_mask       => false,       # -spectral-mask for true
      }
    end

    file_args = {}
    file_args_array.each_with_index { |file,i| file_args[i.to_s] = file }
    return file_args
  end

  def create_civet_for_one(one_file_args) #:nodoc:

    # Create the new object
    civ             = self.clone
    civparams       = civ.params

    # Non-civet fields not needed so let's not polute the params output in show()
    civparams.delete(:file_args)
    civparams.delete(:study_name)
    civparams.delete(:qc_study)

    # Adjust description
    if civ.description.blank?
      collection_id   = civparams[:collection_id]
      collection_id   = nil if collection_id.blank?
      collection      = collection_id ? FileCollection.find(collection_id) : nil
      t1_object       = collection || Userfile.find(one_file_args[:t1_id])
      t1_name         = collection ? one_file_args[:t1_name] : t1_object.name
      civ.description = t1_name
      civparams[:interface_userfile_ids] = [ t1_object.id ]
    end

    # Initialize the new object
    civparams[:file_args] = { "0" => one_file_args } # just a single entry named '0'

    return civ
  end
  
  def create_combiner(study_name,tids) #:nodoc:

    params = self.params
    
    combiner = CbrainTask::CivetCombiner.new
    combiner.user_id          = self.user_id
    combiner.bourreau_id      = self.bourreau_id
    combiner.description      = study_name
    combiner.status           = 'New'
    combiner.group_id         = self.group_id
    combiner.params = {
      :civet_study_name     => study_name,
      :civet_from_task_ids  => tids.join(","),
      :destroy_sources      => false,  # must be the string 'YeS' to trigger it
      :data_provider_id     => params[:data_provider_id]
    }

    tids.each do |tid|
      combiner.add_prerequisites_for_setup(tid)
    end

    return combiner
  end

  def create_qc(cid) #:nodoc:

    params = self.params

    qc = CbrainTask::CivetQc.new
    qc.user_id     = self.user_id
    qc.bourreau_id = self.bourreau_id
    qc.description = params[:study_name]
    qc.status      = 'New'
    qc.group_id    = self.group_id
    qc.params      = { :study_from_task_id => cid }
    qc.add_prerequisites_for_setup(cid)

    return qc
  end

  # Apply the new auto-prefix and auto-dsid extraction mechanism.
  def refresh_form #:nodoc
    params = self.params
    prefpat = params[:prefix_auto_comp] || ""
    dsidpat = params[:dsid_auto_comp]   || ""
    return "" if prefpat.blank? && dsidpat.blank? # nothing to do
    file_args = params[:file_args] || {}
    file_args.values.each do |struct|
      t1_name = struct[:t1_name]
      next if t1_name.blank?
      comps_array = t1_name.split(/([a-zA-Z0-9]+)/)
      comps = {}
      1.step(comps_array.size,2) { |i| comps[((i-1)/2+1).to_s] = comps_array[i] }
      struct[:prefix] = prefpat.pattern_substitute(comps) if ! prefpat.blank?
      struct[:dsid]   = dsidpat.pattern_substitute(comps) if ! dsidpat.blank?
    end
    ""
  end

  private

  def find_t2_pd_mask(t1_name,userfileindex) #:nodoc:
      if ! t1_name.match(/_t1\b/)
          return [nil,nil,nil]
      end
      t2 = userfileindex[t1_name.sub(/_t1/,"_t2")]
      t2_id = t2 ? t2.id : nil

      pd = userfileindex[t1_name.sub(/_t1/,"_pd")]
      pd_id = pd ? pd.id : nil

      mk = userfileindex[t1_name.sub(/_t1/,"_mask")]
      mk_id = mk ? mk.id : nil

      [t2_id,pd_id,mk_id]
  end

  def extract_t2_pd_mask(t1,minclist)  #:nodoc:
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

  def adjust_old_civet_structure #:nodoc:
    params = self.params

    # This assignment is for back compatibility with old CIVET tasks
    params[:file_args] ||= { "0" => # note that NEW CIVET tasks SAVE the :file_args["0"]
                           { :launch              => true,
                             :t1_id               => params[:t1_id], 
                             :t1_name             => params[:t1_name],
                             :t2_id               => params[:t2_id],
                             :t2_name             => params[:t2_name],
                             :pd_id               => params[:pd_id],
                             :pd_name             => params[:pd_name],
                             :mk_id               => params[:mk_id],
                             :mk_name             => params[:mk_name],
                             :prefix              => params[:prefix],
                             :dsid                => params[:dsid],
                             :multispectral       => params[:multispectral],
                             :spectral_mask       => params[:spectral_mask]
                           } }
    params.delete(:study_name) # just to be sure
    params.delete(:qc_study) # just to be sure
  end

end

