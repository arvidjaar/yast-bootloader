# Sources for bootloader

module_DATA = \
  modules/BootCommon.rb \
  modules/Bootloader.rb \
  modules/BootGRUB2EFI.rb \
  modules/BootStorage.rb \
  modules/BootELILO.rb \
  modules/BootZIPL.rb \
  modules/BootArch.rb \
  modules/BootPOWERLILO.rb \
  modules/BootLILO.rb \
  modules/GfxMenu.rb \
  modules/BootSupportCheck.rb \
  modules/BootGRUB2.rb \
  modules/BootGRUB.rb \
  modules/Bootloader_API.pm

client_DATA = \
  clients/bootloader_preupdate.rb \
  clients/bootloader.rb \
  clients/inst_lilo_convert.rb \
  clients/inst_bootloader.rb \
  clients/bootloader_proposal.rb \
  clients/bootloader_auto.rb \
  clients/bootloader_finish.rb \
  clients/print-product.rb

yncludedir = @yncludedir@/bootloader/routines
ynclude_DATA = \
  include/bootloader/routines/common_options.rb \
  include/bootloader/routines/wizards.rb \
  include/bootloader/routines/popups.rb \
  include/bootloader/routines/i386.rb \
  include/bootloader/routines/section_helps.rb \
  include/bootloader/routines/misc.rb \
  include/bootloader/routines/autoinstall.rb \
  include/bootloader/routines/section_widgets.rb \
  include/bootloader/routines/dialogs.rb \
  include/bootloader/routines/lilolike.rb \
  include/bootloader/routines/switcher.rb \
  include/bootloader/routines/global_widgets.rb \
  include/bootloader/routines/lib_iface.rb \
  include/bootloader/routines/helps.rb \
  include/bootloader/routines/common_helps.rb

ynclude1dir = @yncludedir@/bootloader/elilo
ynclude1_DATA = \
  include/bootloader/elilo/widgets.rb \
  include/bootloader/elilo/options.rb \
  include/bootloader/elilo/dialogs.rb \
  include/bootloader/elilo/helps.rb

ynclude2dir = @yncludedir@/bootloader/grub2
ynclude2_DATA = \
  include/bootloader/grub2/options.rb \
  include/bootloader/grub2/misc.rb \
  include/bootloader/grub2/dialogs.rb \
  include/bootloader/grub2/helps.rb

ynclude3dir = @yncludedir@/bootloader/grub
ynclude3_DATA = \
  include/bootloader/grub/options.rb \
  include/bootloader/grub/misc.rb \
  include/bootloader/grub/dialogs.rb \
  include/bootloader/grub/helps.rb

ynclude4dir = @yncludedir@/bootloader/zipl
ynclude4_DATA = \
  include/bootloader/zipl/helps.rb

ynclude5dir = @yncludedir@/bootloader/ppc
ynclude5_DATA = \
  include/bootloader/ppc/options.rb \
  include/bootloader/ppc/dialogs.rb \
  include/bootloader/ppc/helps.rb

scrconf_DATA = \
  scrconf/cfg_bootloader.scr \
  scrconf/cfg_bootsplash.scr \
  scrconf/bootloader.scr

agent_SCRIPTS = \
  servers_non_y2/ag_bootloader

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/bootloader.rnc

desktop_DATA = \
  desktop/bootloader.desktop

fillup_DATA = \
  fillup/sysconfig.bootloader.default \
  fillup/sysconfig.bootloader.i386

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(ynclude1_DATA) $(ynclude2_DATA) $(ynclude3_DATA) $(ynclude4_DATA) $(ynclude5_DATA) $(scrconf_DATA) $(agent_SCRIPTS) $(schemafiles_DATA) $(desktop_DATA) $(fillup_DATA)

include $(top_srcdir)/Makefile.am.common