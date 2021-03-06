# encoding: utf-8

# File:
#      modules/BootCommon.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Data to be shared between common and bootloader-specific parts of
#      bootloader configurator/installator, generic versions of bootloader
#      specific functions
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
module Yast
  module BootloaderRoutinesI386Include
    def initialize_bootloader_routines_i386(include_target)
      textdomain "bootloader"

      # general MBR reading cache

      # The last disk that was checked for the sequence
      @_old_mbr_disk = nil

      # Contents of the last read MBR
      @_old_mbr = nil

      # info about ThinkPad

      # Does MBR contain special thinkpadd stuff?
      @_thinkpad_mbr = nil

      # The last disk that was checked for the sequence
      @_old_thinkpad_disk = nil

      # Info about keeping MBR contents

      # Keep the MBR contents?
      @_keep_mbr = nil

      # Sequence specific for IBM ThinkPad laptops, see bug 86762
      @thinkpad_seq = "50e46124108ae0e461241038e074f8e2f458c332edb80103ba8000cd13c3be05068a04240cc0e802c3"
    end

    # Get the contents of the MBR of a disk
    # @param [String] disk string the disk to be checked
    # @return strign the contents of the MBR of the disk in hexa form
    def GetMBRContents(disk)
      if @_old_mbr == nil || disk != @_old_mbr_disk
        @_old_mbr_disk = disk
        out = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("dd if=%1 bs=512 count=1 | od -v -t x1 -", disk)
          )
        )
        if Ops.get_integer(out, "exit", 0) != 0
          Builtins.y2error("Reading MBR contents failed")
          return nil
        end
        mbr = Ops.get_string(out, "stdout", "")
        mbrl = Builtins.splitstring(mbr, "\n")
        mbrl = Builtins.maplist(mbrl) do |s|
          l = Builtins.splitstring(s, " ")
          Ops.set(l, 0, "")
          Builtins.mergestring(l, "")
        end
        mbr = Builtins.mergestring(mbrl, "")
        Builtins.y2debug("MBR contents: %1", mbr)
        @_old_mbr = mbr
      end
      @_old_mbr
    end

    # Does MBR of the disk contain special IBM ThinkPad stuff?
    # @param [String] disk string the disk to be checked
    # @return [Boolean] true if it is MBR
    def ThinkPadMBR(disk)
      if @_thinkpad_mbr == nil || disk != @_old_thinkpad_disk
        @_old_thinkpad_disk = disk
        mbr = GetMBRContents(disk)
        x02 = Builtins.tointeger(Ops.add("0x", Builtins.substring(mbr, 4, 2)))
        x03 = Builtins.tointeger(Ops.add("0x", Builtins.substring(mbr, 6, 2)))
        x0e = Builtins.substring(mbr, 28, 2)
        x0f = Builtins.substring(mbr, 30, 2)
        Builtins.y2internal("Data: %1 %2 %3 %4", x02, x03, x0e, x0f)
        @_thinkpad_mbr = Ops.less_or_equal(2, x02) &&
          Ops.less_or_equal(x02, Builtins.tointeger("0x63")) &&
          Ops.less_or_equal(2, x03) &&
          Ops.less_or_equal(x03, Builtins.tointeger("0x63")) &&
          Builtins.tolower(x0e) == "4e" &&
          Builtins.tolower(x0f) == "50"
      end
      Builtins.y2milestone(
        "MBR of %1 contains ThinkPad sequence: %2",
        disk,
        @_thinkpad_mbr
      )
      @_thinkpad_mbr
    end

    # Keep the MBR contents on the specified disk? Check whether the contents
    # should be kept because ot contains vendor-specific data
    # @param [String] disk string the disk to be checked
    # @return [Boolean] true to keep the contents
    def KeepMBR(disk)
      # FIXME: see bug #464485 there is problem with detection of
      # MBR the 3rd byte is 0 after recovery thinkpad notebook with
      # recovery CD, next missing cooperate with Lenovo there also
      # missing any specification about Lenovo's changes in MBR

      Builtins.y2milestone("Skip checking of MBR for thinkpad sequence")

      false
    end

    # Add the partition holding firmware to bootloader?
    # @param [String] disk string the disk to be checked
    # @return [Boolean] true if firmware partition is to be added
    def AddFirmwareToBootloader(disk)
      !ThinkPadMBR(disk)
    end

    # Display bootloader summary
    # @return a list of summary lines
    def i386Summary
      ret = Summary()
      order_sum = DiskOrderSummary()
      ret = Builtins.add(ret, order_sum) if order_sum != nil
      deep_copy(ret)
    end

    # Propose the boot loader location for i386 (and similar) platform
    def i386LocationProposal
      if !@was_proposed
        DetectDisks()
        @del_parts = BootStorage.getPartitionList(
          :deleted,
          getLoaderType(false)
        )
        # check whether edd is loaded; if not: load it
        lsmod_command = "lsmod | grep edd"
        Builtins.y2milestone("Running command %1", lsmod_command)
        lsmod_out = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), lsmod_command)
        )
        Builtins.y2milestone("Command output: %1", lsmod_out)
        edd_loaded = Ops.get_integer(lsmod_out, "exit", 0) == 0
        if !edd_loaded
          command = "/sbin/modprobe edd"
          Builtins.y2milestone("Loading EDD module, running %1", command)
          out = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )
          Builtins.y2milestone("Command output: %1", out)
        end
      end

      # refresh device map
      if (BootStorage.device_mapping == nil ||
          Builtins.size(BootStorage.device_mapping) == 0) &&
          getLoaderType(false) == "grub"
        BootStorage.ProposeDeviceMap
      end

      if DisksChanged() && !Mode.autoinst
        if askLocationResetPopup(@loader_device)
          @selected_location = nil
          @loader_device = nil
          Builtins.y2milestone("Reconfiguring locations")
          DetectDisks()
        end
      end

      nil
    end


    # Do updates of MBR after the bootloader is installed
    # @return [Boolean] true on success
    def PostUpdateMBR
      ret = true
      if ThinkPadMBR(@mbrDisk)
        if @loader_device != @mbrDisk
          command = Builtins.sformat("/usr/lib/YaST2/bin/tp_mbr %1", @mbrDisk)
          Builtins.y2milestone("Running command %1", command)
          out = Convert.to_map(
            SCR.Execute(path(".target.bash_output"), command)
          )
          exit = Ops.get_integer(out, "exit", 0)
          Builtins.y2milestone("Command output: %1", out)
          ret = ret && 0 == exit
        end
      end

      ret
    end
  end
end
