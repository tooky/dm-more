require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

describe DataMapper::Serialize, '#to_csv' do
  #
  # ==== blah, it's CSV
  #

  before(:all) do
    query = DataMapper::Query.new(DataMapper::repository(:default), Cow)

    @collection = DataMapper::Collection.new(query) do |c|
      c.load([1, 2, 'Betsy', 'Jersey'])
      c.load([10, 20, 'Berta', 'Guernsey'])
    end

    @empty_collection = DataMapper::Collection.new(query) {}
  end

  it "should serialize a resource to CSV" do
    peter = Cow.new
    peter.id = 44
    peter.composite = 344
    peter.name = 'Peter'
    peter.breed = 'Long Horn'
    peter.to_csv.chomp.should == '44,344,Peter,Long Horn'
  end

  it "should serialize a collection to CSV" do
    @collection.to_csv.gsub(/[[:space:]]+\n/, "\n").should ==
      "1,2,Betsy,Jersey\n" +
      "10,20,Berta,Guernsey\n"
  end
end
