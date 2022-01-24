
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

# A subclass of PortalTask to launch civet.
class CbrainTask::Civet < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  InterfaceUserfileIDsLimit = 1000

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
    verify_civet
  )

  task_properties :readonly_input_files, :use_parallelizer

  # Returns the scientific parameters common to all the CIVET
  # jobs we're about to launch
  def self.default_launch_args #:nodoc:
    {
      :file_args           => {},

      # Input options
      :input_is_stx        => "0",         # -input_is_stx

      # Pipeline options
      :reset_from          => "",          # -reset-from

      # Volume option
      :model               => "icbm152nl", # -model
      :template            => "1.00",      # -template
      :lsq                 => "9",         # -lsq6, -lsq9, -lsq12
      :interp              => "trilinear", # -interp
      :headheight          => "",          # CIVET 1.1.12 or better only
      :mask_blood_vessels  => "0",         # -mask-blood-vessels
      :N3_distance         => "",          # -N3-distance

      # Surface option
      :no_surfaces         => "0",         # -no-surfaces
      :high_res_surfaces   => "0",         # -hi-res-surfaces
      :combine_surfaces    => "0",         # -[no-]combine-surfaces
      :thickness_method    => "tlink",     # -thickness method kernel
      :thickness_kernel    => "",          #             "
      :resample_surfaces   => "1",         # -[no-]resample-surfaces
      :atlas               => "",          # -surface-atlas
      :resample_surfaces_kernel_areas   => "", # -area-fwhm
      :resample_surfaces_kernel_volumes => "", # -volume-fwhm

      # VBM options
      :VBM                 => "0",         # -[no-]VBM
      :VBM_fwhm            => "8",         # -VBM-fwhm
      :VBM_symmetry        => "0",         # -[no-]VBM-symmetry
      :VBM_cerebellum      => "1",         # -[no-]VBM-cerebellum

      # ANIMAL options
      :animal              => "0",         # -[no-]ANIMAL

      # CBRAIN output renaming
      :output_filename_pattern => '{subject}-{cluster}-{task_id}-{run_number}',

    }
  end

  def before_form #:nodoc:
    params    = self.params

    params[:model] = "icbm152nl_09s" if self.tool_config && self.tool_config.is_at_least_version("2.0.0")
    if self.tool_config && self.tool_config.is_at_least_version("2.1.0")
      params[:thickness_method]        = ["tlaplace"]
      params[:thickness_method_for_qc] = "tlaplace"
      params[:template]                = "0.5"
      params[:lsq]                     = "12"
    end

    file_ids  = params[:interface_userfile_ids]

    userfiles = Userfile.where(:id => file_ids)

    # The params serialization is limited to 65000 bytes, so we need to set a limit of selected file.
    cb_error "Error: Too many files selected, this task can only handle #{InterfaceUserfileIDsLimit} T1 files at a time." if userfiles.size > InterfaceUserfileIDsLimit
    userfiles = userfiles.all.to_a

    # MODE A, we have a single FileCollection in argument
    if userfiles.size == 1 && userfiles[0].is_a?(FileCollection)
      collection = userfiles[0]
      file_args  = old_get_default_args_for_collection(collection)
      params[:collection_id] = collection.id
      params[:file_args]     = file_args
      return ""
    end

    # MODE B, we have one or many T1s in argument
    if userfiles.any? { |u| ! u.is_a?(SingleFile) }
      cb_error "Error: CIVET can only be launched on one FileCollection\n" +
               "or a set of T1 Minc files\n"
    end

    file_args = old_get_default_args_for_t1list(userfiles)
    params[:collection_id] = nil
    params[:file_args]     = file_args
    return ""
  end

  def after_form #:nodoc:
    params = self.params
    # clean some params according with other one.
    clean_interdependent_params()

    return "" if self.tool_config.blank?

    # file_args is returned as a hash, so
    # transform it back into an array of records (in the values)
    file_args_hash  = params[:file_args] || {}

    cb_error "Cannot update this CIVET task; its structure is no longer supported." if file_args_hash.size > 1 && ! self.new_record?

    file_args       = file_args_hash.values
    file_args       = file_args.select { |f| f[:launch].to_s == '1' }

    if file_args.empty?
      cb_error  "No CIVET started, as no T1 file selected for launch!" if self.new_record?
      cb_notice "Warning! No T1 file selected for processing!"
    end

    # Verify N3_distance value
    if params[:N3_distance].blank? || params[:N3_distance] !~ /^\d+$/
      params_errors.add(:N3_distance, <<-N3_MESSAGE)
        suggested values: 200 for 1.5T scan; 50-125 for 3T scan.
        For older 3T scans, low values nearer 50 may work best;
        for newer 3T scans, high values nearer 125 may work best.
        0 is acceptable for versions later than 1.1.12 for MP2RAGE scanner.
      N3_MESSAGE
    end

    # Verify headheight value
    if params[:headheight].present? && params[:headheight] !~ /^\d+$/
      params_errors.add(:headheight,  " must be an integer")
    end

    # Verify thickness value
    if params[:thickness_kernel].blank?
      params[:thickness_kernel] = (self.tool_config && self.tool_config.is_at_least_version("1.1.12")) ? "30" : "20"
    end

    # Verify thickness kernel
    if !is_valid_integer_list(params[:thickness_kernel], allow_blanks: true)
      params_errors.add(:thickness_kernel,
        " must be an integer (version < 2.0.0) or a list of integers separated by a ':' (version >= 2.0.0)")
    end

    # Verify resample surfaces
    if !is_valid_integer_list(params[:resample_surfaces_kernel_areas], allow_blanks: true)
      params_errors.add(:resample_surfaces_kernel_areas,
        " must be an integer (version < 2.0.0) or a list of integers separated by a ':' (version >= 2.0.0)")
    end

    if !is_valid_integer_list(params[:resample_surfaces_kernel_volumes], allow_blanks: true)
      params_errors.add(:resample_surfaces_kernel_volumes,
        " must be an integer (version < 2.0.0) or a list of integers separated by a ':' (version >= 2.0.0)")
    end

    # Verify uniqueness of subject IDs
    dsid_counts = {}
    file_args_hash.each do |idx,fa|
      dsid = (fa[:dsid] || "").strip
      fa[:dsid] = dsid # write back cleaned up value
      dsid_counts[dsid] ||= 0
      dsid_counts[dsid]  += 1
    end

    is_at_least_version_2_1_0 = self.tool_config && self.tool_config.is_at_least_version("2.1.0")

    # Verify validity of subject IDs and prefix
    file_args_hash.each do |idx,fa|
      next unless fa[:launch] == '1'

      # Preprocess the subject ID
      dsid = fa[:dsid]

      # Verify the subject ID
      message = nil
      if dsid.blank?
        message = " is blank?"
      elsif dsid !~ /^\w[\w\-]*$/
        message = " is not a simple identifier."
      elsif dsid_counts[dsid] > 1
        message = " is the same as another subject ID."
      end
      if message
        self.class.pretty_params_names["file_args[#{idx}][dsid]"] = "Subject ID for '#{fa[:t1_name]}'"
        params_errors.add(             "file_args[#{idx}][dsid]", message)
      end

      # Preprocess the prefix
      prefix = (fa[:prefix] || "").strip
      fa[:prefix] = prefix

      # Verify the prefix
      message = nil
      if prefix.blank?  && is_at_least_version_2_1_0
        message = nil
      elsif prefix.blank?
        message = " is blank?"
      elsif prefix !~ /^\w[\w\-]*$/
        message = " is not a simple identifier."
      end
      if message
        self.class.pretty_params_names["file_args[#{idx}][prefix]"] = "Prefix ID for '#{fa[:t1_name]}'"
        params_errors.add(             "file_args[#{idx}][prefix]", message)
      end

    end

    # Nothing else to do when we're editing an existing task
    return "" if ! self.new_record?

    # Combine into a Study
    study_name = (params[:study_name] || "").strip
    params[:study_name] = study_name
    if params[:qc_study] == '1' && study_name.blank?
      params_errors.add(:study_name, "needs to be given if QC is requested too.")
    end
    if study_name.present?
      if ! Userfile.is_legal_filename?(study_name)
        params_errors.add(:study_name, "contains some unacceptable characters.")
        return ""
      end
      combiner_tool_config_id = params[:combiner_tool_config_id]
      cb_error "You need to select a version for the optional CivetCombiner task." if combiner_tool_config_id.blank?
      cb_error "The version of CivetCombiner you selected is not on the same Execution Server as your CIVET tasks!" if
        ToolConfig.find(combiner_tool_config_id).bourreau_id != self.bourreau_id
      if params[:qc_study] == '1'
        qc_tool_config_id = params[:qc_tool_config_id]
        cb_error "You need to select a version for the optional CivetQc task." if qc_tool_config_id.blank?
        cb_error "The version of CivetQc you selected is not on the same Execution Server as your CIVET tasks!" if
          ToolConfig.find(qc_tool_config_id).bourreau_id != self.bourreau_id
      end
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
    file_args.each do |fa|
      task_list << self.create_single_civet_task(fa)
    end

    return task_list
  end

  def after_final_task_list_saved(task_list) #:nodoc:

    # Nothing to do if re-launching an existing task.
    return "" if task_list.size == 1 && task_list[0] == self

    params = self.params

    study_name = params[:study_name] || ""
    qc_study   = params[:qc_study]   || ""

    messages = ""
    if study_name.present?
      tids = task_list.map(&:id)
      combiner = create_combiner(study_name,tids)
      combiner.tool_config_id = params[:combiner_tool_config_id].to_i
      combiner.save!
      messages += "Created CivetCombiner task '#{combiner.bname_tid}'\n"
      if qc_study.to_s == '1'
        qc = create_qc(combiner.id)
        qc.tool_config_id = params[:qc_tool_config_id].to_i
        qc.save!
        messages += "Created Civet QC task '#{qc.bname_tid}'\n"
      end
    end

    messages
  end

  def untouchable_params_attributes #:nodoc:
    { :collection_id => true,
      :output_civetcollection_id  => true, # OLD deprecated
      :output_civetcollection_ids => true  # The NEW convention is to use output_civetcollection_ids (with an 's'), not _id
    }
  end

  def unpresetable_params_attributes #:nodoc:
    { :file_args => true }
  end



  #################################################
  # OLD API BELOW (+ modified)
  #################################################

  def old_get_default_args_for_collection(collection) #:nodoc:

    # Get the list of all files inside the collection
    if collection.is_a?(LorisSubject)
      files_inside  = collection.list_files().map(&:name) # will work synchronized or not
    else
      # TODO: Provide the link directly in the CIVET args page?
      cb_error "Error: in order to process this collection, it must first have been synchronized.\n" +
               "In the file manager, click on the collection then on the 'synchronize' link." unless collection.is_locally_synced?
      # we only look one level deep inside the directory.
      files_inside  = collection.list_files(:top).map(&:name)
      files_inside  = files_inside.map { |f| Pathname.new(f).basename.to_s }
    end

    # Parse the list of all files and extract the MINC files.
    # We ignore everything else.
    minc_files = []
    warned_bad = 0
    files_inside.each do |basename|
      if basename.match(/\.mnc(\.gz|\.Z)?$/i)
        if Userfile.is_legal_filename?(basename)
          minc_files << basename
        else
          warned_bad += 1
        end
      end
    end

    if warned_bad > 0
      self.errors.add(:base, "Some filenames (#{warned_bad} of them) inside the collection are not correct and will be ignored.")
    end

    cb_error "There are no valid MINC files in this collection!" unless minc_files.size > 0

    # From the list of minc files, try to identify files
    # that are clearly 't1' files, based on the filename.
    t1_files = []
    minc_files.each do |minc|
      t1_files << minc if minc.match(/(\b|_)t1(\b|_)/i)
    end

    # If we have any, we remove them from the total list of minc files.
    minc_files = minc_files - t1_files

    # Prepare the structure for all the CIVET operations;
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
      next if minc.match(/(\b|_)(t2|pd|mask)(\b|_)/i)  # ignore spurious t2s, pds, and masks
      minc_groups << [ minc, nil, nil, nil ]
    end

    # OK, build an arg structure for each minc group
    file_args_array = []
    minc_groups.each_with_index do |group,idx|

      t1_name = group[0]
      t2_name = group[1]
      pd_name = group[2]
      mk_name = group[3]

      if t1_name.match(/(\w+)(\W+|_)(\w+)(\W+|_)t1(\b|_)/i)
        prefix = Regexp.last_match[1]
        dsid   = Regexp.last_match[3]
      else
        prefix = self.tool_config && !self.tool_config.is_version("2.1.0") ? "prefix"  : ""
        dsid   = "subject"  # maybe "auto_#{idx}"
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

        :multispectral       => (t2_name.present? || pd_name.present?), # -multispectral for true
        :spectral_mask       => (t2_name.present? || pd_name.present?), # -spectral-mask for true
      }

    end

    # The final structure, for historical reasons, is a hash
    # with stringified numerical keys (yuk) : { "0" => { struct }, "1" => { struct } ... }
    file_args = {}
    file_args_array.each_with_index { |file,i| file_args[i.to_s] = file }
    return file_args
  end

  def old_get_default_args_for_t1list(minc_userfiles) #:nodoc:

    user    = self.user

    file_args_array = []

    minc_userfiles.each_with_index do |t1,idx|

      t1_name = t1.name
      t1_id   = t1.id

      t2_id   = nil
      pd_id   = nil
      mk_id   = nil

      # Find other MINC userfiles with similar names, but with _t2, _pd or _mask instead of _t1
      if t1_name =~ /(\b|_)t1(\b|_)/i
        all_access = SingleFile.find_all_accessible_by_user(user, :access_requested => :read) # a relation
        # Names in DB are not case sensitive, so searching for _t2 matches files with _T2
        t2_id = all_access.where(:name => t1_name.sub(/(\b|_)t1(\b|_)/i,'\1t2\2')).limit(1).raw_first_column("#{Userfile.table_name}.id")[0]
        pd_id = all_access.where(:name => t1_name.sub(/(\b|_)t1(\b|_)/i,'\1pd\2')).limit(1).raw_first_column("#{Userfile.table_name}.id")[0]
        mk_id = all_access.where(:name => t1_name.sub(/(\b|_)t1(\b|_)/i,'\1mask\2')).limit(1).raw_first_column("#{Userfile.table_name}.id")[0]
      end

      if t1_name.match(/(\w+)(\W+|_)(\w+)(\W+|_)t1(\b|_)/i)
        prefix = Regexp.last_match[1]
        dsid   = Regexp.last_match[3]
      else
        prefix = self.tool_config && !self.tool_config.is_version("2.1.0") ? "prefix"  : ""
        dsid   = "subject"  # maybe "auto_#{idx}"
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

        :multispectral       => (t2_id.present? || pd_id.present?), # -multispectral for true
        :spectral_mask       => (t2_id.present? || pd_id.present?), # -spectral-mask for true
      }
    end

    # The final structure, for historical reasons, is a hash
    # with stringified numerical keys (yuk) : { "0" => { struct }, "1" => { struct } ... }
    file_args = {}
    file_args_array.each_with_index { |file,i| file_args[i.to_s] = file }
    return file_args
  end

  def create_single_civet_task(file_arg) #:nodoc:

    # Create the new object
    civ             = self.dup    # not .clone, as of Rails 3.1.10
    civparams       = civ.params  # ActiveRecord is supposed to dup the hash too

    # Non-civet fields not needed so let's not polute the params output in show()
    civparams.delete(:file_args)
    civparams.delete(:study_name)
    civparams.delete(:qc_study)
    civparams.delete(:combiner_tool_config_id)
    civparams.delete(:qc_tool_config_id)

    # Clean up description
    desc  = civ.description.blank? ? "" : civ.description.strip
    desc += "\n\n" if desc.present?

    # Adjust description and list of IDs based on mode (collection vs T1 file)
    collection_id   = civparams[:collection_id]
    collection_id   = nil if collection_id.blank?
    collection      = collection_id ? FileCollection.find(collection_id) : nil
    t1_object       = collection || Userfile.find(file_arg[:t1_id])
    t1_name         = collection ? file_arg[:t1_name] : t1_object.name
    desc           += "#{t1_name}\n"
    iuids           = collection ? [ collection.id ] : [ t1_object.id ]

    # Set these things
    civ.description                    = desc
    civparams[:interface_userfile_ids] = iuids

    # Initialize the new object's file_args
    civparams[:file_args] = { "0" => file_arg } # just one fixed entry with key "0"

    return civ
  end

  def create_combiner(study_name,tids) #:nodoc:

    combiner = CbrainTask::CivetCombiner.new
    combiner.user_id          = self.user_id
    combiner.bourreau_id      = self.bourreau_id
    combiner.description      = study_name
    combiner.status           = 'New'
    combiner.group_id         = self.group_id
    combiner.batch_id         = self.batch_id
    combiner.params = {
      :civet_study_name     => study_name,
      :civet_from_task_ids  => tids.join(","),
      :destroy_sources      => false  # must be the string 'YeS' to trigger it
    }.with_indifferent_access

    tids.each do |tid|
      combiner.add_prerequisites_for_setup(tid)
    end

    return combiner
  end

  def create_qc(cid) #:nodoc:
    # 'cid' is the CivetCombiner ID

    params = self.params

    qc = CbrainTask::CivetQc.new
    qc.user_id     = self.user_id
    qc.bourreau_id = self.bourreau_id
    qc.description = params[:study_name]
    qc.status      = 'New'
    qc.group_id    = self.group_id
    qc.batch_id    = self.batch_id
    qc.params      = { :study_from_task_id => cid }.with_indifferent_access
    qc.add_prerequisites_for_setup(cid)

    return qc
  end

  # Apply the new auto-prefix and auto-dsid extraction mechanism.
  def refresh_form #:nodoc:
    params = self.params

    prefpat = params[:prefix_auto_comp] || ""
    dsidpat = params[:dsid_auto_comp]   || ""
    return "" if prefpat.blank? && dsidpat.blank? # nothing to do

    file_args = params[:file_args] || {}
    file_args.values.each do |struct|
      t1_name = struct[:t1_name]
      next if t1_name.blank?
      comps_array = t1_name.split(/([a-zA-Z0-9]+)/)
      comps = {} # From "abc_def" will make { "0" => 'abc', "1" => 'def' ... }
      1.step(comps_array.size,2) { |i| comps[((i-1)/2+1).to_s] = comps_array[i] }
      struct[:prefix] = prefpat.pattern_substitute(comps) if prefpat.present?
      struct[:dsid]   = dsidpat.pattern_substitute(comps) if dsidpat.present?
    end
    ""
  end

  def self.pretty_params_names #:nodoc:
    @_ppn ||= {}
  end

  def zenodo_outputfile_ids #:nodoc:
    params[:output_civetcollection_ids] || []
  end

  private

  # A destructive method; tries to find some
  # names in the array minclist, and if found
  # returns them while removing them from the array.
  # Returns a quadruplet:
  #   [ t2_name, pd_name, mk_name, modified_minclist ]
  def extract_t2_pd_mask(t1,minclist)  #:nodoc:
    t2_name = nil
    pd_name = nil
    mk_name = nil

    expect = t1.sub(/(\b|_)t1(\b|_)/i,'\1t2\2')
    t2_name = minclist.detect { |n| n.downcase == expect.downcase }

    expect = t1.sub(/(\b|_)t1(\b|_)/i,'\1pd\2')
    pd_name = minclist.detect { |n| n.downcase == expect.downcase }

    expect = t1.sub(/(\b|_)t1(\b|_)/i,'\1mask\2')
    mk_name = minclist.detect { |n| n.downcase == expect.downcase }

    minclist = minclist - [ t2_name, pd_name, mk_name ]

    [ t2_name, pd_name, mk_name, minclist ]
  end

end

