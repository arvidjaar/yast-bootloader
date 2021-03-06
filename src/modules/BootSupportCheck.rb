# encoding: utf-8

# File:
#      modules/BootSupportCheck.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Check whether the current system setup is a supported configuration
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#
# $Id: BootCommon.ycp 49686 2008-08-05 10:04:46Z juhliarik $
#
require "yast"

module Yast
  class BootSupportCheckClass < Module
    def main

      textdomain "bootloader"

      Yast.import "Bootloader"
      Yast.import "Arch"
      Yast.import "Storage"
      Yast.import "Region"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "FileUtils"

      # List of problems found during last check
      @detected_problems = []
    end

    # Add a new problem description to the list of found problems
    def AddNewProblem(description)
      @detected_problems = Builtins.add(@detected_problems, description)

      nil
    end

    # List detected problems
    # Always run SystemSupported before calling this function
    # @return [Boolean] a list of problems, empty if no was found
    def DetectedProblems
      deep_copy(@detected_problems)
    end


    # Formated string of detected problems
    # Always run SystemSupported before calling this function
    # @return [Boolean] a list of problems, empty if no was found
    def StringProblems
      ret = ""
      if Ops.greater_than(Builtins.size(@detected_problems), 0)
        Builtins.foreach(@detected_problems) do |s|
          ret = Ops.add(Ops.add(ret, s), "\n")
        end
      end

      ret
    end


    # Check that bootloader is known and supported
    def KnownLoader
      if !Builtins.contains(
          ["grub", "grub2", "grub2-efi", "elilo", "ppc", "zipl", "none"],
          Bootloader.getLoaderType
        )
        if Bootloader.getLoaderType != "lilo"
          Builtins.y2error("Unknown bootloader: %1", Bootloader.getLoaderType)
          AddNewProblem(
            Builtins.sformat(
              _("Unknown bootloader: %1"),
              Bootloader.getLoaderType
            )
          )
        else
          Builtins.y2error("LILO bootloader: %1", Bootloader.getLoaderType)
          AddNewProblem(_("LILO bootloader is not supported"))
        end
        return false
      end
      true
    end

    # Check if elilo is supported
    def checkElilo
      cmd = "modprobe efivars 2>/dev/null"
      ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      # bnc#581213 - x86-64/UEFI: "Unsupported combination of hardware platform x86_64 and bootloader elilo"
      if FileUtils.Exists("/sys/firmware/efi/systab")
        return true
      else
        return false
      end
    end



    # Check that bootloader matches current hardware
    def CorrectLoaderType
      lt = Bootloader.getLoaderType
      return true if lt == "none"

      return true if Arch.s390 && lt == "zipl"
      return true if Arch.ppc && lt == "ppc"
      return true if Arch.ia64 && lt == "elilo"
      if Arch.i386 || Arch.x86_64
        if checkElilo
          return true if lt == "elilo" || lt == "grub2-efi"
        else
          return true if lt == "grub" || lt == "lilo" || lt == "grub2"
        end
      end
      Builtins.y2error(
        "Unsupported combination of hardware platform %1 and bootloader %2",
        Arch.architecture,
        lt
      )
      AddNewProblem(
        Builtins.sformat(
          _("Unsupported combination of hardware platform %1 and bootloader %2"),
          Arch.architecture,
          lt
        )
      )
      false
    end

    #  * Checks for GPT partition table
    #  // FIXME adapt for ELILO if needed
    def GptPartitionTable
      ret = true
      tm = Storage.GetTargetMap
      devices = [BootStorage.BootPartitionDevice]
      # TODO add more devices
      Builtins.foreach(devices) do |dev|
        p_dev = Storage.GetDiskPartition(dev)
        num = BootCommon.myToInteger(Ops.get(p_dev, "nr"))
        mbr_dev = Ops.get_string(p_dev, "disk", "")
        label = Ops.get_string(tm, [mbr_dev, "label"], "")
        Builtins.y2milestone("Label: %1", label)
        Builtins.y2internal("Num: %1", num)
        if label == "gpt"
          if Ops.greater_than(num, 3)
            Builtins.y2error(
              "Partition number > 3 is being used for booting with GPT partition table"
            )
            AddNewProblem(
              _(
                "Partition number > 3 is being used for booting with GPT partition table"
              )
            )
            ret = false
          end
        end
      end
      ret
    end


    # Check if boot partition exist
    # check if not on raid0
    #
    # @return [Boolean] true on success


    def check_BootDevice
      result = true
      boot_device = ""

      devices = Storage.GetTargetMap

      boot_device = BootCommon.getBootPartition

      boot_disk = BootCommon.getBootDisk
      # if (BootStorage::BootPartitionDevice == BootStorage::RootPartitionDevice)
      # AddNewProblem (_("Doesn't exist separete /boot partition"));

      found_boot = false
      # check if boot device is on raid0
      Builtins.foreach(devices) do |k, v|
        # check if boot disk is iscsi disk
        # bnc#393928: Installing root system on iscsi disk makes the system useless
        if k == boot_disk
          # if "iscsi" is true
          if Ops.get_boolean(v, "iscsi", false)
            AddNewProblem(
              Builtins.sformat(
                _("The boot device is on iSCSI disk: %1. System may not boot."),
                k
              )
            )
            Builtins.y2error(
              "The boot partition: %1 is on iscsi disk: %2",
              boot_device,
              k
            )
            result = false
          end
        end
        Builtins.foreach(Ops.get_list(v, "partitions", [])) do |p|
          if Ops.get_string(p, "device", "") == boot_device
            if Ops.get_string(p, "raid_type", "") != "raid1" &&
                Ops.get(p, "type") == :sw_raid
              AddNewProblem(
                Builtins.sformat(
                  _(
                    "The boot device is on raid type: %1. System will not boot."
                  ),
                  Ops.get_string(p, "raid_type", "")
                )
              )
              Builtins.y2error(
                "The boot device: %1 is on raid type: %2",
                boot_device,
                Ops.get_string(p, "raid_type", "")
              )
              result = false
              raise Break
            else
              # bnc#501043 added check for valid configuration
              if Ops.get_string(p, "raid_type", "") == "raid1" &&
                  Ops.get(p, "type") == :sw_raid
                if Builtins.tolower(Ops.get_string(p, "fstype", "")) == "md raid" &&
                    Ops.get(BootCommon.globals, "boot_mbr", "false") != "true"
                  AddNewProblem(
                    _(
                      "The boot device is on software RAID1. Select other bootloader location, e.g. Master Boot Record"
                    )
                  )
                  Builtins.y2error(
                    "Booting from soft-raid: %1 and bootloader setting are not valid: %2",
                    p,
                    BootCommon.globals
                  )
                  result = false
                  raise Break
                else
                  found_boot = true
                  Builtins.y2milestone("Valid configuration for soft-raid")
                end
              else
                found_boot = true
                Builtins.y2milestone(
                  "The boot device: %1 is on raid: %2",
                  boot_device,
                  Ops.get_string(p, "raid_type", "")
                )
              end
            end
            if Ops.get(p, "used_fs") == :xfs
              AddNewProblem(
                _(
                  "The /boot directory is on an XFS filesystem. System may not boot."
                )
              )
              Builtins.y2error("The /boot directory is on an XFS filesystem")
              result = false
              raise Break
            else
              found_boot = true
              Builtins.y2milestone("/boot filesystem is OK")
              raise Break
            end
          end
        end
        raise Break if !result || found_boot
      end if boot_device != ""
      result
    end

    # Check if there is bios_id
    # if not show warning
    #
    # @return [Boolean] true on success

    def CheckBios_ID
      ret = true
      if BootStorage.bois_id_missing
        AddNewProblem(
          _(
            "It was not possible to determine the exact order of disks for device map. The order of disks can be changed in \"Boot Loader Installation Details\""
          )
        )
        ret = false
      end
      ret
    end


    # Check that the root partition is reachable
    def RootPartition
      true
    end

    # GRUB-related check
    def GRUB
      ret = GptPartitionTable()
      ret = check_BootDevice if ret
      ret = CheckBios_ID() if ret
      ret
    end

    # GRUB2-related check
    def GRUB2
      GRUB()
    end

    # GRUB2EFI-related check
    def GRUB2EFI
      true
    end

    # ELILO related check
    def ELILO
      true
    end

    # ZIPL related check
    def ZIPL
      true
    end

    # PPC related check
    def PPC
      true
    end

    # Check if the system configuraiton is supported
    # Also sets the founds problems into internal variable
    # Always run this function before calling DetectedProblems()
    # @return [Boolean] true if supported
    def SystemSupported
      @detected_problems = []

      # check if the bootloader is known and supported
      supported = KnownLoader()

      lt = Bootloader.getLoaderType
      return true if lt == "none"

      # detect correct bootloader type
      supported = CorrectLoaderType() && supported

      # check whether root partition can be reached
      supported = RootPartition() && supported

      # check specifics for individual loaders
      if lt == "grub"
        supported = GRUB() && supported
      elsif lt == "elilo"
        supported = ELILO() && supported
      elsif lt == "ppc"
        supported = PPC() && supported
      elsif lt == "zipl"
        supported = ZIPL() && supported
      elsif lt == "grub2"
        supported = GRUB2() && supported
      elsif lt == "grub2-efi"
        supported = GRUB2EFI() && supported
      end

      Builtins.y2milestone("Configuration supported: %1", supported)
      supported
    end


    def EndOfBootOrRootPartition
      part = Storage.GetEntryForMountpoint("/boot")
      part = Storage.GetEntryForMountpoint("/") if Builtins.isempty(part)

      device = Ops.get_string(part, "device", "")
      Builtins.y2milestone("device:%1", device)

      end_cyl = Region.End(Ops.get_list(part, "region", []))

      cyl_size = 82252800
      target_map = Storage.GetTargetMap
      Builtins.foreach(target_map) do |dev, disk|
        if Builtins.find(Ops.get_list(disk, "partitions", [])) do |p|
            Ops.get_string(p, "device", "") == device
          end != nil
          cyl_size = Ops.get_integer(disk, "cyl_size", 82252800)
        end
      end

      ret = Ops.multiply(end_cyl, cyl_size)

      Builtins.y2milestone(
        "end_cyl:%1 cyl_size:%2 end:%3",
        end_cyl,
        cyl_size,
        ret
      )
      ret
    end

    publish :function => :DetectedProblems, :type => "list <string> ()"
    publish :function => :StringProblems, :type => "string ()"
    publish :function => :check_BootDevice, :type => "boolean ()"
    publish :function => :GRUB, :type => "boolean ()"
    publish :function => :GRUB2, :type => "boolean ()"
    publish :function => :GRUB2EFI, :type => "boolean ()"
    publish :function => :SystemSupported, :type => "boolean ()"
    publish :function => :EndOfBootOrRootPartition, :type => "integer ()"
  end

  BootSupportCheck = BootSupportCheckClass.new
  BootSupportCheck.main
end
