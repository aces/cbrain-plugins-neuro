
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

  def content(options)

    if options[:study_subject]
      return {:partial  => "file_collection_civet_file_list", :locals  => { :subject  => self.get_full_subdir_listing(options[:study_subject]) }}

    elsif options[:qc_file]
      if options[:qc_file] == "base"
        qc_file = self.list_files("QC", :file).find{ |qc| qc.name =~ /\.html$/ && !self.subject_ids.include?(Pathname.new(qc.name).basename.to_s.sub(/\.html$/, "")) }.name
      else
        qc_file = self.name + "/QC/" + options[:qc_file]
      end
      doc = Nokogiri::HTML.fragment(File.read(self.cache_full_path.parent + qc_file))
      doc.search("a").each {|link| link['href'] = "/userfiles/#{self.id}/content?qc_file=#{link['href']}" }
      doc.search("img").each {|img| img['src'] = "/userfiles/#{self.id}/content?collection_file=#{self.list_files.map(&:name).find{ |file| file =~ /#{img['src'].sub(/^\.+\//, "")}$/ }}" }
      doc.search("image").each {|img| img['src'] = "/userfiles/#{self.id}/content?collection_file=#{self.list_files.map(&:name).find{ |file| file =~ /#{img['src'].sub(/^\.+\//, "")}$/ }}" }
      return {:text  => doc.to_html}
    else
      return super
    end
  end
 
  def pretty_type
    "(Study)"
  end
  
  #Returns a list of the ids of the subjects contained in this study.
  def subject_ids
    @subject_id ||= self.list_files(".", :directory).map{ |s| s.name.sub(/^#{self.name}\//, "") }.reject{ |s_id| s_id == "QC" }
  end
  
end
