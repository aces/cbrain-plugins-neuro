
#
# Load this file in a console; I suggest running 'no_log' first.
#

1.times do

# Clean up everything
DataladDataProvider.where(:name => [ 'auto-test-top', 'auto-test-abide']).each do |dp|
  dp.userfiles.each do |u|
    puts "Erasing #{u.to_summary}"
    u.delete
  end
  DataladSystemSubset.where("name like '%dp=#{dp.id}%'").each do |u|
    puts "Destroying #{u.to_summary}"
    u.destroy!
  end
  puts "Destroying #{dp.to_summary}"
  dp.reload
  dp.destroy!
end

# Create two DPs and one file
d1=DataladDataProvider.find_or_create_by!(
  :name => 'auto-test-abide',
  :user_id  => CoreAdmin.first.id,
  :group_id => CoreAdmin.first.own_group.id,
  :online => true,
  :read_only => false,
  :not_syncable => false,
  :datalad_repository_url => 'https://datasets.datalad.org/abide',
  :datalad_relative_path => 'RawDataBIDS',
)
d2=DataladDataProvider.find_or_create_by!(
  :name => 'auto-test-top',
  :user_id  => CoreAdmin.first.id,
  :group_id => CoreAdmin.first.own_group.id,
  :online => true,
  :read_only => false,
  :not_syncable => false,
  :datalad_repository_url => 'https://datasets.datalad.org',
  :datalad_relative_path => '',
)
f3=FileCollection.create!(
  :name => 'MaxMun_b',
  :user_id => d1.user_id,
  :group_id => d1.group_id,
  :size => 144639235,
  :data_provider_id => d1.id,
  :num_files => 32,
)

puts_red "Browsing DP1"
list1 = d1.provider_list_all
sc1 = ScratchDataProvider.main.userfiles.last
puts_blue "LS of #{sc1.cache_full_path}"
system "ls #{sc1.cache_full_path}"
cb_error "No good" unless list1.any? { |f| f.name == 'CMU_a' }

puts_red "Browsing DP2"
list2 = d2.provider_list_all
sc2 = ScratchDataProvider.main.userfiles.last
puts_blue "LS of #{sc2.cache_full_path}"
system "ls #{sc2.cache_full_path}"
cb_error "No good" unless list2.any? { |f| f.name == 'abide' }

# provider_collection_index vs cache_collection_index tests
tests = [
  [ ],
  [ :top, [:regular, :directory] ],
  [ :top, :directory ],
  [ :all ],
  [ :all, [:regular, :directory] ],
  [ :all, :directory ],
  [ "sub-0051323" ],
  [ "sub-0051323", :regular ],
  [ "sub-0051323", [ :regular, :directory] ],
  [ ".", [ :regular, :directory] ],
]

dump_fis = lambda { |fis| fis.sort { |a,b| a.name <=> b.name }.each { |fi|
                    printf "%9s %10d %s\n",fi.symbolic_type,fi.size,fi.name } }
type_names = lambda { |fis| fis.sort { |a,b| a.name <=> b.name }.map { |fi|
                      "#{fi.symbolic_type}-#{fi.symbolic_type == :directory ? 0 : fi.size}-#{fi.name}" }.join("\n") }

res = {}
tests.each do |args|
  puts "\n\n\n"
  puts_magenta "LISTING MAXMUN #{args.inspect}"
  mm=f3.provider_collection_index(*args)
  dump_fis.(mm)
  tn = type_names.(mm)
  res[args] = tn
end

puts_red "SYNCING TO CACHE"
f3.sync_to_cache

tests.each do |args|
  puts "\n\n\n"
  puts_magenta "LISTING MAXMUN #{args.inspect}"
  mm=f3.cache_collection_index(*args)
  dump_fis.(mm)
  tn = type_names.(mm)
  if (res[args] != tn)
    puts_red "DIFFER FOR #{args}!!!"
    puts_green  "PROV:\n#{res[args]}"
    puts_yellow "CACHE:\n#{tn}"
  end
end

end
