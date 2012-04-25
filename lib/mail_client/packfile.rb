require 'fileutils'
require 'digest/sha1'

module MailClient

  class Indexfile
    def initialize(path)
      @shas = {}
      @path = path.gsub('.pack', '.idx')
    end

    def update(sha, offset)
      @shas[sha] = offset
    end

    def write
      shasum = Digest::SHA1.new
      File.open(@path, File::RDWR|File::CREAT, 0644) do |file|
        file.flock(File::LOCK_EX)
        write_header(file)
        write_fanout(file)
        write_shas(file)
        write_offsets(file)
        write_shasum(file)
      end
    end

    def write_header(io)
      io << 'INDX'
      io << [@shas.length].pack('N')
    end

    def write_fanout(io)
      fanout = calculate_fanout
      fanout.each do |num_objs|
        io << [num_objs].pack('N')
      end
    end

    def calculate_fanout
      num_by_prefix = {}
      shas.each do |sha|
        num_by_prefix[sha[0...2]] ||= 0
        num_by_prefix[sha[0...2]] += 1
      end

      fanout = []
      sum = 0
      (0..255).each do |prefix|
        if num_by_prefix.has_key? prefix.to_s(16)
          sum += num_by_prefix[prefix.to_s(16)]
        end
        fanout[prefix] = sum
      end

      fanout
      
    end

    def shas
      @shas.keys.sort
    end

    def write_shas(io)
    end

    def write_offsets(io)
    end

    def write_shasum(io)
    end
  end
  
  class Packfile

    def initialize(path)
      @shas = []
      @path = path
    end

    def add_object(sha)
      @shas << sha
    end

    def shas
      @shas.sort
    end

    def write(store)
      FileUtils.mkdir_p(File.dirname(@path))
      shasum = Digest::SHA1.new
      File.open(@path, File::RDWR|File::CREAT, 0644) do |file|
        file.flock(File::LOCK_EX)
        write_header(file)
        shas.each do |sha|
          shasum << sha
          write_obj(file, sha, store.get_compressed(sha))
        end
      end
      shasum.hexdigest
    end

    def write_obj(io, sha, obj)
      io << [sha].pack('H*')
      size = obj.length
      byte = size & 0x7f
      size >>= 7

      while size > 0
        io << (byte | 0x80).chr
        byte = size & 0x7f
        size >>= 7
      end
      io << byte.chr
      io << obj
    end

    def read_obj(io)
      sha = io.read(20)
      e = 0
      size = 0
      while true
        byte = io.read(1)
        if (byte.ord & 0x80) == 128
          size += ((byte.ord & 0x7f) << e)
          e += 7
        else
          size += ((byte.ord & 0x7f) << e)
          break
        end
      end
      return size, sha.unpack('H*')[0], io.read(size)
    end

    def each_object
      File.open(@path) do |file|
        file.flock(File::LOCK_SH)
        num_objs = read_header(file)

        num_objs.times do
          size, sha, compressed = read_obj(file)
          yield sha, compressed
        end
      end
    end

    def read_header(io)
      magic = io.read(4)
      if magic != 'PACK'
        raise "Invalid pack: #{@path}"
      end

      num_objs = io.read(4).unpack('N')[0]
      return num_objs
    end

    def write_header(io)
      io << 'PACK'
      io << [@shas.length].pack('N')
    end
  end
end
