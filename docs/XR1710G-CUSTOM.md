# XR1710G custom build

This fork configuration keeps the XR1710G stock partition / chainloader layout,
Linux 6.18.60, Airoha NPU support, and the selected LuCI applications.

## Changes

- Default shadcn theme and Tailscale Community LuCI panel.
- Factory identity, fan/NPU, Mesh, MLO, network-mode, terminal, UPnP, KMS,
  Wi-Fi history and Wi-Fi scheduling applications selected in `1710.config`.
- Preserve upstream hiding of the Plugins and Switch/VLAN menu entries.
- Default SSIDs: Gemtek_XR1710G_2.4G, Gemtek_XR1710G_5G, Gemtek_XR1710G_6G.
- Public build uses the upstream example password 12345678. Set a private
  wireless password before deploying; personal credentials are not committed.
- Neutral distribution branding and download-link labels; retain source
  attribution and working upstream download URLs.
- Fix the Airoha PPE helper declaration and two MT76 patch compatibility issues.
- Use current DAWN native 6 GHz support and matching Mesh configuration names.
- Support factory data under the split stock `dsd` and `uenv` partitions.

## Build

```sh
./scripts/feeds update -a
./scripts/feeds install -a
bash scripts/select-feed-providers.sh
FEED_PATCHES_STRICT=1 bash scripts/apply-feed-patches.sh
cp 1710.config .config
make defconfig
bash scripts/set-build-version.sh .config
make download -j8
make -j8 world
```

The normal image supports `gemtek,xr1710g`. Legacy firmware sometimes reports
`gemtek,xr1710g-ubi` despite using the stock-chainloader layout. The old board
alias is opt-in: pass `XR1710G_LEGACY_CHAINLOADER_COMPAT=1` to the build command
ONLY after verifying chainloader at 0x600000 and UBI at 0x700000. This option
must never be used for a full-NAND OpenWrt U-Boot UBI layout. The alias is not
a conversion between layouts.

## Validation and limits

The private build with these functional changes completed a full world build
and artifact/profile checks. Its transition image and subsequent Wi-Fi build
were reported to boot successfully on an XR1710G. The factory-plugin fix was
tested through live RPC reads; original factory partitions retained identical
hashes. Factory write operations were not exercised. The public example
password and opt-in compatibility default differ from that private build;
a fresh complete build of this public configuration has not been performed.
