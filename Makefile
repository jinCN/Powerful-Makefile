SHELL  := /bin/bash
.SECONDEXPANSION:
.SUFFIXES:
.PHONY: all clean symlink
.DEFAULT_GOAL  := all
all:$$(TARGETS_ALL)

MIN_MAKE_VERSION := 3.81
MIN_MAKE_VER_MSG := GNU Make ${MIN_MAKE_VERSION} or greater required

#########################检查make的版本
define MIN
$(firstword $(sort ${1} ${2}))
endef
ifeq "${MAKE_VERSION}" ""
    $(info GNU Make not detected)
    $(error ${MIN_MAKE_VER_MSG})
endif
ifneq "${MIN_MAKE_VERSION}" "$(call MIN,${MIN_MAKE_VERSION},${MAKE_VERSION})"
    $(info This is GNU Make version ${MAKE_VERSION})
    $(error ${MIN_MAKE_VER_MSG})
endif

########################寻找TOP
TOP_MARK:=TOP_RUL
define find_top
$(if $(1),$(if $(wildcard $(1)/$(TOP_MARK)),$(1),$(call find_top,$(patsubst %/,%,$(dir $(1))))),$(error TOP not found))
endef

ifndef TOP
TOP:=$(call find_top,$(CURDIR))
endif

$(warning1 top $(TOP))
rulfile_TOP:=$(TOP)/$(TOP_MARK)
makefile_TOP:=$(TOP)/Makefile

########################构建时使用的一些常量属性
C_SRC_EXTS := %.c
CXX_SRC_EXTS := %.C %.cc %.cp %.cpp %.CPP %.cxx %.c++
ALL_SRC_EXTS := ${C_SRC_EXTS} ${CXX_SRC_EXTS}

TAR_VARS  :=TYPE SRCS SRCS_EXCLUDE SRCS_VPATH DEPS DEP_FLAGS INCS CPPFLAGS CFLAGS CXXFLAGS ARFLAGS LDFLAGS PREBUILT_LIBS


#######################包含TOP_RUL文件，可以覆盖以上
$(warning1 rulfile_TOP=$(rulfile_TOP))
include $(rulfile_TOP)
$(warning1 CONFIG=$(CONFIG))
######################设置CONFIG VERBOSE
CONFIG ?= debug
ifneq ($(VERBOSE),1)
echo_cmd = @echo "$(1)";
else # Verbose output
echo_cmd =
endif

##########################格式转换与识别
TARGETS_ALL:=
#由分隔tar的dir和name中间的@转化
TAR_SPLITER:=***TAR@@@
#由分隔dep的tar和detail中间的:转化
DEP_SPLITER:=***DEP@@@
#由分隔dep的detail内的,转化
AND_SPLITER:=***AND@@@
define tar_dir
$(if $(findstring $(TAR_SPLITER),$(1)),$(patsubst %/,%,$(dir $(subst $(TAR_SPLITER),/,$(1)))),)
endef

define tar_name
$(if $(findstring $(TAR_SPLITER),$(1)),$(notdir $(subst $(TAR_SPLITER),/,$(1))),$(1))
endef

define dep_detail
$(if $(findstring $(DEP_SPLITER),$(1)),$(notdir $(subst $(DEP_SPLITER),/,$(1))),)
endef

define dep_tar
$(if $(findstring $(DEP_SPLITER),$(1)),$(patsubst %/,%,$(dir $(subst $(DEP_SPLITER),/,$(1)))),$(1))
endef


#$(\n)展开为一个回车
define \n


endef

# push $(1)作为栈,将$(2)push到最后
define push
${2:%=${1} %}
endef

# peek $(1)作为栈,获得最后一个元素
define peek
$(lastword ${1})
endef

# pop $(1)作为栈,删去最后一个元素
define pop
${1:% $(lastword ${1})=%}
endef


#####################################路径定义
#转换为绝对路径"/systemsome/some2"
#$(1)输入路径列表,包含三类:绝对路径"/systemsome/some2",相对路径"//topsome/some2"(从顶级目录$(TOP)开始),局部路径"localsome/some2"
#$(2)代表当前目录,格式为绝对路径,默认为$(d)
define to_abspath
$(strip $(patsubst //,$(TOP),$(filter //,$(1))) $(abspath $(patsubst //%,$(TOP)/%,$(filter //%,$(filter-out //,$(1)))) $(filter /%,$(filter-out //%,$(1))) $(patsubst %,$(or $(2),$(d))/%,$(filter-out /%,$(1)))))
endef

#转换为相对路径"//topsome/some2"(从顶级目录$(TOP)开始)
#$(1)输入路径列表,包含三类:绝对路径"/systemsome/some2",相对路径"//topsome/some2"(从顶级目录$(TOP)开始),局部路径"localsome/some2"
#$(2)代表当前目录,格式为绝对路径,默认为$(d)
define to_relpath
$(patsubst $(TOP),//,$(patsubst $(TOP)/%,//%, $(call to_abspath,$(1),$(2))))
endef

#转换为局部路径"localsome/some2"(从当前目录开始),若不在当前目录,则转换为相对路径，若为当前目录，则返回"."
#$(1)输入路径列表,包含三类:绝对路径"/systemsome/some2",相对路径"//topsome/some2"(从顶级目录$(TOP)开始),局部路径"localsome/some2"
#$(2)代表当前目录,格式为绝对路径,默认为$(d)
define to_locpath
$(patsubst $(patsubst $(TOP),/,$(patsubst $(TOP)/%,//%,$(or $(2),$(d))))/%,%,$(patsubst $(patsubst $(TOP),//,$(patsubst $(TOP)/%,//%,$(or $(2),$(d)))),.,$(call to_relpath,$(1),$(2))))
endef

#输入目标名称,返回标准命名的目标名称
#$(1)目标名称,若无参数则为"makefile文件名的basename"
define name_target
$(call to_abspath,$d$(TAR_SPLITER)$(or $(1),$(notdir $(basename $(lastword $(MAKEFILE_LIST))))))
endef

############################以下为解析rul文件使用的程式
define CLEAR_VARS
$(foreach v,$(TAR_VARS),$(warning1 CVevalwhat $(v)  :=$(DEFAULT_$(v)))$(eval $(v)  :=$(DEFAULT_$(v))))
endef

define SAVE_VARS
$(warning1 into SAVE_VARS)
$(foreach v,$(TAR_VARS),$(warning1 evalwhat $(v)_$(tar)  := $($(v)) $(GLOBAL_$(v)))$(eval $(v)_$(tar)  := $(strip $($(v)) $(GLOBAL_$(v)))))
endef

define HANDLE_VARS
$(warning1 into HANDLE_VARS)
$(warning1 SRCS_$(tar)$(SRCS_$(tar))Dir$(d))
SRCS_VPATH_$(tar):=$(d) $(call to_abspath,$(SRCS_VPATH_$(tar)))
$(warning1 SRCS_VPATH$(SRCS_VPATH_$(tar)))

SRCS_EXCLUDE_$(tar) :=$(strip $(wildcard $(to_abspath $(filter /%,$(SRCS_$(tar))))) $(foreach sd,$(SRCS_VPATH_$(tar)),$(abspath $(wildcard $(addprefix $(sd)/,$(filter-out /%,$(SRCS_EXCLUDE_$(tar))))))))

SRCS_$(tar) := $(strip $(wildcard $(to_abspath $(filter /%,$(SRCS_$(tar))))) $(foreach sd,$(SRCS_VPATH_$(tar)),$(abspath $(wildcard $(addprefix $(sd)/,$(filter-out /%,$(SRCS_$(tar))))))))

SRCS_$(tar) := $(filter-out $(SRCS_EXCLUDE_$(tar)),$(SRCS_$(tar)))
$(warning1 SRCS_$(tar)$(SRCS_$(tar)))
DEPS_$(tar) :=$(subst ;,$(AND_SPLITER),$(subst :,$(DEP_SPLITER),$(subst @,$(TAR_SPLITER),$(DEPS_$(tar)))))
DEPS_$(tar) :=$(foreach dep,$(DEPS_$(tar)),$(call to_abspath,$(or $(call tar_dir,$(dep)),$(d)))$(TAR_SPLITER)$(call tar_name,$(dep))$(warning1 DEPSn$(call tar_name,$(dep))))
$(warning1 DEPS $(DEPS_$(tar)))

DEP_FLAGS_$(tar):=$(foreach each,$(DEP_FLAGS_$(tar)),$(strip $(abspath $(wildcard $(call to_abspath,$(filter-out -%,$(each))))) $(filter-out -L%,$(filter -%,$(each))) $(addprefix -L,$(call to_abspath,$(patsubst -L%,%,$(filter -L%,$(each)))))))

INCS_$(tar) :=$(strip $(d) $(call to_abspath,$(INCS_$(tar))))
INCS_$(tar) :=$(patsubst %,-I%,$(patsubst -I%,%,$(INCS_$(tar))))
$(warning DEP_FLAGS_$(tar)=$(DEP_FLAGS_$(tar)))
$(warning1 TYPE_$(tar)=$(TYPE_$(tar)))
$(warning1 PREBUILT_LIBS_$(tar)=$(PREBUILT_LIBS_$(tar)))
outdir_$(tar):=$(call tar_dir,$(tar))/$(CONFIG)
ifeq (prebuilt,$(strip $(TYPE_$(tar))))
PREBUILT_LIBS_$(tar):=$(or $(PREBUILT_LIBS_$(tar)),lib$(call tar_name,$(tar)).a lib$(call tar_name,$(tar)).so)
PREBUILT_LIBS_$(tar):=$(wildcard $(call to_abspath,$(PREBUILT_LIBS_$(tar))))
out_prebuilt_$(tar):=$(PREBUILT_LIBS_$(tar))
out_static_prebuilt_$(tar):=$(filter %.a,out_prebuilt_$(tar))
out_shared_prebuilt_$(tar):=$(filter %.so,out_prebuilt_$(tar))
endif
ifeq (multi_prebuilt,$(strip $(TYPE_$(tar))))
PREBUILT_LIBS_$(tar):=$(or $(PREBUILT_LIBS_$(tar)),*.a *.so)
$(warning 2.1PREBUILT_LIBS_$(tar)=$(PREBUILT_LIBS_$(tar)))
PREBUILT_LIBS_$(tar):=$(wildcard $(call to_abspath,$(PREBUILT_LIBS_$(tar))))
$(warning 2.2 w=$(call to_abspath $(PREBUILT_LIBS_$(tar)));x=$(d);y=$(2);e=$(patsubst %,$(d)/%,$(filter-out /%,*.a *.so));PREBUILT_LIBS_$(tar)=$(PREBUILT_LIBS_$(tar)))
out_prebuilt_$(tar):=$(PREBUILT_LIBS_$(tar))
out_static_prebuilt_$(tar):=$(filter %.a,out_prebuilt_$(tar))
out_shared_prebuilt_$(tar):=$(filter %.so,out_prebuilt_$(tar))
endif
ifneq ($(filter static,$(TYPE_$(tar))),)
$(warning1 into 1HANDLE_VARS)
outname_static_$(tar):=lib$(call tar_name,$(tar)).a
out_static_$(tar):=$(outdir_$(tar))/$(outname_static_$(tar))
endif
ifneq ($(filter shared,$(TYPE_$(tar))),)
$(warning1 into 2HANDLE_VARS)
outname_shared_$(tar):=lib$(call tar_name,$(tar)).so
out_shared_$(tar):=$(outdir_$(tar))/$(outname_shared_$(tar))
endif
ifneq ($(filter exe,$(TYPE_$(tar))),)
$(warning1 into 3HANDLE_VARS)
outname_exe_$(tar):=$(call tar_name,$(tar))
out_exe_$(tar):=$(outdir_$(tar))/$(outname_exe_$(tar))
endif
$(warning1 3PREBUILT_LIBS_$(tar)=$(PREBUILT_LIBS_$(tar)))
endef

define HANDLE_ONE_TAR
$(warning1 into HANDLE_ONE_TAR $(tar) $(d))
rulfile_$(tar):=$(d)/$(notdir $(lastword $(MAKEFILE_LIST)))
TARGETS_ALL :=$(TARGETS_ALL) $(tar)
TARGETS_$(d):=$(TARGETS_$(d)) $(tar)


local_target:=$(call to_relpath,$(d))@$(call tar_name,$(tar))

$(warning local_target=$(local_target))
.PHONY:$(local_target) $(call tar_name,$(tar))
$(local_target):$(tar)

$(call tar_name,$(tar)):$(tar)

$(eval $(value SAVE_VARS))
$(eval $(value HANDLE_VARS))
$(eval $(value CLEAR_VARS))
$(warning1 out HANDLE_ONE_TAR $(TARGETS_$(d)))
endef
#包含rul文件
#$(1)文件名,绝对路径
define include_one_rul
$$(warning1 into include_one_rul $(1))
$$(warning1 eval what $$(value CLEAR_VARS))
$$(eval $$(value CLEAR_VARS))#仅为保险措施
TARGETS:=
include $(1)
$$(warning1 after include $(1) $$(call name_target))
ifeq ($$(strip $$(TARGETS)),)#简洁定义,rul文件名作为TARGETS名,无需evaltar定义
tar:=$$(call name_target,$$(notdir $$(basename $$(lastword $$(MAKEFILE_LIST)))))
$$(warning1 1tar $$(tar) MF $$(basename $$(lastword $$(MAKEFILE_LIST))))
$$(eval $$(value HANDLE_ONE_TAR))

else#详细定义,TARGETS可能有多个
$$(warning1 into targetprocess $(1))
$$(foreach t,$$(TARGETS),$$(eval include $(1))\
$$(eval $$(value $$(t)))\
$$(eval tar := $$$$(call name_target ,$$(t)))$$(warning1 2tar $$(tar))\
$$(eval $$(value HANDLE_ONE_TAR)))
endif
$$(warning1 out include_one_rul $(1))
endef

#递归包含目录下所有rul文件
#$(1)目录名,绝对路径
define include_dir_rul
$(warning1 into idr $(1))
d  := $(1)
dir_stack  := $$(call push,$$(dir_stack),$$(d))

#获取d下所有rul文件
ruls  := $$(wildcard $$(d)/*.rul)

$$(foreach rul,$$(ruls),$$(eval $$(call include_one_rul,$$(rul)))$$(warning1 tarsome $$(tar)))

ifneq ($$(strip $$(ruls)),)

local_dir_target:=$$(call to_relpath,$$(d))

$$(warning local_dir_target=$$(local_dir_target))
.PHONY:$$(local_dir_target) clean_$$(local_dir_target) clean_$$(d) symlink_$$(local_dir_target) symlink_$$(d)
$$(local_dir_target):$$(TARGETS_$$(d))
clean_$$(local_dir_target):clean_$$(d)
clean_$$(d):dir_to:=$$(d)/$$(CONFIG)
clean_$$(d):
	rm -f -r $$(dir_to)
symlink_$$(local_dir_target):symlink_$$(d)
symlink_$$(d):dir_to:=$$(d)
symlink_$$(d):
	ln -sf $$(makefile_TOP) $$(dir_to)
clean:clean_$$(d)
ifneq ($$(d),$$(TOP))
symlink:symlink_$$(d)
endif
endif
#获取所有非空子目录
sub_dirs :=$$(patsubst %/,%,$$(sort $$(dir $$(wildcard $$d/*/*)))) 
#迭代本过程
$$(foreach dir,$$(sub_dirs),$$(eval $$(call include_dir_rul,$$(dir))))

dir_stack  := $$(call pop,$$(dir_stack))
d  := $$(call peek,$$(dir_stack))
endef
############################以上为解析rul文件使用的程式


############################以下为定义tar规则使用的程式
define COMPILE_C
	$(call echo_cmd,COMPILE_C $(call to_locpath,$<,$(call tar_dir,$(tar)))) ${CC} -o $@ -c -MD $(CPPFLAGS_$(tar)) ${CFLAGS_$(tar)} ${INCS_$(tar)} $<
	@cp ${@:%$(suffix $@)=%.d} ${@:%$(suffix $@)=%.P}; \
	sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
	     -e '/^$$/ d' -e 's/$$/ :/' < ${@:%$(suffix $@)=%.d} \
	     >> ${@:%$(suffix $@)=%.P}; \
	rm -f ${@:%$(suffix $@)=%.d}
endef

define COMPILE_CXX
	$(call echo_cmd,COMPILE_CXX $(call to_locpath,$<,$(call tar_dir,$(tar)))) ${CXX} -o $@ -c -MD $(CPPFLAGS_$(tar)) ${CXXFLAGS_$(tar)} ${INCS_$(tar)} $<
	@cp ${@:%$(suffix $@)=%.d} ${@:%$(suffix $@)=%.P}; \
	 sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' \
	     -e '/^$$/ d' -e 's/$$/ :/' < ${@:%$(suffix $@)=%.d} \
	     >> ${@:%$(suffix $@)=%.P}; \
	 rm -f ${@:%$(suffix $@)=%.d}
endef

#$(src)作为循环变量
define ADD_OBJ_RULE
ifneq ($(filter ${CXX_SRC_EXTS},${src}),)
$(patsubst %,$(objsdir)/%.o,$(basename $(notdir $(src)))): $(src) $(rulfile_$(tar)) $(rulfile_TOP) $(makefile_TOP) | $(objsdir) 
	$(COMPILE_CXX)
else
$(patsubst %,$(objsdir)/%.o,$(basename $(notdir $(src)))): $(src) $(rulfile_$(tar)) $(rulfile_TOP) $(makefile_TOP) | $(objsdir) 
	$(COMPILE_C)
endif
endef


define GEN_DEPS
$(warning1 into GEN_DEPS $(dep))
ifeq ($(strip $(call dep_detail,$(dep))),)
$(warning1 into 1GEN_DEPS $(dep))
lib:=$(or $(out_static_$(call dep_tar,$(dep))),$(out_shared_$(call dep_tar,$(dep))),$(out_static_prebuilt_$(call dep_tar,$(dep))),$(out_shared_prebuilt_$(call dep_tar,$(dep))),$(out_prebuilt_$(call dep_tar,$(dep))))
else
ifeq ($(strip $(call dep_detail,$(dep))),static)
$(warning1 into GEN_DEPS detail1)
lib:=$(or $(out_static_$(call dep_tar,$(dep))),$(out_static_prebuilt_$(call dep_tar,$(dep))))
else
ifeq ($(strip $(call dep_detail,$(dep))),shared)
$(warning1 into GEN_DEPS detail2)
lib:=$(or $(out_shared_$(call dep_tar,$(dep))),$(out_shared_prebuilt_$(call dep_tar,$(dep))))
else
$(warning1 into GEN_DEPS detail3 $(foreach det,$(subst $(AND_SPLITER), ,$(call dep_detail,$(dep))),$(det)) out=$(out_prebuilt_$(call dep_tar,$(dep))))
lib:=$(foreach det,$(subst $(AND_SPLITER), ,$(call dep_detail,$(dep))),$(filter %/$(det),$(out_prebuilt_$(call dep_tar,$(dep)))))
endif
endif
endif
$(warning1 into 4GEN_DEPS dep=$(dep) lib=$(lib))
#二次扩展时解析$(deps_$(lib))
$(eval outdeps_$(tar) += $(if $(filter %.a,$(lib)),$$(outdeps_$(call dep_tar,$(dep))),) $(lib))
$(eval outdep_flags_$(tar) += $(if $(filter %.a,$(lib)),$$(outdep_flags_$(call dep_tar,$(dep))),))
$(eval deps_$(tar) += $$(deps_$(call dep_tar,$(dep))) $(lib))
$(eval dep_flags_$(tar) += $$(dep_flags_$(call dep_tar,$(dep))))
endef

define GEN_DEP_FLAGS
$(warning into GEN_DEP_FLAGS dep_flag=$(dep_flag))

#二次扩展时解析$(deps_$(lib))
$(eval outdep_flags_$(tar) += $(dep_flag))
$(eval dep_flags_$(tar) += $(dep_flag))
endef

define ADD_TAR_RULE
$(warning1 into ADD_TAR_RULE $(tar))
.PHONY:$(tar) 
$(tar)::tar:=$(tar)

ifndef $(outdir_$(tar))_RULE_IS_DEFINED
$(outdir_$(tar)):
	@mkdir -p $@
$(outdir_$(tar))_RULE_IS_DEFINED := 1
endif
$(warning1 into ADD_TAR_RULE $(tar))
#解析传递依赖,生成二次扩展目标
#输出依赖
outdeps_$(tar)=
outdep_flags_$(tar)=
#所有依赖
deps_$(tar)=
dep_flags_$(tar)=
$(warning1 into ADD_TAR_RULE $(tar))
$(foreach dep,$(DEPS_$(tar)),$(eval $(value GEN_DEPS)))
$(foreach dep_flag,$(DEP_FLAGS_$(tar)),$(eval $(value GEN_DEP_FLAGS)))
$(warning1 outdeps $(outdeps_$(tar)))
$(warning1 $(TYPE_$(tar))$(out_static_$(tar))$(out_shared_$(tar))$(out_exe_$(tar)))
ifeq ($(strip $(TYPE_$(tar))),prebuilt)
$(tar)::$(out_prebuilt_$(tar))
$(warning1 into +0ADD_TAR_RULE)
else
ifeq ($(strip $(TYPE_$(tar))),multi_prebuilt)
$(tar)::$(out_prebuilt_$(tar))
$(warning1 into +0ADD_TAR_RULE)
else
$(warning1 into -0ADD_TAR_RULE)
ifneq ($(strip $(out_static_$(tar))),)
$(warning1 into 1ADD_TAR_RULE)
$(tar)::$(out_static_$(tar))

objsdir:=$(outdir_$(tar))/obj_$(outname_static_$(tar))
$(warning1 into 1ADD_TAR_RULE$(objsdir))

ifndef $(objsdir)_RULE_IS_DEFINED
$(objsdir):
	@mkdir -p $@
$(objsdir)_RULE_IS_DEFINED := 1
endif
objs:=$(patsubst %,$(objsdir)/%.o,$(basename $(notdir $(SRCS_$(tar)))))
$(out_static_$(tar))::$(outdir_$(tar))
$(out_static_$(tar))::tar:=$(tar)
$(out_static_$(tar))::$(objs)
	$(call echo_cmd,AR $(call to_locpath,$@,$(call tar_dir,$(tar)))<=$(call to_locpath,$^,$(call tar_dir,$(tar))))ar -rcs ${ARFLAGS_$(tar)} $(@) $(?)
	
-include $(objs:.o=.P)
$(foreach src,$(SRCS_$(tar)),$(eval $(value ADD_OBJ_RULE)))

endif
ifneq ($(strip $(out_shared_$(tar))),)
	ifneq ($(filter ${CXX_SRC_EXTS},${SRCS_${tar}}),)
        linker := ${CXX}
    else
        linker := ${CC}
    endif
$(warning1 ${SRCS_${tar}},$(filter ${CXX_SRC_EXTS},${SRCS_${tar}}),linker$(linker))


objsdir:=$(outdir_$(tar))/obj_$(outname_shared_$(tar))
$(warning1 into 2ADD_TAR_RULE$(objsdir))
ifndef $(objsdir)_RULE_IS_DEFINED
$(objsdir):
	@mkdir -p $@
$(objsdir)_RULE_IS_DEFINED := 1
endif

objs:=$(patsubst %,$(objsdir)/%.o,$(basename $(notdir $(SRCS_$(tar)))))
$(out_shared_$(tar))::$(outdir_$(tar))
$(out_shared_$(tar))::tar:=$(tar)
$(out_shared_$(tar))::CFLAGS_$(tar) +=-fPIC 
$(out_shared_$(tar))::CXXFLAGS_$(tar) +=-fPIC 
$(out_shared_$(tar))::LDFLAGS_$(tar) +=-shared
$(out_shared_$(tar))::linker:=$(linker)
$(out_shared_$(tar))::$(objs) $$(outdeps_$(tar))
	$(call echo_cmd,LINK $(call to_locpath,$@,$(call tar_dir,$(tar)))<=$(call to_locpath,$^,$(call tar_dir,$(tar))))$(linker) -Wl,--start-group $^ $(outdep_flags_$(tar)) $(LDFLAGS_$(tar)) -Wl,--end-group -Wl,-rpath,. -Wl,--soname,$(notdir $@) -o $(@)
	
$(tar)::$(out_shared_$(tar))
$(tar)::$$(wildcard $$(sort $$(filter-out %.a,$$(deps_$(tar)) $$(dep_flags_$(tar)))))
	$(if $^,cp -u -t $(outdir_$@) $(foreach file,$^,$(if $(filter-out $(outdir_$@)/, $(dir $(file))),$(file))))
-include $(objs:.o=.P)
$(foreach src,$(SRCS_$(tar)),$(eval $(value ADD_OBJ_RULE)))
endif
ifneq ($(strip $(out_exe_$(tar))),)
$(warning1 into 3ADD_TAR_RULE)
	ifneq ($(filter ${CXX_SRC_EXTS},${SRCS_${tar}}),)
        linker = ${CXX}
    else
        linker = ${CC}
    endif
objsdir:=$(outdir_$(tar))/obj_$(outname_exe_$(tar))
$(warning1 objsdir$(objsdir))
ifndef $(objsdir)_RULE_IS_DEFINED
$(objsdir):
	@mkdir -p $@
$(objsdir)_RULE_IS_DEFINED := 1
endif

objs:=$(patsubst %,$(objsdir)/%.o,$(basename $(notdir $(SRCS_$(tar)))))
$(out_exe_$(tar))::$(outdir_$(tar))
$(out_exe_$(tar))::tar:=$(tar)
$(out_exe_$(tar))::linker:=$(linker)
$(out_exe_$(tar))::
$(out_exe_$(tar))::$(objs) $$(outdeps_$(tar))$$(warning outdep=$$(outdeps_$(tar)))
	$(call echo_cmd,LINK $(call to_locpath,$@,$(call tar_dir,$(tar)))<=$(call to_locpath,$(warning outdep_flags_$(tar)=$(outdep_flags_$(tar)))$(warning ^=$(^))$^,$(call tar_dir,$(tar))))$(linker) -Wl,--start-group $^ $(outdep_flags_$(tar)) $(LDFLAGS_$(tar)) -Wl,--end-group -Wl,-rpath-link,$(outdir_$(tar)) -Wl,-rpath,. -o $(@)
	
$(tar)::$(out_exe_$(tar))
$(tar)::$$(wildcard $$(sort $$(filter-out %.a,$$(deps_$(tar)) $$(dep_flags_$(tar)))))
	$(if $^,cp -u -t $(outdir_$@) $(foreach file,$^,$(if $(filter-out $(outdir_$@)/, $(dir $(file))),$(file))))
	
$(warning1 into 3.5ADD_TAR_RULE)
-include $(objs:.o=.P)
$(foreach src,$(SRCS_$(tar)),$(eval $(value ADD_OBJ_RULE)))
endif
endif
endif
$(warning1 into 4ADD_TAR_RULE)
endef
############################以上为定义tar规则使用的程式

############################程序主要流程，此前已经执行的有包含TOP_RUL，定义基本常量
$(eval $(call include_dir_rul,$(TOP)))
$(warning1 TARGETS_ALL $(TARGETS_ALL))
$(foreach tar,$(TARGETS_ALL),$(warning1 tryin ADD_TAR_RULE,$(tar))$(eval $(value ADD_TAR_RULE)))



$(warning1 $(CURDIR))
$(warning1 $(TARGETS_$(CURDIR)))
