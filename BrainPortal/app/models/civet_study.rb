
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
# to represent the output of several *CIVET* runs (see DrmaaCivet). The overall
# structure of a CivetStudy is YET TO BE DETERMINED.
#
# API to come later.
class CivetStudy < FileCollection

  Revision_info="$Id$"

  def pretty_type
    "(Study)"
  end
  
end
