
#
# CBRAIN Project
#
# DrmaaTask models as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

class DrmaaDcm2mnc < DrmaaTask

  Revision_info="$Id$"
  
  def self.has_args?
    false
  end
  
  def self.launch(params = {})
    file_ids = params[:file_ids]
    
    dm = DrmaaDcm2mnc.new
    dm.user_id = Userfile.find(file_ids[0], :include  => :user).user.id
    # TODO what to do when more than one collection selected ?
    # TODO check that the ID is really a collection right away ?
    dm.params = { :dicom_colid => file_ids[0] }
    dm.save
    
    "Started Dcm2Mnc on your files.\n" #flash message
  end

end

