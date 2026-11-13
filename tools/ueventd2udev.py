#!/usr/bin/python3
"""Converte le righe /dev di ueventd.rc (Android) in regole udev per Ubuntu Touch.
Uso: ueventd2udev.py <ueventd.rc ...> [--group-file /vendor/etc/group] > 70-android.rules
Utenti e gruppi sono scritti come numeri (AID Android), cosi' valgono anche se il nome non esiste su UT."""
import sys, re
AID = {"root":0,"system":1000,"radio":1001,"bluetooth":1002,"graphics":1003,"input":1004,"audio":1005,
 "camera":1006,"log":1007,"compass":1008,"mount":1009,"wifi":1010,"adb":1011,"install":1012,"media":1013,
 "dhcp":1014,"sdcard_rw":1015,"vpn":1016,"keystore":1017,"usb":1018,"drm":1019,"mdnsr":1020,"gps":1021,
 "media_rw":1023,"mtp":1024,"drmrpc":1026,"nfc":1027,"sdcard_r":1028,"clat":1029,"loop_radio":1030,
 "mediadrm":1031,"package_info":1032,"logd":1036,"shared_relro":1037,"dbus":1038,"mediaex":1040,
 "audioserver":1041,"debuggerd":1045,"mediacodec":1046,"cameraserver":1047,"firewall":1048,"trunks":1049,
 "nvram":1050,"dns":1051,"dns_tether":1052,"webview_zygote":1053,"vehicle_network":1054,"media_audio":1055,
 "media_video":1056,"media_image":1057,"tombstoned":1058,"media_obb":1059,"ese":1060,"ota_update":1061,
 "automotive_evs":1062,"lowpan":1063,"hsm":1064,"reserved_disk":1065,"statsd":1066,"incidentd":1067,
 "secure_element":1068,"lmkd":1069,"llkd":1070,"iorapd":1071,"gpu_service":1072,"network_stack":1073,
 "gsid":1074,"fsverity_cert":1075,"credstore":1076,"external_storage":1077,"ext_data_rw":1078,
 "ext_obb_rw":1079,"context_hub":1080,"virtualizationservice":1081,"artd":1082,"uwb":1083,
 "thread_network":1084,"diced":1085,"dmesgd":1086,"prng_seeder":1092,"shell":2000,"cache":2001,"diag":2002,
 "net_bt_admin":3001,"net_bt":3002,"inet":3003,"net_raw":3004,"net_admin":3005,"net_bw_stats":3006,
 "net_bw_acct":3007,"readproc":3009,"wakelock":3010,"uhid":3011,"everybody":9997,"misc":9998,"nobody":9999}
args = sys.argv[1:]
if "--group-file" in args:
    i = args.index("--group-file"); gf = args[i+1]; del args[i:i+2]
    for line in open(gf, errors="replace"):
        p = line.strip().split(":")
        if len(p) >= 3 and p[2].isdigit():
            AID.setdefault(p[0], int(p[2]))
seen, out, unknown = set(), [], set()
for path in args:
    for line in open(path, errors="replace"):
        line = line.split("#")[0].strip()
        if not line.startswith("/dev/"):
            continue
        f = line.split()
        if len(f) < 4:
            continue
        dev, mode, user, group = f[:4]
        for n in (user, group):
            m = re.fullmatch(r"oem_(\d+)", n)
            if m: AID.setdefault(n, int(m.group(1)))
            if n not in AID: unknown.add(n)
        u, g = AID.get(user, 0), AID.get(group, 0)
        name = dev[len("/dev/"):]
        match = 'KERNEL=="%s"' % name if "/" not in name else 'DEVNAME=="%s"' % dev
        key = match
        if key in seen:      # in ueventd vince l'ultima definizione: la teniamo sovrascrivendo
            out = [o for o in out if not o.startswith("ACTION==\"add\", " + match + ",")]
        seen.add(key)
        out.append('ACTION=="add", %s, OWNER="%d", GROUP="%d", MODE="%s"' % (match, u, g, mode))
print("# Generato da ueventd.rc (system + vendor) con tools/ueventd2udev.py")
if unknown:
    print("# Nomi sconosciuti mappati a 0 (root): " + " ".join(sorted(unknown)))
print("\n".join(out))
