
#
# CBRAIN Project
#
# DrmaaTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

class DrmaaCivet < DrmaaTask

  Revision_info="$Id$"

#    /usr/local/bic/CIVET/CIVET_Processing_Pipeline -prefix demo -source /home/mero/CIVET/mincfiles -target /home/mero/CIVET -lsq12 -spawn -run rioux_pierre
#
#    NOTE: for SGE, replace '-spawn' by '-sge -granular' ( multiple CIVET jobs run in parallel, a single job would run faster, ma
#    ny would run slower ) or '-sge -nogranular' ( CIVET jobs run to completion, one at the time, so first come first serve ).
#


  def setup
    params       = self.params
    prefix       = params[:prefix] || "unkpref1"
    dsid         = params[:dsid]   || "unkdsid1"
    mincfile_id  = params[:mincfile_id]

    t2_id        = params[:t2_id]
    pd_id        = params[:pd_id]
    mk_id        = params[:mk_id]

    mincfile     = Userfile.find(mincfile_id)
    unless mincfile
      self.addlog("Could not find active record entry for userfile '#{mincfile_id}'.")
      return false
    end

    pre_synchronize_userfile(mincfile)

    Dir.mkdir("mincfiles",0700)

    vaultname    = mincfile.vaultname
    File.symlink(vaultname,"mincfiles/#{prefix}_#{dsid}_t1.mnc")

    if params[:multispectral] || params[:spectral_mask]
      if (t2_id)
        t2vaultfile = Userfile.find(t2_id)
        t2vaultname = t2vaultfile.vaultname
        File.symlink(t2vaultname,"mincfiles/#{prefix}_#{dsid}_t2.mnc")
        pre_synchronize_userfile(t2vaultfile)
      end

      if (pd_id)
        pdvaultfile = Userfile.find(pd_id)
        pdvaultname = pdvaultfile.vaultname
        File.symlink(pdvaultname,"mincfiles/#{prefix}_#{dsid}_pd.mnc")
        pre_synchronize_userfile(pdvaultfile)
      end

      if (mk_id)
        mkvaultfile = Userfile.find(mk_id)
        mkvaultname = mkvaultfile.vaultname
        File.symlink(mkvaultname,"mincfiles/#{prefix}_#{dsid}_mask.mnc")
        pre_synchronize_userfile(mkvaultfile)
      end
    end

    Dir.mkdir("civet_out",0700)

    true
  end

  def drmaa_commands
    params = self.params

    prefix = params[:prefix] || "unkpref2"
    dsid   = params[:dsid]   || "unkdsid2"

    args = ""

    args += "-make-graph "                          if params[:make_graph]
    args += "-make-filename-graph "                 if params[:make_filename_graph]
    args += "-print-status-report "                 if params[:print_status_report]
    args += "-template #{params[:template]} "       if params[:template]
    args += "-model #{params[:model]} "             if params[:model]
    args += "-interp #{params[:interp]} "           if params[:interp]
    args += "-N3-distance #{params[:N3_distance]} " if params[:N3_distance]
    args += "-lsq#{params[:lsq]} "                  if params[:lsq] && params[:lsq].to_i != 9
    args += "-no-surfaces "                         if params[:no_surfaces]
    args += "-multispectral "                       if params[:multispectral]
    args += "-spectral_mask "                       if params[:spectral_mask]

    if params[:correct_pve]
        args += "-correct-pve "
    else
        # args += "-no-correct-pve "      # default
    end

    if params[:thickness_method] && params[:thickness_kernel]
        args += "-thickness #{params[:thickness_method]} #{params[:thickness_kernel]} "
    end

    if params[:resample_surfaces]
        args += "-resample-surfaces "
    else
        # args += "-no-resample-surfaces "      # default
    end

    if params[:combine_surfaces]
        args += "-combine-surfaces "
    else
        # args += "-no-combine-surfaces "      # default
    end

    civet_command = "CIVET_Processing_Pipeline -prefix #{prefix} -source mincfiles -target civet_out -spawn #{args} -run #{dsid}"

    self.addlog("Full CIVET command:\n  #{civet_command.gsub(/ -/, "\n  -")}")

    return [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "export PATH=\"#{CBRAIN::CIVET_dir}:$PATH\"",
      "echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET",
      "echo Command: #{civet_command}",
      "#{civet_command}"
    ]

  end

  def save_results
    params       = self.params
    user_id      = self.user_id

    mincfile_id  = params[:mincfile_id]
    mincfile     = Userfile.find(mincfile_id)

    civet_tarresult = "civet#{self.object_id}.tar"

    # TODO: speed up tar? Create in /tmp?
    system("tar -cpf #{civet_tarresult} civet_out")
    # Note: tar file will be cleaned up at the same time the workdir is erased

    # TODO: speed up .read() ?
    civetresult = SingleFile.new(
      :user_id   => user_id,
      :name      => civet_tarresult,
      :content   => File.read(civet_tarresult),
      :task      => "Civet"
    )

    if civetresult.save
      civetresult.move_to_child_of(mincfile)
      self.addlog("Saved new civet result file #{civetresult.name}.")
      post_synchronize_userfile(civetresult)
      return true
    else
      self.addlog("Could not save back result file '#{civetresult.name}'.")
      return false
    end

  end

end

