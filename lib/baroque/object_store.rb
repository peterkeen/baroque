require 'fileutils'
require 'digest/sha1'
require 'zlib'
require 'yajl/json_gem'
require 'tempfile'
require 'baroque/packfile'

module Baroque

  class Metadata
    def initialize(directory)
      @directory = directory
    end

    def path
      @directory + "/meta.json"      
    end

    def read_key(key)
      if File.exists?(path)
        File.open(path, "r") do |f|
          f.flock(File::LOCK_EX)
          contents = f.read
          meta = contents.length > 0 ? JSON.parse(contents) : {}
          return meta[key]
        end
      else
        return nil
      end
    end

    def write_key(key, val)
      if not File.exists?(path)
        `touch #{path}`
      end
      File.open(path, File::RDWR|File::CREAT, 0644) do |f|
        f.flock(File::LOCK_EX)
        contents = f.read
        meta = contents.length > 0 ? JSON.parse(contents) : {}
        meta[key] = val
        f.rewind
        f.write(meta.to_json)
        f.flush
        f.truncate(f.pos)
      end
    end
  end

  class ObjectStore
    def initialize(directory)
      @directory = directory
      @metadata = Metadata.new(directory)
    end

    def get_metadata(key)
      @metadata.read_key(key)
    end

    def set_metadata(key, val)
      @metadata.write_key(key, val)
    end

    def compress_obj(object)
      size = object.length.to_s
      header = "blob #{size}\0"
      store = header + object
      sha1 = Digest::SHA1.hexdigest(store)
      content = Zlib::Deflate.deflate(store)

      return sha1, size, content
    end

    def add_object(object)
      sha1, size, content = compress_obj(object)
      
      path = @directory + '/objects/' + sha1[0...2] + '/' + sha1[2..40]
      if !File.exists?(path)
        FileUtils.mkdir_p(@directory + '/objects/' + sha1[0...2])
        File.open(path, 'w') do |f|
          f.write(content)
        end
      end
      return sha1
    end

    def [](sha1)
      get_object(sha1)
    end

    def <<(object)
      add_object(object)
    end

    def each_packfile
      if not @packcache
        @packcache = []
        Dir.glob(@directory + '/objects/pack/pack*.pack') do |filename|
          @packcache << Baroque::Packfile.new(filename, self)
        end
      end

      @packcache.each do |pack|
        yield pack
      end

    end

    def get_object(sha1)
      path = @directory + '/objects/' + sha1[0...2] + '/' + sha1[2..40]
      if File.exists?(path)
        _get_object_from_path(path)
      elsif File.exists?(@directory + '/objects/pack/')
        each_packfile do |pack|
          if pack.has_object? sha1
            return _unpack_compressed(pack.get_object(sha1))
          end
        end
      else
        raise "Object not found: #{sha1}"
      end
    end

    def _get_object_from_path(path)
      File.open(path) do |f|
        return _unpack_compressed(f.read)
      end
    end

    def get_compressed(sha1)
      path = @directory + '/objects/' + sha1[0...2] + '/' + sha1[2..40]
      File.open(path) do |f|
        return f.read
      end
    end

    def _unpack_compressed(content)
      content = Zlib::Inflate.inflate(content)
      header, content = content.split(/\0/, 2)
      return content
    end

    def _delete_loose(key)
      path = @directory + '/objects/' + key[0...2] + '/' + key[2..40]
      File.delete(path)
    end

    def each_key(include_packed=true, include_loose=true)
      path = @directory + '/objects/'
      Dir.glob(path + "**/*") do |filename|
        next unless File.file?(filename)

        if filename =~ /objects\/pack.*\.pack/ and include_packed
          pack = Baroque::Packfile.new(filename, self)
          pack.each_object() do |sha|
            yield sha
          end
        elsif include_loose
          key = filename.gsub(path, '').gsub('/', '')
          next unless key.length == 40

          yield key
        end
      end
    end

    def each_object(include_packed=true, include_loose=true)
      path = @directory + '/objects/'
      Dir.glob(path + "**/*") do |filename|
        next unless File.file?(filename)

        if filename =~ /objects\/pack.*\.pack/ and include_packed
          pack = Baroque::Packfile.new(filename, self)
          pack.each_object() do |sha, compressed|
            yield sha, _unpack_compressed(compressed)
          end
        elsif include_loose
          key = filename.gsub(path, '').gsub('/', '')
          next unless key.length == 40

          yield key, _get_object_from_path(filename)
        end
      end
    end

    def pack_loose
      packdir = @directory + '/objects/pack/'
      FileUtils.mkdir_p(packdir)
      temp = Tempfile.new(['tmp', '.pack'], packdir)
      temp.close

      pack = Baroque::Packfile.new(temp.path, self)

      n = 0
      puts "Adding objects to pack"
      each_key(false) do |key|
        pack.add_object(key)
        n = n + 1
        if n % 1000 == 0
          puts n
        end
      end
      puts "Writing pack"
      sha = pack.write

      File.rename(temp.path, packdir + "pack-#{sha}.pack")
      File.rename(temp.path.gsub(".pack", ".idx"), packdir + "pack-#{sha}.idx")

      puts "Deleting loose"
      pack.shas.each do |sha|
        _delete_loose(sha)
      end
      
    end

  end
end
