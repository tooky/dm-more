require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

if HAS_SQLITE3 || HAS_MYSQL || HAS_POSTGRES

  class User
    include DataMapper::Resource

    property :id, Serial
    property :name, String

    has n, :categories
  end

  class Category
    include DataMapper::Resource

    property :id, Integer, :serial => true
    property :name, String

    belongs_to :user

    is :nested_set, :scope => [:user_id]



    # convenience method only for speccing.
    def pos; [lft,rgt] end
  end

  def setup
    repository(:default) do

      User.auto_migrate!
      @paul = User.create!(:name => "paul")
      @john = User.create!(:name => "john")

      Category.auto_migrate!
      electronics  = Category.create!(:id => 1, :name => "Electronics")
      televisions  = Category.create!(:id => 2, :parent_id => 1,  :name => "Televisions")
      tube         = Category.create!(:id => 3, :parent_id => 2,  :name => "Tube")
      lcd          = Category.create!(:id => 4, :parent_id => 2,  :name => "LCD")
      plasma       = Category.create!(:id => 5, :parent_id => 2,  :name => "Plasma")
      portable_el  = Category.create!(:id => 6, :parent_id => 1,  :name => "Portable Electronics")
      mp3_players  = Category.create!(:id => 7, :parent_id => 6,  :name => "MP3 Players")
      flash        = Category.create!(:id => 8, :parent_id => 7,  :name => "Flash")
      cd_players   = Category.create!(:id => 9, :parent_id => 6,  :name => "CD Players")
      radios       = Category.create!(:id => 10,:parent_id => 6,  :name => "2 Way Radios")
    end
  end

  setup

  # id | lft| rgt| title
  #========================================
  # 1  | 1  | 20 | - Electronics
  # 2  | 2  | 9  |   - Televisions
  # 3  | 3  | 4  |     - Tube
  # 4  | 5  | 6  |     - LCD
  # 5  | 7  | 8  |     - Plasma
  # 6  | 10 | 19 |   - Portable Electronics
  # 7  | 11 | 14 |     - MP3 Players
  # 8  | 12 | 13 |       - Flash
  # 9  | 15 | 16 |     - CD Players
  # 10 | 17 | 18 |     - 2 Way Radios

  # |  |  |      |  |     |  |        |  |  |  |  |           |  |  |            |  |              |  |  |
  # 1  2  3      4  5     6  7        8  9  10 11 12  Flash  13 14  15          16  17            18 19 20
  # |  |  | Tube |  | LCD |  | Plasma |  |  |  |  |___________|  |  | CD Players |  | 2 Way Radios |  |  |
  # |  |  |______|  |_____|  |________|  |  |  |                 |  |____________|  |______________|  |  |
  # |  |                                 |  |  |   MP3 Players   |                                    |  |
  # |  |          Televisions            |  |  |_________________|       Portable Electronics         |  |
  # |  |_________________________________|  |_________________________________________________________|  |
  # |                                                                                                    |
  # |                                       Electronics                                                  |
  # |____________________________________________________________________________________________________|



  describe 'DataMapper::Is::NestedSet' do
    before :all do

    end

    describe 'Class#rebuild_tree_from_set' do
      it 'should reset all parent_ids correctly' do
        repository(:default) do
          plasma = Category.get(5)
          plasma.parent_id.should == 2
          plasma.ancestor.id.should == 2
          plasma.pos.should == [7,8]
          plasma.parent_id = nil
          Category.rebuild_tree_from_set
          plasma.parent_id.should == 2
        end
      end
    end

    describe 'Class#root and #root' do
      it 'should return the toplevel node' do
        Category.root.name.should == "Electronics"
      end
    end

    describe 'Class#leaves and #leaves' do
      it 'should return all nodes without descendants' do
        repository(:default) do
          Category.leaves.length.should == 6

          r = Category.root
          r.leaves.length.should == 6
          r.children[1].leaves.length.should == 3
        end
      end
    end

    describe '#ancestor, #ancestors and #self_and_ancestors' do
      it 'should return ancestors in an array' do
        repository(:default) do |repos|
          c8 = Category.get(8)
          c8.ancestor.should == Category.get(7)
          c8.ancestor.should == c8.parent

          c8.ancestors.map{|a|a.name}.should == ["Electronics","Portable Electronics","MP3 Players"]
          c8.self_and_ancestors.map{|a|a.name}.should == ["Electronics","Portable Electronics","MP3 Players","Flash"]
        end
      end
    end

    describe '#children' do
      it 'should return children of node' do
        repository(:default) do |repos|
          r = Category.root
          r.children.length.should == 2

          t = r.children.first
          t.children.length.should == 3
          t.children.first.name.should == "Tube"
          t.children[2].name.should == "Plasma"
        end
      end
    end

    describe '#descendants and #self_and_descendants' do
      it 'should return all subnodes of node' do
        repository(:default) do
          r = Category.root
          r.self_and_descendants.length.should == 10
          r.descendants.length.should == 9

          t = r.children[1]
          t.descendants.length.should == 4
          t.descendants.map{|a|a.name}.should == ["MP3 Players","Flash","CD Players","2 Way Radios"]
        end
      end
    end

    describe '#siblings and #self_and_siblings' do
      it 'should return all siblings of node' do
        repository(:default) do
          r = Category.root
          r.self_and_siblings.length.should == 1
          r.descendants.length.should == 9

          televisions = r.children[0]
          televisions.siblings.length.should == 1
          televisions.siblings.map{|a|a.name}.should == ["Portable Electronics"]
        end
      end
    end

    describe '#move' do

      # Outset:
      # id | lft| rgt| title
      #========================================
      # 1  | 1  | 20 | - Electronics
      # 2  | 2  | 9  |   - Televisions
      # 3  | 3  | 4  |     - Tube
      # 4  | 5  | 6  |     - LCD
      # 5  | 7  | 8  |     - Plasma
      # 6  | 10 | 19 |   - Portable Electronics
      # 7  | 11 | 14 |     - MP3 Players
      # 8  | 12 | 13 |       - Flash
      # 9  | 15 | 16 |     - CD Players
      # 10 | 17 | 18 |     - 2 Way Radios


      it 'should move items correctly with :higher / :highest / :lower / :lowest' do
        repository(:default) do |repos|

          Category.get(4).pos.should == [5,6]

          Category.get(4).move(:above => Category.get(3))
          Category.get(4).pos.should == [3,4]

          Category.get(4).move(:higher).should == false
          Category.get(4).pos.should == [3,4]
          Category.get(3).pos.should == [5,6]
          Category.get(4).right_sibling.should == Category.get(3)

          Category.get(4).move(:lower)
          Category.get(4).pos.should == [5,6]
          Category.get(4).left_sibling.should == Category.get(3)
          Category.get(4).right_sibling.should == Category.get(5)

          Category.get(4).move(:highest)
          Category.get(4).pos.should == [3,4]
          Category.get(4).move(:higher).should == false

          Category.get(4).move(:lowest)
          Category.get(4).pos.should == [7,8]
          Category.get(4).left_sibling.should == Category.get(5)

          Category.get(4).move(:higher) # should reset the tree to how it was

        end
      end

      it 'should move items correctly with :indent / :outdent' do
        repository(:default) do |repos|

          mp3_players = Category.get(7)

          portable_electronics = Category.get(6)
          televisions = Category.get(2)

          mp3_players.pos.should == [11,14]
          #mp3_players.descendants.length.should == 1

          # The category is at the top of its parent, should not be able to indent.
          mp3_players.move(:indent).should == false

          mp3_players.move(:outdent)

          mp3_players.pos.should == [16,19]
          mp3_players.left_sibling.should == portable_electronics

          mp3_players.move(:higher) # Move up above Portable Electronics

          mp3_players.pos.should == [10,13]
          mp3_players.left_sibling.should == televisions
        end
      end
    end

    describe 'moving objects with #move_* #and place_node_at' do
      it 'should set left/right when choosing a parent' do
        repository(:default) do |repos|
          Category.auto_migrate!

          c1 = Category.create!(:name => "New Electronics")

          c2 = Category.create!(:name => "OLED TVs")

          c1.pos.should == [1,4]
          c1.root.should == c1
          c2.pos.should == [2,3]

          c3 = Category.create(:name => "Portable Electronics")
          c3.parent=c1
          c3.save

          c1.pos.should == [1,6]
          c2.pos.should == [2,3]
          c3.pos.should == [4,5]

          c3.parent=c2
          c3.save

          c1.pos.should == [1,6]
          c2.pos.should == [2,5]
          c3.pos.should == [3,4]

          c3.parent=c1
          c3.move(:into => c2)

          c1.pos.should == [1,6]
          c2.pos.should == [2,5]
          c3.pos.should == [3,4]

          c4 = Category.create(:name => "Tube", :parent => c2)
          c5 = Category.create(:name => "Flatpanel", :parent => c2)

          c1.pos.should == [1,10]
          c2.pos.should == [2,9]
          c3.pos.should == [3,4]
          c4.pos.should == [5,6]
          c5.pos.should == [7,8]

          c5.move(:above => c3)
          c3.pos.should == [5,6]
          c4.pos.should == [7,8]
          c5.pos.should == [3,4]

        end
      end
    end

    describe 'scoping' do
      it 'should detach from list when changing scope' do
        setup
        plasma = Category.get(5)
        plasma.pos.should == [7,8]
        plasma.user_id = 1
        plasma.save

        plasma.pos.should == [1,2]
      end
    end

  end
end
