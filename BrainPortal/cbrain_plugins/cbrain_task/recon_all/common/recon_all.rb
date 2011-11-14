                                                                     
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

  def has_legal_output_name?
    output_name = params[:output_name] 
    return output_name.blank? || Userfile.is_legal_filename?(output_name)
  end               

  def has_legal_subject_name?
    subject_name = params[:subject_name]
    return subject_name =~ /^[a-z0-9][\w\-]*$/i
  end
  
end
