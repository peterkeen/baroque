require 'spec_helper'
require 'baroque/object_store'
require 'baroque/packfile'
require 'digest/sha1'

def obj_path(dir, sha)
  path = dir + "/objects/" + sha[0...2] + "/" + sha[2..40]
  path
end
  

describe Baroque::ObjectStore do
  describe "#add_object" do
    it "should add objects at the correct path" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      sha = o.add_object("hi there")

      File.exists?(obj_path(dir, sha)).should eq true
    end
  end

  describe "#get_object" do
    it "should get an object" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      sha = o.add_object("hi there")

      o.get_object(sha).should eq 'hi there'
    end
  end

  describe "#each_object" do
    it "should iterate each object" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      o.add_object("hi there")
      o.add_object("good bye")
      
      objs = []
      o.each_object do |sha, obj|
        objs << obj
      end

      objs.sort.should eq ['good bye', 'hi there']
    end

    it "should include packed objects" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      o.add_object("hi there")
      sha = o.add_object("good bye")
      pack = Baroque::Packfile.new(dir + "/objects/pack/pack-foo.pack", o)
      pack.add_object(sha)
      pack.write

      objs = []
      o.each_object do |sha, obj|
        objs << obj
      end

      objs.sort.should eq ['good bye', 'good bye', 'hi there']      
    end

    it "should write an index file" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      o.add_object("hi there")
      sha = o.add_object("good bye")
      pack = Baroque::Packfile.new(dir + "/objects/pack/pack-foo.pack", o)
      pack.add_object(sha)
      pack.write

      File.exists?(dir + '/objects/pack/pack-foo.idx').should eq true

    end
  end

  describe "#pack_loose" do
    it "should pack all of the loose objects" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      sha = o.add_object("hi there")
      o.pack_loose

      objs = []
      o.each_object(true, false) do |sha, obj|
        objs << obj
      end

      objs.sort.should eq ['hi there']
      
    end

    it "should delete all of the loose objects" do
      dir = Dir.mktmpdir
      o = Baroque::ObjectStore.new(dir)
      sha = o.add_object("hi there")
      o.pack_loose

      File.exists?(dir + "/objects/" + sha[0...2] + '/' + sha[2..40]).should eq false

    end
  end
end
      
