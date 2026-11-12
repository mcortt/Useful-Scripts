import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

XML_FILE = "running-config.xml"

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{title}</title>
  <style>
    html, body {{ margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background: #1e1e1e; }}
    #diagram, #diagram svg {{ width: 100%; height: 100%; }}
  </style>
  <script src="https://cdn.jsdelivr.net/npm/svg-pan-zoom@3.6.1/dist/svg-pan-zoom.min.js"></script>
  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
    mermaid.initialize({{
      startOnLoad: false,
      theme: 'dark',
      maxEdges: 10000,
      maxTextSize: 1000000,
      flowchart: {{ useMaxWidth: false }}
    }});
    const el = document.getElementById('diagram');
    const {{ svg }} = await mermaid.render('graphDiv', el.textContent);
    el.innerHTML = svg;
    const svgEl = el.querySelector('svg');
    svgEl.removeAttribute('style');
    svgPanZoom(svgEl, {{ zoomEnabled: true, panEnabled: true, controlIconsEnabled: true, maxZoom: 100, minZoom: 0.05 }});
  </script>
</head>
<body>
  <div id="diagram">
{mmd_code}
  </div>
</body>
</html>
"""

def clean_id(prefix: str, name: str) -> str:
    return f"{prefix}_{re.sub(r'[^a-zA-Z0-9_]', '_', name)}"

def build_management_hierarchy(root: ET.Element) -> str:
    lines = ["graph LR"]

    for dg in root.findall(".//device-group/entry"):
        dg_name = dg.get("name", "unknown")
        dg_id = clean_id("DG", dg_name)
        lines.append(f'    {dg_id}["DG: {dg_name}"]')

        parent = dg.find("./parent-dg")
        if parent is not None and parent.text:
            lines.append(f'    {clean_id("DG", parent.text)} --> {dg_id}')

        for dev in dg.findall("./devices/entry"):
            serial = dev.get("name", "unknown")
            lines.append(f'    {dg_id} --> {clean_id("FW", serial)}("FW: {serial}")')

    for ts in root.findall(".//template-stack/entry"):
        ts_name = ts.get("name", "unknown")
        ts_id = clean_id("TS", ts_name)
        lines.append(f'    {ts_id}{{"Stack: {ts_name}"}}')

        for tmpl in ts.findall("./templates/member"):
            if tmpl.text:
                lines.append(f'    {clean_id("T", tmpl.text)}["Template: {tmpl.text}"] -.-> {ts_id}')

        for dev in ts.findall("./devices/entry"):
            serial = dev.get("name", "unknown")
            lines.append(f'    {ts_id} -.-> {clean_id("FW", serial)}')

    return "\n".join(lines)

def build_logical_topology(root: ET.Element) -> str:
    lines = ["graph TD"]

    for tmpl in root.findall(".//template/entry"):
        t_name = tmpl.get("name", "unknown")
        t_id = clean_id("TMPL", t_name)

        net_node = tmpl.find("./config/devices/entry/network")
        vsys_node = tmpl.find("./config/devices/entry/vsys/entry")
        if net_node is None and vsys_node is None:
            continue

        lines.append(f'    subgraph {t_id} ["Template: {t_name}"]')

        if vsys_node is not None:
            for zone in vsys_node.findall("./zone/entry"):
                z_name = zone.get("name", "unknown")
                z_id = clean_id(f"{t_id}_Z", z_name)
                lines.append(f'        {z_id}(["Zone: {z_name}"])')
                for member in zone.findall(".//member"):
                    if member.text:
                        if_id = clean_id(f"{t_id}_IF", member.text)
                        lines.append(f'        {z_id} --- {if_id}["{member.text}"]')

        if net_node is not None:
            # Supports both legacy <virtual-router> and PAN-OS 10.2+ <logical-router>
            vrs = net_node.findall("./virtual-router/entry") + net_node.findall("./logical-router/entry")
            for vr in vrs:
                vr_name = vr.get("name", "unknown")
                vr_id = clean_id(f"{t_id}_VR", vr_name)
                lines.append(f'        {vr_id}{{"VRF: {vr_name}"}}')

                for iface in vr.findall(".//interface/member"):
                    if iface.text:
                        if_id = clean_id(f"{t_id}_IF", iface.text)
                        lines.append(f'        {if_id}["{iface.text}"] --> {vr_id}')

                for sr in vr.findall(".//routing-table/ip/static-route/entry"):
                    dest = sr.findtext("./destination", default="")
                    next_vr = sr.findtext("./nexthop/next-vr")
                    next_ip = sr.findtext("./nexthop/ip-address")

                    if next_vr:
                        target_vr_id = clean_id(f"{t_id}_VR", next_vr)
                        lines.append(f'        {vr_id} ==>|"{dest} (next-vr)"| {target_vr_id}')
                    elif next_ip:
                        nh_id = clean_id(f"{t_id}_NH", next_ip)
                        lines.append(f'        {vr_id} -->|"{dest}"| {nh_id}(("GW: {next_ip}"))')

                for peer in vr.findall(".//protocol/bgp/peer-group/entry/peer/entry"):
                    p_name = peer.get("name", "peer")
                    p_ip = peer.findtext("./peer-address/ip", default=p_name)
                    p_as = peer.findtext("./peer-as", default="?")
                    bgp_id = clean_id(f"{t_id}_BGP", p_ip)
                    lines.append(f'        {vr_id} <-->|"BGP AS{p_as}"| {bgp_id}(("Peer: {p_ip}"))')

        lines.append("    end")

    return "\n".join(lines)

def write_outputs(base_name: str, title: str, mmd_code: str) -> None:
    mmd_path = Path(f"{base_name}.mmd")
    html_path = Path(f"{base_name}.html")

    mmd_path.write_text(mmd_code, encoding="utf-8")
    html_path.write_text(HTML_TEMPLATE.format(title=title, mmd_code=mmd_code), encoding="utf-8")
    print(f"Generated {mmd_path} and {html_path}")

def main() -> None:
    if len(sys.argv) > 1:
        xml_path = Path(sys.argv[1])
    elif Path("running-config.xml").exists():
        xml_path = Path("running-config.xml")
    else:
        xml_path = Path("running_config.xml")
    if not xml_path.exists():
        print(f"Error: Could not find '{xml_path}'")
        sys.exit(1)

    root = ET.parse(xml_path).getroot()

    arch_mmd = build_management_hierarchy(root)
    write_outputs("panorama_arch", "Panorama Management & Device Hierarchy", arch_mmd)

    logical_mmd = build_logical_topology(root)
    write_outputs("panorama_logical_vrfs", "Panorama Logical Architecture (VRFs & Zones)", logical_mmd)

if __name__ == "__main__":
    main()