require 'fileutils'
require 'digest/sha1'

# abstract some of the common stuff here. Maybe build an abstract StructuredFile class

module MailClient

  class StructuredFile
    def path
      raise "Not Implemented"
    end

    def magic
      raise "Not Implemented"
    end

    def write_file(io)
      raise "Not Implemented"
    end

    def size
      raise "Not Implemented"
    end

    def write_header(io)
      write_magic(io)
      write_size(io)
    end

    def write_magic(io)
      io << magic
    end

    def write_size(io)
      io << [size].pack('N')
    end

    def read_header(io)
      validate_magic(io)
      read_size(io)
    end

    def read_size(io)
      io.read(4).unpack('N')[0]
    end

    def validate_magic(io)
      test = io.read(4)
      if test != magic
        raise "Invalid magic for path #{path}"
      end
    end

    def with_lock(lock_type, mode=nil, perms=nil)
      File.open(path, mode, perms) do |file|
        file.flock(lock_type)
        yield file
      end
    end

    def open_for_write
      with_lock(File::LOCK_EX, File::RDWR|File::CREAT, 0644) do |file|
        yield file
      end
    end

    def open_for_read
      with_lock(File::LOCK_SH) do |file|
        yield file
      end
    end

    def write
      FileUtils.mkdir_p(File.dirname(path))
      open_for_write do |file|
        write_header(file)
        write_file(file)
      end
    end

    def read_bytes(io, start, num_bytes, unpack_format=nil)
      io.rewind
      io.seek(start, 0)
      _read_bytes(io, num_bytes, unpack_format)
    end

    def _read_bytes(io, num_bytes, unpack_format=nil)
      bytes = io.read(num_bytes)
      if unpack_format
        return bytes.unpack(unpack_format)
      else
        return bytes
      end
    end

    def read_groups(io, start, num_groups, bytes_per_group, unpack_format=nil)
      io.rewind
      io.seek(start, 0)
      groups = []
      num_groups.times do
        groups << _read_bytes(io, bytes_per_group, unpack_format)
      end
      groups
    end
  end

  class Indexfile < StructuredFile
    def initialize(path)
      @shas = {}
      @path = path.gsub('.pack', '.idx')
    end

    def path
      @path
    end

    def magic
      'INDX'
    end

    def size
      @shas.length
    end

    def update(sha, offset)
      @shas[sha] = offset
    end

    def write_file(io)
      write_fanout(io)
      write_shas(io)
      write_offsets(io)
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
      shas.each do |sha|
        io << [sha].pack('H*')
      end
    end

    def write_offsets(io)
      shas.each do |sha|
        io << [@shas[sha]].pack('N')
      end
    end

    def offset(sha)
      binsha = [sha].pack('H*')

      open_for_read do |file|
        num_shas = read_header(file)
        fanout = read_fanout(file)
        fanout_index = sha[0...2].to_i(16) - 1

        shas = read_groups(file, 8 + 256 * 4, num_shas, 20)

        prev_index = fanout_index > 0 ? fanout_index - 1 : 0

        imin = fanout[prev_index]
        imax = fanout[fanout_index]

        while imax > imin
          imid = ((imax + imin) / 2).to_i

          if shas[imid] < binsha
            imin = imid + 1
          else
            imax = imid
          end
        end
        if (imax == imin) && shas[imin] == binsha
          return read_bytes(file, 8 + 256 * 4 + num_shas * 20 + imin * 4, 4, 'N')[0]
        else
          return -1
        end
        
      end
    end

    def read_fanout(io)
      read_bytes(io, 8, 256*4, 'N*')
    end

  end
  
  class Packfile < StructuredFile

    def initialize(path, store)
      @shas = []
      @path = path
      @store = store
    end

    def path
      @path
    end

    def magic
      'PACK'
    end

    def size
      @shas.length
    end

    def add_object(sha)
      @shas << sha
    end

    def shas
      @shas.sort
    end

    def write_file(io)
      shasum = Digest::SHA1.new
      index = MailClient::Indexfile.new(path)
      shas.each do |sha|
        shasum << sha
        index.update(sha, io.pos)
        write_obj(io, sha, @store.get_compressed(sha))
      end
      index.write
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
      open_for_read do |file|
        num_objs = read_header(file)

        num_objs.times do
          size, sha, compressed = read_obj(file)
          yield sha, compressed
        end
      end
    end

    def has_object?(sha)
      index = MailClient::Indexfile.new(@path)
      index.offset(sha) != -1
    end

    def get_object(sha)
      index = MailClient::Indexfile.new(@path)
      offset = index.offset(sha)
      if index.offset(sha) != -1
        open_for_read do |file|
          file.seek(offset, 0)
          size, file_sha, compressed = read_obj(file)
          raise "SHA mismatch! #{sha} != #{file_sha}" if sha != file_sha
          return compressed
        end
      else
        raise "Unknown object: #{sha}"
      end
    end

  end
end
