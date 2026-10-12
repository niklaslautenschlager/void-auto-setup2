# shellcheck shell=bash
# lib/hardware.sh: hardware detection straight from sysfs. No pciutils needed,
# and no string matching on vendor names: the original matched "*ati*",
# which also matches "Corporation" (Hyper-V guests became "AMD").

# PCI vendor IDs
readonly V_INTEL=0x8086 V_AMD=0x1002 V_AMD_CPU=0x1022 V_NVIDIA=0x10de
readonly V_VIRTIO=0x1af4 V_QXL=0x1b36 V_VMWARE=0x15ad V_VBOX=0x80ee
readonly V_BOCHS=0x1234 V_HYPERV=0x1414 V_CIRRUS=0x1013

SYSFS="${VPI_SYSFS:-/sys}"

GPU_VENDORS=()       # intel amd nvidia virtual (unique)
NVIDIA_DEVIDS=()     # device ids of NVIDIA GPUs
HAS_INTEL_AMD_AUDIO=0
HAS_BLUETOOTH=0
CPU_VENDOR=""        # intel | amd | ""
VM_KIND=""           # qemu | vmware | virtualbox | hyperv | ""

_add_gpu() { in_list "$1" "${GPU_VENDORS[@]}" || GPU_VENDORS+=("$1"); }

detect_hardware() {
  local d class vendor device
  for d in "$SYSFS"/bus/pci/devices/*; do
    [ -r "$d/class" ] || continue
    class=$(<"$d/class") vendor=$(<"$d/vendor") device=$(<"$d/device")
    case "$class" in
      0x0300*|0x0302*|0x0380*)                         # VGA / 3D / display
        case "$vendor" in
          "$V_INTEL")  _add_gpu intel ;;
          "$V_AMD")    _add_gpu amd ;;
          "$V_NVIDIA") _add_gpu nvidia; NVIDIA_DEVIDS+=("$device") ;;
          "$V_VIRTIO"|"$V_QXL"|"$V_VMWARE"|"$V_VBOX"|"$V_BOCHS"|"$V_HYPERV"|"$V_CIRRUS")
                       _add_gpu virtual ;;
        esac ;;
      0x0401*|0x0403*|0x0480*)                         # audio / HDA / AMD ACP
        case "$vendor" in "$V_INTEL"|"$V_AMD"|"$V_AMD_CPU") HAS_INTEL_AMD_AUDIO=1 ;; esac ;;
    esac
  done

  compgen -G "$SYSFS/class/bluetooth/hci*" >/dev/null && HAS_BLUETOOTH=1
  case "$(grep -m1 vendor_id "${VPI_CPUINFO:-/proc/cpuinfo}" 2>/dev/null || true)" in
    *GenuineIntel*) CPU_VENDOR=intel ;;
    *AuthenticAMD*) CPU_VENDOR=amd ;;
  esac

  local dmi
  dmi="$(cat "$SYSFS"/class/dmi/id/sys_vendor "$SYSFS"/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)"
  case "$dmi" in
    *qemu*|*kvm*|*bochs*) VM_KIND=qemu ;;
    *vmware*)             VM_KIND=vmware ;;
    *virtualbox*|*innotek*) VM_KIND=virtualbox ;;
    *microsoft*virtual*|*hyper-v*) VM_KIND=hyperv ;;
  esac
}

# nvidia_pkg_for DEVICE_ID: Void driver package per handbook table.
#   Turing+ (TU1xx, device >= 0x1e00)       -> nvidia      (595, open modules)
#   Maxwell..Volta (0x1340-0x1dff)          -> nvidia580
#   Kepler (GK1xx)                          -> nvidia470
#   Fermi (GF1xx)                           -> nvidia390
#   older (Tesla)                           -> "" (nouveau only)
nvidia_pkg_for() {
  local id=$(( $1 ))
  if   (( id >= 0x1e00 )); then echo nvidia
  elif (( id >= 0x1340 )); then echo nvidia580
  elif (( id >= 0x0fc0 && id <= 0x103f )) || (( id >= 0x1180 && id <= 0x11ff )) \
    || (( id >= 0x1280 && id <= 0x12ff )); then echo nvidia470
  elif (( id >= 0x06c0 && id <= 0x06df )) || (( id >= 0x0dc0 && id <= 0x0e3f )) \
    || (( id >= 0x1040 && id <= 0x10bf )) || (( id >= 0x1140 && id <= 0x117f )) \
    || (( id >= 0x1200 && id <= 0x127f )); then echo nvidia390
  else echo ""
  fi
}

# nvidia_suggested_pkg: the newest driver branch every detected card supports
nvidia_suggested_pkg() {
  local id pkg best="" rank=9 r
  for id in "${NVIDIA_DEVIDS[@]}"; do
    pkg="$(nvidia_pkg_for "$id")"
    case "$pkg" in nvidia) r=4 ;; nvidia580) r=3 ;; nvidia470) r=2 ;; nvidia390) r=1 ;; *) r=0 ;; esac
    if (( r < rank )); then rank=$r best=$pkg; fi
  done
  echo "$best"
}

# installed_kernel_series: "6.18 6.12" from installed linuxX.Y packages
installed_kernel_series() {
  local out
  out="$(xbps-query -l 2>/dev/null | awk '{print $2}' | sed -nE 's/^linux([0-9]+\.[0-9]+)-[0-9].*/\1/p' | sort -u)"
  [ -n "$out" ] || out="$(uname -r | sed -nE 's/^([0-9]+\.[0-9]+).*/\1/p')"
  echo "$out"
}
