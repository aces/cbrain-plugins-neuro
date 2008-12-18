
#
# CBRAIN Project
#
# DrmaaTask subclass
#
# Original author: Pierre Rioux
#
# $Id: drmaa_minc2jiv.rb 87 2008-12-10 21:06:03Z prioux $
#

class DrmaaCivet < DrmaaTask

  Revision_info="$Id: drmaa_minc2jiv.rb 87 2008-12-10 21:06:03Z prioux $"

#    /usr/local/bic/CIVET/CIVET_Processing_Pipeline -prefix demo -source /home/mero/CIVET/natives -target /home/mero/CIVET -lsq12 -spawn -run rioux_pierre
#
#    NOTE: for SGE, replace '-spawn' by '-sge -granular' ( multiple CIVET jobs run in parallel, a single job would run faster, ma
#    ny would run slower ) or '-sge -nogranular' ( CIVET jobs run to completion, one at the time, so first come first serve ).
#


  def setup
    params       = self.params

    mincfile_id  = params[:mincfile_id]
    mincfile     = Userfile.find(mincfile_id)
    unless mincfile
      self.addlog("Could not find active record entry for userfile #{mincfile_id}")
      return false
    end

    Dir.mkdir("natives",0700)
    vaultname    = mincfile.vaultname
    File.symlink(vaultname,"natives/civet_in_t1.mnc")

    Dir.mkdir("civet_out",0700)

    true
  end

  def drmaa_commands
    params = self.params
    [
      "source /usr/local/bic/init.sh",
      "export PATH=\"/usr/local/bic/CIVET:$PATH\"",
      "echo \"\";echo \"\";echo Showing ENVIRONMENT",
      "env | sort",
      "echo \"\";echo Starting CIVET",
      "CIVET_Processing_Pipeline -prefix civet -source natives -target civet_out -lsq12 -spawn -run in"
    ]
  end

  def save_results
    params = self.params
    mincfile_id  = params[:mincfile_id]
    mincfile     = Userfile.find(mincfile_id)
    user_id      = mincfile.user_id

    civet_tarresult = "civet#{self.object_id}.tar"

    # TODO: speed up tar? Create in /tmp?
    system("tar -cpf #{civet_tarresult} civet_out")
    # Note: tar file will be cleaned up at the same time the workdir is erased

    # TODO: speed up .read() ?
    civetresult = Userfile.new(
      :user_id   => user_id,
      :name      => civet_tarresult,
      :content   => File.read(civet_tarresult)
    )

    if civetresult.save
      civetresult.move_to_child_of(mincfile)
      self.addlog("Saved new civet result file #{civetresult.name}")
      return true
    else
      self.addlog("Could not save back result file '#{civetresult.name}'.")
      return false
    end

  end

end

