include $(TOPDIR)/rules.mk

PKG_NAME:=xr1710g-link-recovery
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKG_LICENSE:=GPL-2.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/xr1710g-link-recovery
  SECTION:=net
  CATEGORY:=Network
  TITLE:=XR1710G bounded 10G DHCP link recovery
  DEPENDS:=@TARGET_airoha_an7581 +tcpdump +ip-full
endef

define Package/xr1710g-link-recovery/description
  Detect repeated client DHCP Discover/Offer exchanges without a Request
  on XR1710G lan2 and perform bounded recovery of a confirmed 10G link.
  This mitigates a link-up/no-RX interoperability failure; it is not a
  replacement for an eventual PHY/PCS root-cause fix.
endef

define Package/xr1710g-link-recovery/conffiles
/etc/config/xr1710g_link_recovery
endef

define Build/Compile
endef

define Package/xr1710g-link-recovery/install
	$(INSTALL_DIR) $(1)/usr/sbin $(1)/usr/share/xr1710g-link-recovery $(1)/etc/init.d $(1)/etc/config
	$(INSTALL_BIN) ./files/xr1710g-link-recovery $(1)/usr/sbin/
	$(INSTALL_DATA) ./files/dhcp-monitor.awk $(1)/usr/share/xr1710g-link-recovery/
	$(INSTALL_BIN) ./files/init $(1)/etc/init.d/xr1710g-link-recovery
	$(INSTALL_CONF) ./files/config $(1)/etc/config/xr1710g_link_recovery
endef

$(eval $(call BuildPackage,xr1710g-link-recovery))
