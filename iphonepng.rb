#!/usr/bin/env ruby
# copyright @ stanley cai <stanley.w.cai@gmail.com>
#
# impressed by Axel E. Brzostowski iPhone PNG Images Normalizer in Python
# Jeff talked about the PNG formats in more details in his blog
# http://iphonedevelopment.blogspot.com/2008/10/iphone-optimized-pngs.html
#
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
=begin
  TODO unit test
=end

require "zlib"

def decompress(data)
  # make zlib not check the header
  zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
  buf = zstream.inflate(data)
  zstream.finish
  zstream.close
  buf
end

def compress(data)
  Zlib::Deflate.deflate(data)
end

PNG_HEADER = "\x89PNG\r\n\x1a\n"

def normalize(oldPNG)
  if oldPNG[0, 8] != PNG_HEADER then
    puts "Corrupted PNG file"
    return nil
  end
  
  newPNG = String.new(oldPNG[0, 8])
  pos = 8
  sections = []

  while pos < oldPNG.length
    
    # use "N" instead of "L", using network endian not native endian
    length = oldPNG[pos, 4].unpack('N')[0]
    type = oldPNG[pos+4, 4]
    data = oldPNG[pos+8, length]
    crc = oldPNG[pos+8+length, 4].unpack('N')[0]
    pos += length + 12
    
    next if type == "CgBI"
    
    if type == "IHDR" then
      width = data[0, 4].unpack("N")[0]
      height = data[4, 4].unpack("N")[0]
    end

    if type == 'IDAT' && sections.size > 0 && sections.last.first == 'IDAT'
      # Append to the previous IDAT
      sections.last[1] += length
      sections.last[2] += data
    else
      sections << [type, length, data, crc, width, height]
    end

    break if type == "IEND"
    
  end

  sections.map do |(type, length, data, crc, width, height)|

    if type == "IDAT" then

      bufSize = width * height * 4 + height
      data = decompress(data[0, bufSize])

      # duplicate the content of old data at first to avoid creating too many string objects
      newdata = String.new(data)
      pos = 0

      for y in 0...height
        newdata[pos] = data[pos, 1]
        pos += 1
        for x in 0...width
          newdata[pos+0] = data[pos+2, 1]
          newdata[pos+1] = data[pos+1, 1]
          newdata[pos+2] = data[pos+0, 1]
          newdata[pos+3] = data[pos+3, 1]
          pos += 4
        end
      end

      data = compress(newdata)
      length = data.length
      crc = Zlib::crc32(type)
      crc = Zlib::crc32(data, crc)
      crc = (crc + 0x100000000) % 0x100000000
    end

    newPNG += [length].pack("N") + type + (data || '') + [crc].pack("N")

  end

  newPNG
end


def normalize_png(filename)
  puts "#{filename}"
  File.open(filename, 'rb') do |file|
    newPNG = normalize(file.read())
    if newPNG != nil then
      newFilename = File.basename(filename, ".*") + "_norm" + File.extname(filename)
      File.new(newFilename, 'wb').write(newPNG)
    end
  end
end

# ARGV[0] = '.' 
ARGV.each {|a| Dir.glob("#{a}/*.png").each {|file| normalize_png(file)}}
puts "Done."