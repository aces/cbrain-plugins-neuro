
#
# CBRAIN Project
#
# Civet Study model
# Essentially a Civet Collection where more than one subject is involved.
#
# Original author: Pierre Rioux
#
# $Id$
#

# This class represents a CivetCollection (itself a FileCollection) meant specifically
# to represent the output of several *CIVET* runs (see CbrainTask::Civet). The overall
# structure of a CivetStudy is YET TO BE DETERMINED.
#
# API to come later.
class CivetStudy < FileCollection

  Revision_info="$Id$"

  def pretty_type
    "(Study)"
  end
  
  def subject_ids
    @subject_id ||= self.list_files(".", :directory).map{ |s| s.name.sub(/^#{self.name}\//, "") }.reject{ |s_id| s_id == "QC" }
  end
  
end
