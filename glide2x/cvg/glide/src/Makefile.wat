# OpenWatcom makefile for Glide3/SST1 and Texus2
# This makefile MUST be processed by GNU make!!!
# Building under native DOS is not supported:
#		only tested under Win32 or Linux
#
#  Copyright (c) 2004 - Daniel Borca
#  Email : dborca@users.sourceforge.net
#  Web   : http://www.geocities.com/dborca
#

#
#  Available options:
#
#    Environment variables:
#	FX_GLIDE_HW	build for the given ASIC (either sst1, or sst96).
#			default = sst1
#	OPTFLAGS	pass given optimization flags to compiler
#			default = -ox -5s (Pentium, stack)
#	DEBUG=1		enable debugging checks and messages
#			default = no
#	USE_X86=1	use assembler triangle specializations!
#			default = no
#	TEXUS2=1	embed Texus2 functions into Glide3.
#			default = no
#
#    Targets:
#	all:		build everything
#	glide3x:	build Glide3x lib
#	clean:		remove object files
#	realclean:	remove all generated files
#

.PHONY: all glide3x clean realclean
.INTERMEDIATE: wlib.lbc fxgasm.exe
.SUFFIXES: .c .obj

###############################################################################
#	general defines (user settable?)
###############################################################################

GLIDE_LIB = glide2x.lib
GLIDE_DLL = glide2x.ovl
TEXUS_EXE = texus2.exe

FX_GLIDE_HW ?= cvg
FX_GLIDE_SW = ../../../swlibs
GLIDE_LIBDIR = ../../lib
TEXUS_EXEDIR = $(FX_GLIDE_SW)/bin

###############################################################################
#	tools
###############################################################################

CC = wcc386
AS = nasm
WAS = wasm
AR = wlib
LD = wlink

# detect if running under unix by finding 'rm' in $PATH :
ifeq ($(wildcard $(addsuffix /rm,$(subst :, ,$(PATH)))),)
DOSMODE= 1
UNLINK = rm -f $(subst /,\,$(1))
FIXPATH= $(subst /,\\,$1)
else
DOSMODE= 0
UNLINK = $(RM) $(1)
FIXPATH= $1
endif

###############################################################################
#	defines
###############################################################################

# platform
CDEFS = -D__DOS__ -D__DOS32__ -DINIT_DOS -D__3Dfx_PCI_CFG__ -DFX_DLL_ENABLE

# general
CDEFS += -DGLIDE_HW_TRI_SETUP=1 -DGLIDE_PACKED_RGB=1 -DGLIDE_TRI_CULLING=1 -DGLIDE_DEFAULT_GAMMA=1.3f -DGLIDE_LIB=1

# workaround for CVGs with broken tsus which cannot send commands to multiple
# tmus using chipfield. chipfield will always be set to 0xf
CDEFS += -DGLIDE_CHIP_BROADCAST=1
# special sli buffer clears
CDEFS += -DGLIDE_BLIT_CLEAR=1

# subsystem
CDEFS += -DCVG

# debug
ifdef DEBUG
CDEFS += -DGDBG_INFO_ON -DGLIDE_DEBUG -DGLIDE_SANITY_ASSERT -DGLIDE_SANITY_SIZE
endif

override USE_FIFO = 1

ifeq ($(USE_X86),1)
CDEFS += -DGLIDE_DISPATCH_SETUP=1 -DGLIDE_DISPATCH_DOWNLOAD=1
override USE_FIFO = 1
CDEFS += -DHAVE_XDRAWTRI_ASM=1
override USE_DRAWTRI_ASM = 1
else
CDEFS += -DGLIDE_USE_C_TRISETUP=1
endif

# fifo
ifeq ($(USE_FIFO),1)
CDEFS += -DUSE_PACKET_FIFO=1 -DGLIDE_PACKET3_TRI_SETUP=1
endif

###############################################################################
#	flags
###############################################################################

# librarian
ARFLAGS = -c -fo -n -t -q

# linker
# pick either of causeway, dos4g, dos32a or stub32a as link target
LDFLAGS = -zq -k16384 -l=dos4g

# assembler
ASFLAGS = -O6 -fobj -D__WATCOMD__ --prefix _
ASFLAGS += $(CDEFS)

WASFLAGS = -5s -bt=dos

# compiler
CFLAGS = -5s -bt=dos -bd -mf -aa
# newer OpenWatcom versions enable W303 by default
CFLAGS += -wcd=303
INCPATH = -I. -I../../incsrc -I../../init
INCPATH += -I$(FX_GLIDE_SW)/fxmisc -I$(FX_GLIDE_SW)/newpci/pcilib -I$(FX_GLIDE_SW)/fxmemmap
CFLAGS += $(CDEFS) $(INCPATH)

# cpu optimized triangle
ifeq ($(USE_MMX),1)
CFLAGS += -DGL_MMX
override USE_X86 = 1
endif

ifeq ($(USE_3DNOW),1)
CFLAGS += -DGL_AMD3D
override USE_X86 = 1
endif

OPTFLAGS ?= -ox

# optflags
CFLAGS += $(OPTFLAGS)

# for cross-builds
HOST_CFLAGS=$(filter-out -mcpu=% -mtune=% -march=%,$(CFLAGS))

###############################################################################
#	objects
###############################################################################

GLIDE_OBJECTS = \
	fifo.obj \
	gsplash.obj \
	g3df.obj \
	gu.obj \
	guclip.obj \
	gpci.obj \
	gump.obj \
	diglide.obj \
	disst.obj \
	ditex.obj \
	gbanner.obj \
	gerror.obj \
	gmovie.obj \
	digutex.obj \
	ddgump.obj \
	gaa.obj \
	gdraw.obj \
	gglide.obj \
	glfb.obj \
	gsst.obj \
	gtex.obj \
	gtexdl.obj \
	gutex.obj \
	cpuid.obj \
	fpu.obj \
	dllstart.obj \
	xtexdl_def.obj

ifeq ($(USE_DRAWTRI_ASM),1)
GLIDE_OBJECTS += xdrawtri.obj
endif
ifeq ($(USE_X86),1)
GLIDE_OBJECTS += \
	xdraw2_def.obj
ifeq ($(USE_MMX),1)
GLIDE_OBJECTS += \
	xtexdl_mmx.obj
endif
ifeq ($(USE_3DNOW),1)
GLIDE_OBJECTS += \
	xdraw2_3dnow.obj \
	xtexdl_3dnow.obj
endif
else
GLIDE_OBJECTS += \
	gxdraw.obj
endif

GLIDE_OBJECTS += \
	$(FX_GLIDE_SW)/newpci/pcilib/fxmsr.obj \
	$(FX_GLIDE_SW)/newpci/pcilib/fxpci.obj \
	$(FX_GLIDE_SW)/newpci/pcilib/fxdpmi2.obj \
	../../init/canopus.obj \
	../../init/dac.obj \
	../../init/gamma.obj \
	../../init/gdebug.obj \
	../../init/info.obj \
	../../init/parse.obj \
	../../init/print.obj \
	../../init/sli.obj \
	../../init/sst1init.obj \
	../../init/util.obj \
	../../init/video.obj \
	../../init/fxremap.obj


###############################################################################
#	rules
###############################################################################

.c.obj:
	$(CC) $(CFLAGS) -fo=$(call FIXPATH,$@) $(call FIXPATH,$<)

###############################################################################
#	main
###############################################################################
all: glide2x $(TEXUS_EXEDIR)/$(TEXUS_EXE) $(GLIDE_DLL)

glide2x: $(GLIDE_LIBDIR)/$(GLIDE_LIB)

$(GLIDE_LIBDIR)/$(GLIDE_LIB): wlib.lbc
	$(AR) $(ARFLAGS) $(call FIXPATH,$@) @wlib.lbc

$(GLIDE_DLL): $(GLIDE_OBJECTS)
ifeq ($(USE_X86),1)
	$(LD) @glideovl_asm.lnk
else
	$(LD) @glideovl.lnk
endif

$(TEXUS_EXEDIR)/$(TEXUS_EXE): $(FX_GLIDE_SW)/texus2/cmd/cmd.c $(GLIDE_LIBDIR)/$(GLIDE_LIB)
ifeq ($(TEXUS2),1)
	$(CC) $(CFLAGS) -fe=$(call FIXPATH,$@) $(LDFLAGS) $(call FIXPATH,$^)
else
	$(warning Texus2 not enabled... Skipping $(TEXUS_EXE))
endif

###############################################################################
#	rules(2)
###############################################################################

#cpuid.obj: cpudtect.asm
#	$(AS) -o $@ $(ASFLAGS) $<
dllstart.obj: dllstart.asm
	$(WAS) -fo=$@ $(WASFLAGS) $<
xdraw2_def.obj: xdraw2.asm
	$(AS) -o $@ $(ASFLAGS) $<
xtexdl_def.obj: xtexdl.c
	$(CC) -fo=$@ $(CFLAGS) $<
xtexdl_mmx.obj: xtexdl.asm
	$(AS) -o $@ $(ASFLAGS) -DGL_MMX=1 $<
xdraw2_3dnow.obj: xdraw2.asm
	$(AS) -o $@ $(ASFLAGS) -DGL_AMD3D=1 $<
xtexdl_3dnow.obj: xtexdl.asm
	$(AS) -o $@ $(ASFLAGS) -DGL_AMD3D=1 $<
xdrawtri.obj: xdrawtri.asm
	$(AS) -o $@ $(ASFLAGS) $<


$(GLIDE_OBJECTS): fxinline.h fxgasm.h

fxinline.h: fxgasm.exe
	$(call FIXPATH,./$<) -inline > $@

fxgasm.h: fxgasm.exe
	$(call FIXPATH,./$<) -hex > $@

# -bt without args resets build target to host OS.
fxgasm.exe: fxgasm.c 
	$(CC) $(call FIXPATH,$(INCPATH)) $(CDEFS) -DCVG -DGLIDE_LIB=1 -bt -fo=fxgasm.obj $<
	$(LD) file fxgasm.obj name $@

wlib.lbc: $(GLIDE_OBJECTS)
	@echo $(addprefix +,$^) > wlib.lbc

###############################################################################
#	clean, realclean
###############################################################################

clean:
	-$(call UNLINK,*.obj)
	-$(call UNLINK,*.o)
	-$(call UNLINK,*.ovl)
	-$(call UNLINK,*.map)
	-$(call UNLINK,../../init/*.obj)
	-$(call UNLINK,$(FX_GLIDE_SW)/newpci/pcilib/*.obj)
	-$(call UNLINK,fxinline.h)
	-$(call UNLINK,fxgasm.h)
	-$(call UNLINK,$(FX_GLIDE_SW)/texus2/lib/*.obj)
	-$(call UNLINK,*.err)

realclean: clean
	-$(call UNLINK,$(GLIDE_LIBDIR)/$(GLIDE_LIB))
	-$(call UNLINK,$(TEXUS_EXEDIR)/$(TEXUS_EXE))
