
#
# CBRAIN Project
#
# Civet Study model
# Essentially a collection of CivetOutputs where more than one subject is involved.
#
# Original author: Pierre Rioux
#
# $Id$
#

# This class represents a FileCollection meant specifically
# to represent the output of several *CIVET* runs (see CbrainTask::Civet).
#
# API to come later.
class CivetStudy < FileCollection

  Revision_info=CbrainFileRevision[__FILE__]
  
  has_viewer :civet_study
  
  #Returns a list of the ids of the subjects contained in this study.
  def subject_ids
    @subject_id ||= self.list_files(".", :directory).map{ |s| s.name.sub(/^#{self.name}\//, "") }.reject{ |s_id| s_id == "QC" }
  end
  
end
