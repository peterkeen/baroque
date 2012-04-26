require 'spec_helper'
require 'mail_client/packfile'

def sha
  'f19bdcb943aea27be0e0e9e7a06910a625fb8f0e'
end

class MockObjectStore
  def get_compressed(sha)
    'compressed'
  end
end

describe MailClient::Packfile do
  describe "#add_object" do
    it "should add a sha1 to the list to be packed" do
      pack = MailClient::Packfile.new("", nil)
      pack.add_object("abc")
      pack.shas.should eq ['abc']
    end
  end

  describe "#shas" do
    it "should return the shas in sorted order" do
      pack = MailClient::Packfile.new("", nil)
      pack.add_object('def')
      pack.add_object('abc')

      pack.shas.should eq ['abc', 'def']
    end
  end

  describe "#write_header" do
    it "should write the correct header" do
      pack = MailClient::Packfile.new("", nil)
      pack.add_object('abc')

      s = StringIO.new
      pack.write_header(s)
      s.rewind

      s.read(8).should eq "PACK\x00\x00\x00\x01"
    end

  end

  describe "#write_obj" do
    it "should write the size of the object" do
      pack = MailClient::Packfile.new("", nil)

      s = StringIO.new
      pack.write_obj(s, sha, 'content')
      s.rewind
      s.seek(20, 0)
      s.read(1).should eq "\x07"
    end

    it "should write the given content to the stream" do
      pack = MailClient::Packfile.new("", nil)
      s = StringIO.new
      pack.write_obj(s, sha, 'content')
      s.rewind
      s.seek(21)
      s.read.should eq 'content'
    end

    it "should write the size of the object even if it is bigger than 128 bytes" do
      pack = MailClient::Packfile.new("", nil)
      s = StringIO.new
      pack.write_obj(s, sha, 'content' * 100)
      s.rewind
      s.seek(20, 0)
      s.read(2).should eq "\xBC\x05"
    end

    it "should write the given sha as binary" do
      pack = MailClient::Packfile.new("", nil)
      s = StringIO.new
      pack.write_obj(s, sha, 'content')
      s.rewind
      s.read(28).should eq "\xF1\x9B\xDC\xB9C\xAE\xA2{\xE0\xE0\xE9\xE7\xA0i\x10\xA6%\xFB\x8F\x0E\x07content"
    end
  end

  describe "#read_obj" do
    it "should read the written contents" do
      pack = MailClient::Packfile.new("", nil)
      s = StringIO.new
      obj = 'content' * 100
      pack.write_obj(s, sha, obj)
      s.rewind
      pack.read_obj(s).should eq [700, sha, obj]
    end
  end

  describe "#write" do
    it "should write a complete file" do
      dir = Dir.mktmpdir
      pack = MailClient::Packfile.new("#{dir}/pack-foo.pack", MockObjectStore.new)
      pack.add_object(sha)
      pack.write

      File.exists?("#{dir}/pack-foo.pack").should eq true
      File.exists?("#{dir}/pack-foo.idx").should eq true
    end

  end

  describe "#get_object" do
    it "should look in the index for the given sha" do 
      dir = Dir.mktmpdir
      pack = MailClient::Packfile.new("#{dir}/pack-foo.pack", MockObjectStore.new)
      pack.add_object(sha)
      pack.write

      pack.get_object(sha).should eq 'compressed'
    end

    it "should raise an exception when it can't find a given sha" do
      dir = Dir.mktmpdir
      pack = MailClient::Packfile.new("#{dir}/pack-foo.pack", MockObjectStore.new)
      pack.add_object(sha)
      pack.write

      pack.has_object?('deadbeef' * 5).should raise_error
    end
  end

  describe "#has_object" do

    it "should look in the index for the given sha" do
      dir = Dir.mktmpdir
      pack = MailClient::Packfile.new("#{dir}/pack-foo.pack", MockObjectStore.new)
      pack.add_object(sha)
      pack.write

      pack.has_object?(sha).should eq true
      pack.has_object?('deadbeef' * 5).should eq false
    end
  end

end
  
