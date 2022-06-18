#!/usr/bin/ruby
# Create display override file to force Mac OS X to use RGB mode for Display
# see http://embdev.net/topic/284710

require 'base64'

data=`ioreg -l -d0 -w 0 -r -c AppleDisplay`

edids=data.scan(/IODisplayEDID.*?<([a-z0-9]+)>/i).flatten
vendorids=data.scan(/DisplayVendorID.*?([0-9]+)/i).flatten
productids=data.scan(/DisplayProductID.*?([0-9]+)/i).flatten

displays = []
edids.each_with_index do |edid, i|
    disp = { "edid_hex"=>edid, "vendorid"=>vendorids[i].to_i, "productid"=>productids[i].to_i }
    displays.push(disp)
end

# Process all displays
if displays.length > 1
    puts "Found %d displays!  You should only install the override file for the one which" % displays.length
    puts "is giving you problems.","\n"
elsif displays.length == 0
    puts "No display data found!  Are any external displays connected?"
    puts "\nNote: Apple Silicon (arm64) devices are currently unsupported, as the standard"
    puts "method of retrieving display information does not work."
end
displays.each do |disp|
    # Retrieve monitor model from EDID display descriptor
    i = disp["edid_hex"].index('000000fc00')
    if i.nil?
        monitor_name = "Display"
    else
        # The monitor name is stored in (up to) 13 bytes of text following 00 00 00 fc 00.
        # If the name is shorter than 13 bytes, it is terminated with a newline (0a) and then padded with spaces.
        monitor_name = [disp["edid_hex"][i + 10, 26].to_s].pack("H*")
        monitor_name.rstrip!            # remove trailing newline/spaces
    end

    puts "Found display '#{monitor_name}': vendor ID=#{disp["vendorid"]} (0x%x), product ID=#{disp["productid"]} (0x%x)" %
            [disp["vendorid"], disp["productid"]]
    puts "Raw EDID data:\n#{disp["edid_hex"]}"

    bytes=disp["edid_hex"].scan(/../).map{|x|Integer("0x#{x}")}.flatten

    puts "Setting color support to RGB 4:4:4 only"
    bytes[24] &= ~(0b11000)

    puts "Number of extension blocks: #{bytes[126]}"
    puts "removing extension block"
    bytes = bytes[0..127]
    bytes[126] = 0

    bytes[127] = (0x100-(bytes[0..126].reduce(:+) % 256)) % 256
    puts
    puts "Recalculated checksum: 0x%x" % bytes[127]
    puts "new EDID:\n#{bytes.map{|b|"%02X"%b}.join}"

    Dir.mkdir("DisplayVendorID-%x" % disp["vendorid"]) rescue nil
    filename = "DisplayVendorID-%x/DisplayProductID-%x" % [disp["vendorid"], disp["productid"]]
    puts "Output file: #{Dir.pwd}/#{filename}"
    f = File.open(filename, 'w')
    f.write '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">'
    f.write "
<dict>
  <key>DisplayProductName</key>
  <string>#{monitor_name} - forced RGB mode (EDID override)</string>
  <key>IODisplayEDID</key>
  <data>#{Base64.encode64(bytes.pack('C*'))}</data>
  <key>DisplayVendorID</key>
  <integer>#{disp["vendorid"]}</integer>
  <key>DisplayProductID</key>
  <integer>#{disp["productid"]}</integer>
</dict>
</plist>"
    f.close
    puts "\n"
end             # displays.each
