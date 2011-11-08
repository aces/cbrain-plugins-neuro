
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
class CbrainTask::ReconAll < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.default_launch_args #:nodoc:
    {
    }
  end
  
  def before_form #:nodoc:
    params   = self.params

    file_ids  = params[:interface_userfile_ids] || []
    mgzfiles = Userfile.find_all_by_id(file_ids)
    mgzfiles.each do |mgzfile|     
      cb_error "Error: this program can only run on MGZ File." unless 
        mgzfile.is_a?(MgzFile)
    end
    
    return ""
  end

  def after_form #:nodoc:
    params = self.params

    # Check output_name
    self.params_errors.add(:output_name, "provided contains some unacceptable characters.")   unless has_legal_output_name?

    # Check subject_name
    self.params_errors.add(:subject_name, "provided is blank or contains some unacceptable characters.") unless has_legal_subject_name?
    
    ""
  end

  def self.pretty_params_names #:nodoc:
    { :output_name => 'Output name ', :subject_name => 'Subject name' }
  end

  def untouchable_params_attributes
    { :outfile_id => true}
  end

end

