                                                                     
#
# CBRAIN Project
#
# PortalTask model ReconAll
#
# Original author: 
#
# $Id$
#

# A subclass of CbrainTask to launch recon-all of FreeSurfer.
class CbrainTask::ReconAll

  def is_legal_output_name?(output_name) #:nodoc:
    output_name = params[:output_name]
    return Userfile.is_legal_filename?(output_name)
  end               

  def is_legal_subject_name?(subject_name) #:nodoc:
    return subject_name =~ /^[a-z0-9][\w\-]*$/i
  end
 
  def pretty_name #:nodoc:
    "FreeSurfer Recon-all"
  end

 
end
