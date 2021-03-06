# encoding: utf-8

# File:
#      modules/BootGRUB2.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for GRUB2 configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id: BootGRUB.ycp 63508 2011-03-04 12:53:27Z jreidinger $
#
require "yast"

module Yast
  class BootGRUB2Class < Module
    def main
      Yast.import "UI"

      textdomain "bootloader"

      Yast.import "BootArch"
      Yast.import "BootCommon"
      Yast.import "BootStorage"
      Yast.import "Kernel"
      Yast.import "Mode"
      Yast.import "Stage"
      Yast.import "Storage"
      Yast.import "StorageDevices"
      Yast.import "Pkg"
      Yast.import "HTML"
      Yast.import "Initrd"
      Yast.import "Product"

      # includes
      # for shared some routines with grub
      Yast.include self, "bootloader/grub2/misc.rb"
      # for simplified widgets than other
      Yast.include self, "bootloader/grub2/dialogs.rb"
      BootGRUB2()
    end

    # general functions

    # Propose global options of bootloader
    def StandardGlobals
      {
        "timeout"   => "8",
        "default"   => "0",
        "vgamode"   => "",
        "gfxmode"   => "auto",
        "terminal"  => "gfxterm",
        "os_prober" => "true"
      }
    end

    # Read settings from disk
    # @param [Boolean] reread boolean true to force reread settings from system
    # @param [Boolean] avoid_reading_device_map do not read new device map from file, use
    # internal data
    # @return [Boolean] true on success
    def Read(reread, avoid_reading_device_map)
      BootCommon.InitializeLibrary(reread, "grub2")
      BootCommon.ReadFiles(avoid_reading_device_map) if reread
      # TODO: check if necessary for grub2
      grub_DetectDisks
      ret = BootCommon.Read(false, avoid_reading_device_map)

      # TODO: check if necessary for grub2
      # refresh device map if not read
      if BootStorage.device_mapping == nil ||
          Builtins.size(BootStorage.device_mapping) == 0
        BootStorage.ProposeDeviceMap
      end

      if Mode.normal
        md_value = BootStorage.addMDSettingsToGlobals
        pB_md_value = Ops.get(BootCommon.globals, "boot_md_mbr", "")
        if md_value != pB_md_value
          if pB_md_value != ""
            disks = Builtins.splitstring(pB_md_value, ",")
            disks = Builtins.filter(disks) { |v| v != "" }
            if Builtins.size(disks) == 2
              BootCommon.enable_md_array_redundancy = true
              md_value = ""
            end
            Builtins.y2milestone(
              "disks from md array (perl Bootloader): %1",
              disks
            )
          end
          if md_value != ""
            BootCommon.enable_md_array_redundancy = false
            Ops.set(BootCommon.globals, "boot_md_mbr", md_value)
            Builtins.y2milestone(
              "Add md array to globals: %1",
              BootCommon.globals
            )
          end
        end
      end

      ret
    end

    # Update read settings to new version of configuration files
    def Update
      Read(true, true)

      #we don't handle sections, grub2 section create them for us
      #BootCommon::UpdateSections ();
      BootCommon.UpdateGlobals

      nil
    end
    # Write bootloader settings to disk
    # @return [Boolean] true on success
    def Write
      ret = BootCommon.UpdateBootloader

      #TODO: InstallingToFloppy ..
      if BootCommon.location_changed
        # bnc #461613 - Unable to boot after making changes to boot loader
        # bnc #357290 - module rewrites grub generic code when leaving with no changes, which may corrupt grub
        grub_updateMBR

        grub_ret = BootCommon.InitializeBootloader
        grub_ret = false if grub_ret == nil

        Builtins.y2milestone("GRUB return value: %1", grub_ret)
        ret = ret && grub_ret
        ret = ret && BootCommon.PostUpdateMBR
      end

      ret
    end

    # Reset bootloader settings
    # @param [Boolean] init boolean true to repropose also device map
    def Reset(init)
      return if Mode.autoinst
      BootCommon.Reset(init)

      nil
    end

    # Propose bootloader settings

    def Propose
      if BootCommon.was_proposed
        # workaround autoyast config is Imported thus was_proposed always set 
        if Mode.autoinst
          Builtins.y2milestone(
            "autoinst mode we ignore meaningless was_proposed as it always set"
          )
        else
          Builtins.y2milestone(
            "calling Propose with was_proposed set is really bogus, clear it to force a re-propose"
          )
          return
        end
      end

      if BootCommon.globals == nil || Builtins.size(BootCommon.globals) == 0
        BootCommon.globals = StandardGlobals()
      else
        BootCommon.globals = Convert.convert(
          Builtins.union(BootCommon.globals, StandardGlobals()),
          :from => "map",
          :to   => "map <string, string>"
        )
      end

      grub_LocationProposal

      swap_sizes = BootCommon.getSwapPartitions
      swap_parts = Builtins.maplist(swap_sizes) { |name, size| name }
      swap_parts = Builtins.sort(swap_parts) do |a, b|
        Ops.greater_than(Ops.get(swap_sizes, a, 0), Ops.get(swap_sizes, b, 0))
      end

      largest_swap_part = Ops.get(swap_parts, 0, "")

      resume = BootArch.ResumeAvailable ? largest_swap_part : ""
      # try to use label or udev id for device name... FATE #302219
      if resume != "" && resume != nil
        resume = BootStorage.Dev2MountByDev(resume)
      end
      Ops.set(
        BootCommon.globals,
        "append",
        BootArch.DefaultKernelParams(resume)
      )
      Ops.set(
        BootCommon.globals,
        "append_failsafe",
        BootArch.FailsafeKernelParams
      )
      Ops.set(
        BootCommon.globals,
        "distributor",
        Ops.add(Ops.add(Product.short_name, " "), Product.version)
      )
      BootCommon.kernelCmdLine = Kernel.GetCmdLine

      Builtins.y2milestone("Proposed globals: %1", BootCommon.globals) 

      # Let grub2 scripts detects correct root= for us. :)
      # BootCommon::globals["root"] = BootStorage::Dev2MountByDev(BootStorage::RootPartitionDevice);

      # We don't set vga= if Grub2 gfxterm enabled, because the modesettings
      # will be delivered to kernel by Grub2's gfxpayload set to "keep"
      #if (BootArch::VgaAvailable () && Kernel::GetVgaType () != "")
      #{
      #    BootCommon::globals["vgamode"] = Kernel::GetVgaType ();
      #}

      nil
    end

    # FATE#303643 Enable one-click changes in bootloader proposal
    #
    #
    def urlLocationSummary
      Builtins.y2milestone("Prepare url summary for GRUB")
      ret = ""
      line = ""
      locations = []
      line = "<ul>\n<li>"
      if Ops.get(BootCommon.globals, "boot_mbr", "") == "true"
        line = Ops.add(
          Ops.add(
            line,
            _(
              "Boot from MBR is enabled (<a href=\"disable_boot_mbr\">disable</a>"
            )
          ),
          ")</li>\n"
        )
      else
        line = Ops.add(
          Ops.add(
            line,
            _(
              "Boot from MBR is disabled (<a href=\"enable_boot_mbr\">enable</a>"
            )
          ),
          ")</li>\n"
        )
      end
      locations = Builtins.add(locations, line)
      line = "<li>"

      set_boot_boot = false
      if Ops.get(BootCommon.globals, "boot_boot", "") == "true" &&
          BootStorage.BootPartitionDevice != BootStorage.RootPartitionDevice
        set_boot_boot = true
        line = Ops.add(
          Ops.add(
            line,
            _(
              "Boot from /boot partition is enabled (<a href=\"disable_boot_boot\">disable</a>"
            )
          ),
          ")</li></ul>"
        )
      elsif Ops.get(BootCommon.globals, "boot_boot", "") == "false" &&
          BootStorage.BootPartitionDevice != BootStorage.RootPartitionDevice
        set_boot_boot = true
        line = Ops.add(
          Ops.add(
            line,
            _(
              "Boot from /boot partition is disabled (<a href=\"enable_boot_boot\">enable</a>"
            )
          ),
          ")</li></ul>"
        )
      end
      if line != "<li>"
        locations = Builtins.add(locations, line)
        line = "<li>"
      end
      if Ops.get(BootCommon.globals, "boot_root", "") == "true" &&
          !set_boot_boot
        line = Ops.add(
          Ops.add(
            line,
            _(
              "Boot from \"/\" partition is enabled (<a href=\"disable_boot_root\">disable</a>"
            )
          ),
          ")</li></ul>"
        )
      elsif Ops.get(BootCommon.globals, "boot_root", "") == "false" &&
          !set_boot_boot
        line = Ops.add(
          Ops.add(
            line,
            _(
              "Boot from \"/\" partition is disabled (<a href=\"enable_boot_root\">enable</a>"
            )
          ),
          ")</li></ul>"
        )
      end
      locations = Builtins.add(locations, line) if !set_boot_boot

      if Ops.greater_than(Builtins.size(locations), 0)
        # FIXME: should we translate all devices to names and add MBR suffixes?
        ret = Builtins.sformat(
          _("Change Location: %1"),
          Builtins.mergestring(locations, " ")
        )
      end

      ret
    end


    # Display bootloader summary
    # @return a list of summary lines

    def Summary
      result = [
        Builtins.sformat(
          _("Boot Loader Type: %1"),
          BootCommon.getLoaderName(BootCommon.getLoaderType(false), :summary)
        )
      ]
      locations = []

      if Ops.get(BootCommon.globals, "boot_boot", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootStorage.BootPartitionDevice, _(" (\"/boot\")"))
        )
      end
      if Ops.get(BootCommon.globals, "boot_extended", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootStorage.ExtendedPartitionDevice, _(" (extended)"))
        )
      end
      if Ops.get(BootCommon.globals, "boot_root", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootStorage.RootPartitionDevice, _(" (\"/\")"))
        )
      end
      if Ops.get(BootCommon.globals, "boot_mbr", "") == "true"
        locations = Builtins.add(
          locations,
          Ops.add(BootCommon.mbrDisk, _(" (MBR)"))
        )
      end
      if Builtins.haskey(BootCommon.globals, "boot_custom")
        locations = Builtins.add(
          locations,
          Ops.get(BootCommon.globals, "boot_custom", "")
        )
      end
      if Ops.greater_than(Builtins.size(locations), 0)
        # FIXME: should we translate all devices to names and add MBR suffixes?
        result = Builtins.add(
          result,
          Builtins.sformat(
            _("Status Location: %1"),
            Builtins.mergestring(locations, ", ")
          )
        )
      end

      # it is necessary different summary for autoyast and installation
      # other mode than autoyast on running system
      result = Builtins.add(result, urlLocationSummary) if !Mode.config

      order_sum = BootCommon.DiskOrderSummary
      result = Builtins.add(result, order_sum) if order_sum != nil
      deep_copy(result)
    end

    def Dialogs
      Builtins.y2milestone("Called GRUB2 Dialogs")
      {
        "installation" => fun_ref(
          method(:Grub2InstallDetailsDialog),
          "symbol ()"
        ),
        "loader"       => fun_ref(
          method(:Grub2LoaderDetailsDialog),
          "symbol ()"
        )
      }
    end

    # Return map of provided functions
    # @return a map of functions (eg. $["write":BootGRUB2::Write])
    def GetFunctions
      {
        "read"    => fun_ref(method(:Read), "boolean (boolean, boolean)"),
        "reset"   => fun_ref(method(:Reset), "void (boolean)"),
        "propose" => fun_ref(method(:Propose), "void ()"),
        "summary" => fun_ref(method(:Summary), "list <string> ()"),
        "update"  => fun_ref(method(:Update), "void ()"),
        "widgets" => fun_ref(
          method(:grub2Widgets),
          "map <string, map <string, any>> ()"
        ),
        "dialogs" => fun_ref(method(:Dialogs), "map <string, symbol ()> ()"),
        "write"   => fun_ref(method(:Write), "boolean ()")
      }
    end

    # Initializer of GRUB bootloader
    def Initializer
      Builtins.y2milestone("Called GRUB2 initializer")
      BootCommon.current_bootloader_attribs = {
        "propose"            => false,
        "read"               => false,
        "scratch"            => false,
        "restore_mbr"        => false,
        "bootloader_on_disk" => false
      }

      nil
    end

    # Constructor
    def BootGRUB2
      Ops.set(
        BootCommon.bootloader_attribs,
        "grub2",
        {
          "required_packages" => ["grub2"],
          "loader_name"       => "GRUB2",
          "initializer"       => fun_ref(method(:Initializer), "void ()")
        }
      )

      nil
    end

    publish :function => :grub_InstallingToFloppy, :type => "boolean ()"
    publish :function => :grub_updateMBR, :type => "boolean ()"
    publish :function => :ReduceDeviceMapTo8, :type => "boolean ()"
    publish :variable => :common_help_messages, :type => "map <string, string>"
    publish :variable => :common_descriptions, :type => "map <string, string>"
    publish :variable => :grub_help_messages, :type => "map <string, string>"
    publish :variable => :grub_descriptions, :type => "map <string, string>"
    publish :variable => :grub2_help_messages, :type => "map <string, string>"
    publish :variable => :grub2_descriptions, :type => "map <string, string>"
    publish :function => :askLocationResetPopup, :type => "boolean (string)"
    publish :function => :grub2Widgets, :type => "map <string, map <string, any>> ()"
    publish :function => :grub2efiWidgets, :type => "map <string, map <string, any>> ()"
    publish :function => :StandardGlobals, :type => "map <string, string> ()"
    publish :function => :Read, :type => "boolean (boolean, boolean)"
    publish :function => :Update, :type => "void ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Reset, :type => "void (boolean)"
    publish :function => :Propose, :type => "void ()"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :Dialogs, :type => "map <string, symbol ()> ()"
    publish :function => :GetFunctions, :type => "map <string, any> ()"
    publish :function => :Initializer, :type => "void ()"
    publish :function => :BootGRUB2, :type => "void ()"
  end

  BootGRUB2 = BootGRUB2Class.new
  BootGRUB2.main
end
