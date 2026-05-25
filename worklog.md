# Work Log

## 2025-05-25: Port multigw+fix patches to Linux 6.18.33

### Task
Port the Julian Anastasov multi-GW patch and the multi-GW fix patch to Linux 6.18.33.

### What was done

#### Patch 1: Multi-GW (commit e3e904247)
Manually applied changes to 14 files:

1. **include/net/flow.h** - Added `FLOWI_FLAG_SKIP_NH_OIF 0x10`, `fl4_gw` field to `struct flowi4`, and `fl4->fl4_gw = 0` init in `flowi4_init_output()`
2. **include/net/ip_fib.h** - Added declarations for `fib_result_table()`, `fib_nhflags_lock`, `fib_select_default()`
3. **include/net/netfilter/nf_nat.h** - Added `ip_nat_route_input()` declaration
4. **include/net/route.h** - Added `ip_route_input_common_rcu()` and `ip_route_input_lookup()` declarations
5. **include/uapi/linux/rtnetlink.h** - Added `RTNH_F_SUSPECT 128`, `RTNH_F_BADSTATE`, updated `RTNH_COMPARE_MASK`
6. **net/bridge/br_netfilter_hooks.c** - Added `skb_dst_drop(skb)` before `ip_route_input()` call
7. **net/ipv4/fib_rules.c** - Added `fib_result_table()` implementation
8. **net/ipv4/fib_frontend.c** - Added `FIB_RES_TABLE()` macros, `fl4.fl4_gw = 0` init, rewrote RPF validation logic in `__fib_validate_source()`, removed `#ifdef CONFIG_IP_ROUTE_MULTIPATH` guards around `fib_sync_up()` calls
9. **net/ipv4/fib_trie.c** - Added `fl4_gw` check in `fib_lookup_good_nhc()`
10. **net/ipv4/route.c** - Added `lsrc` parameter to `__mkroute_input()`, `ip_mkroute_input()`, `ip_route_input_slow()`; added `fib_select_default()` call; added lsrc validation; renamed `ip_route_input_rcu` to `ip_route_input_common_rcu()` with lsrc param; added `ip_route_input_rcu()` wrapper and `ip_route_input_lookup()`; added `fl4_gw = 0` in output route paths
11. **net/ipv4/fib_semantics.c** - Added `DEFINE_RWLOCK(fib_nhflags_lock)`; rewrote `fib_detect_death()` for multipath/SUSPECT; made `fib_select_default()` non-static; added `last_nhsel` param; added `fib_nhflags_lock` around nh_flags; added RTPROT_STATIC support for dead nexthops; added gateway re-lookup in `fib_sync_up()` with `repeat` loop; rewrote `fib_select_path()` to always call `fib_select_default()` for RTN_UNICAST
12. **net/ipv4/netfilter/iptable_nat.c** - Added `route_input_ops` field, `ip_nat_route_input_ops` hook definition, registration/unregistration
13. **net/netfilter/nf_nat_core.c** - Added `#include <net/ip.h>` and `#include <net/route.h>`; added `ip_nat_route_input()` implementation
14. **net/netfilter/nf_nat_masquerade.c** - Added `#include <net/route.h>`; rewrote masquerade address selection using `fl4_gw`-based route lookup

#### Patch 2: Multi-GW Fix (commit 51e680fb7)
Applied changes to 2 files:

1. **net/netfilter/nf_nat_core.c** - Added `#include <linux/inetdevice.h>`; enhanced `ip_nat_route_input()` with `multi_gw_ifindex` handling: when no NAT status but `multi_gw_ifindex` is set, select address from that device and call `ip_route_input_lookup()`
2. **include/net/netfilter/nf_conntrack.h** - Added `int multi_gw_ifindex` field to `struct nf_conn`

### Build Test Results
All 8 affected .o files compiled successfully:
- net/ipv4/route.o ✅
- net/ipv4/fib_semantics.o ✅
- net/ipv4/fib_frontend.o ✅
- net/ipv4/fib_rules.o ✅
- net/ipv4/fib_trie.o ✅
- net/ipv4/netfilter/iptable_nat.o ✅
- net/netfilter/nf_nat_core.o ✅
- net/netfilter/nf_nat_masquerade.o ✅

Note: drivers/net/ifb.ko failed due to a pre-existing `from_ingress` issue unrelated to our patches.

### Git Commit Hashes
- Patch 1 (multigw): `e3e904247`
- Patch 2 (multigw-fix): `51e680fb7`

### Generated Patch Files
- `/home/z/my-project/kernel-work/patches/0001-multigw-6.18.33-new.patch`
- `/home/z/my-project/kernel-work/patches/0004-multigw-fix-6.18.33-new.patch`

### Issues Encountered
- The original patch files could not be applied cleanly with `git apply` due to whitespace/context mismatches, so all changes were applied manually
- 6.18.33 uses `dscp_t` type instead of `u8 tos` — all function signatures were updated accordingly
- 6.18.33 uses `enum skb_drop_reason` return types instead of `int` — maintained correctly
- Used `ip4h_dscp(iph)` instead of `iph->tos` for dscp parameter in `ip_route_input_lookup()` calls

## 2025-05-25: Generate 6.18.33 gateway NAS kernel .config

### Task
Generate a full kernel .config for Linux 6.18.33 that matches the gateway NAS device requirements from a working 5.4.71 config.

### Source Materials
- Working 5.4.71 gateway/NAS config: `/tmp/config-5.4-working.txt` (4352 CONFIG_ lines)
- Kernel source: `/home/z/my-project/kernel-work/linux-6.18.33/`
- Build env: `/home/z/my-project/kernel-work/env.sh`

### Strategy
1. Started from `x86_64_defconfig` baseline for 6.18.33
2. Created a comprehensive config fragment (`/tmp/gateway-nas-fragment.config`) with all gateway-critical options
3. Used `scripts/kconfig/merge_config.sh` to merge the fragment into the baseline
4. Ran `make olddefconfig` to resolve all dependencies
5. Iteratively fixed missing dependencies (legacy xtables, I40EVF→IAVF, etc.)
6. Verified all critical options

### Key Renames / Structural Changes from 5.4 → 6.18
- `CONFIG_IP_NF_NAT` now depends on `CONFIG_IP_NF_IPTABLES_LEGACY` (new in 6.18)
- `CONFIG_IP6_NF_NAT` now depends on `CONFIG_IP6_NF_IPTABLES_LEGACY`
- Both legacy options depend on `CONFIG_NETFILTER_XTABLES_LEGACY=y`
- `CONFIG_IAVF` is now a hidden symbol selected by `CONFIG_I40EVF=m`
- `CONFIG_EXT3_FS` removed — ext3 is handled by ext4 driver
- `CONFIG_NF_LOG_NETDEV` renamed to `CONFIG_NF_LOG_SYSLOG`
- `CONFIG_MODVERSIONS` now conflicts with `CONFIG_GENDWARFKSYMS`
- `CONFIG_MAXSMP` now requires `CONFIG_DEBUG_KERNEL=y`
- `CONFIG_IFB=m` depends on `CONFIG_NET_ACT_MIRRED` or `CONFIG_NFT_FWD_NETDEV`

### Removed in 6.18 (no longer in Kconfig)
- `CONFIG_NET_SCH_CBQ` — removed (use HTB)
- `CONFIG_NET_SCH_ATM` — removed (ATM qdisc deprecated)
- `CONFIG_NET_SCH_DSMARK` — removed
- `CONFIG_NET_CLS_TCINDEX` — removed
- `CONFIG_NET_CLS_RSVP` / `CONFIG_NET_CLS_RSVP6` — removed
- `CONFIG_IP_NF_TARGET_NFMOD` / `CONFIG_IP_NF_NFMOD` — removed

### Final Config Verification Results

All 19 CRITICAL options verified as set:
| Option | Value |
|--------|-------|
| `CONFIG_LOCALVERSION` | "-NMR-IFB" |
| `CONFIG_NET_REDIRECT` | y |
| `CONFIG_IFB` | m |
| `CONFIG_IP_MULTIPLE_TABLES` | y |
| `CONFIG_IP_ROUTE_MULTIPATH` | y |
| `CONFIG_NF_CONNTRACK` | m |
| `CONFIG_NF_NAT` | m |
| `CONFIG_NETFILTER_XT_NAT` | m |
| `CONFIG_IP_NF_TARGET_MASQUERADE` | m |
| `CONFIG_NET_SCHED` | y |
| `CONFIG_BRIDGE` | m |
| `CONFIG_VLAN_8021Q` | m |
| `CONFIG_NETFILTER_XT_TARGET_MASQUERADE` | m |
| `CONFIG_NETFILTER_XT_TARGET_REDIRECT` | m |
| `CONFIG_NETFILTER_XT_MATCH_CONNTRACK` | m |
| `CONFIG_NETFILTER_XT_MATCH_MARK` | m |
| `CONFIG_NETFILTER_XT_SET` | m |
| `CONFIG_NF_NAT_REDIRECT` | y |
| `CONFIG_NF_NAT_MASQUERADE` | y |

### Config Statistics
- Total CONFIG_ lines: 2637
- Built-in (=y): 1813
- Module (=m): 694
- String values: 27

### All Category Status
- **Core kernel**: ✅ MODULES, UNLOAD, MODVERSIONS, PREEMPT_VOLUNTARY, HZ_1000, MAXSMP, HOTPLUG_CPU
- **Networking core**: ✅ NET, INGRESS, EGRESS, REDIRECT, SKB_EXTENSIONS, XFRM with all sub-options
- **IPv4 routing**: ✅ MULTIPLE_TABLES, ROUTE_MULTIPATH, FIB_TRIE_STATS, ROUTE_CLASSID
- **Tunnels**: ✅ IPIP, IPGRE, IP_TUNNEL, SIT, VTI, VXLAN
- **Netfilter**: ✅ All conntrack helpers, NAT, nftables, xtables, flow table
- **IP tables NAT**: ✅ (via NETFILTER_XTABLES_LEGACY → IP_NF_IPTABLES_LEGACY → IP_NF_NAT)
- **QoS/Traffic Control**: ✅ All modern qdiscs (HTB, HFSC, SFQ, FQ_CODEL, etc.), CBQ/ATM/DSMARK removed upstream
- **Classifiers**: ✅ U32, FLOW, FLOWER, BPF, MATCHALL, CGROUP, etc.; RSVP/TCINDEX removed upstream
- **Bridge/VLAN**: ✅ BRIDGE, IGMP_SNOOPING, VLAN_FILTERING, 8021Q, GVRP, MVRP
- **WiFi**: ✅ CFG80211, MAC80211, RFKILL
- **Storage/FS**: ✅ EXT4, XFS, BTRFS, FUSE, SQUASHFS, NFS, CIFS, NTFS3, FSCACHE
- **RAID/MD/DM**: ✅ MD, RAID0/1/10/456, DM_CRYPT/SNAPSHOT/MIRROR/VERITY, THROTTLING
- **SCSI/ATA**: ✅ SCSI, SD, SR, ATA, PIIX, AHCI, PATA_AMD
- **Network drivers**: ✅ E1000/E1000E/IGB/IXGBE/I40E/ICE, R8169, BNX2/TIGON3/BNX2X, MLX4/5
- **Virtualization**: ✅ KVM, VHOST
- **Crypto**: ✅ AES, SHA, HMAC, GCM, XTS, AES_NI_INTEL
- **ACPI/Power**: ✅ Full ACPI, CPU_FREQ, INTEL_PSTATE
- **IFB**: ✅ CONFIG_IFB=m (critical for IMQ rename patch)

### Output
- Final `.config` saved at: `/home/z/my-project/kernel-work/linux-6.18.33/.config`
- Not committed to git yet
