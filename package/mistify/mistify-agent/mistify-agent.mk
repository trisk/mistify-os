################################################################################
#
# mistify-agent
#
################################################################################

MISTIFY_AGENT_VERSION = 9a8f64940157fbf2c1f68e65ff0d0fa1df57bba5
MISTIFY_AGENT_SITE    = https://github.com/mistifyio/mistify-agent.git
MISTIFY_AGENT_SITE_METHOD = git
MISTIFY_AGENT_LICENSE = Apache
MISTIFY_AGENT_LICENSE_FILES = LICENSE
MISTIFY_AGENT_DEPENDENCIES = systemd

GOPATH=$(O)/tmp/GOPATH

define MISTIFY_AGENT_BUILD_CMDS
	# GO apparently wants the install path to be independent of the
	# build path. Use a temporary directory to do the build.
	mkdir -p $(GOPATH)/src/github.com/mistifyio/mistify-agent
	rsync -av --delete-after --exclude=.git --exclude-from=$(@D)/.gitignore \
		$(@D)/ $(GOPATH)/src/github.com/mistifyio/mistify-agent/
	PATH=$(GOROOT)/bin:$(PATH) \
        GOPATH=$(GOPATH) make install DESTDIR=$(TARGET_DIR) \
		-C $(GOPATH)/src/github.com/mistifyio/mistify-agent

endef

define MISTIFY_AGENT_INSTALL_TARGET_CMDS
	# The install was done as part of the build.
endef

define MISTIFY_AGENT_INSTALL_INIT_SYSTEMD
	$(INSTALL) -m 644 -D $(BR2_EXTERNAL)/package/mistify/mistify-agent/mistify-agent.service \
		$(TARGET_DIR)/lib/systemd/system/mistify-agent.service

	$(INSTALL) -m 644 -D $(BR2_EXTERNAL)/package/mistify/mistify-agent/mistify-agent.sysconfig \
		$(TARGET_DIR)/etc/sysconfig/mistify-agent
endef

$(eval $(generic-package))
