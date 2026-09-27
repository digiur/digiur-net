# Network Device Configuration Reference

## Calix GigaPoint 803G (ONT)

- Nextlight fiber modem (bridge/passthrough)

## Qotom Q355G4 (Router/Firewall — OPNsense)

- Domain: home.arpa
  - Really the "correct" option?
  - Hostname: opnsense
- WAN: DHCP from ISP
  - "Block bogon networks" and "Block RFC1918 Private Networks" set
  - This correct?
- LAN: Renamed 'Mgmt': `10.0.99.1/24`
  - VLAN trunk to GS108E
  - The GS108E management IP lives here
- VLANs: All have Mgmt(LAN) as parent
  - VLAN 40 - Trusted - 10.0.40.0/24
  - VLAN 20 - Servers - 10.0.20.0/24
  - VLAN 30 - IoT-General - 10.0.30.0/24
  - VLAN 10 - TV - 10.0.10.0/24
  - VLAN 50 - Solar - 10.0.50.0/24
  - VLAN 90 - Roommate/Guest - 10.0.90.0/24
- Firewall rules:

  | Seq | Interface (VLAN) | Action | Source | Destination | Port/Protocol | Notes |
  | - | - | - | - | - | - | - |
  | 1 | Mgmt (LAN) | pass | LAN net | any | any | Default allow LAN to any rule |
  | 11 | Mgmt (LAN) | pass | LAN net (IPv6) | any | any | Default allow LAN IPv6 to any rule |
  | 111 | Trusted (40) | pass | Trusted net | any | any | Trusted to anywhere |
  | 161 | IoT (30) | **block** | IoT net | `private_ranges` | any | IoT to nowhere |
  | 211 | IoT (30) | pass | IoT net | any | any | IoT internet access |
  | 261 | Servers (20) | **block** | Servers net | `private_ranges` | any | Servers to nowhere |
  | 311 | Servers (20) | pass | Servers net | any | any | Servers internet access |
  | 361 | Solar (50) | **block** | Solar net | `private_ranges` | any | Solar to nowhere |
  | 411 | Solar (50) | pass | Solar net | any | any | Solar internet access |
  | 461 | Guest (90) | **block** | Guest net | `private_ranges` | any | Guest to nowhere |
  | 511 | Guest (90) | pass | Guest net | any | any | Guest internet access |
  | 536 | TV (10) | pass | TV net | `n100` | 8096/TCP | TV to jellyfin |
  | 548 | TV (10) | pass | TV net | `n100` | 8096/UDP | TV to jellyfin |
  | 561 | TV (10) | **block** | TV net | `private_ranges` | any | TV to nowhere |
  | 611 | TV (10) | pass | TV net | any | any | TV internet access |

## Netgear GS108E (Switch)

- Static reservation: `netgear` / `10.0.99.2`
- Port Table:

  | Port | VLAN | Device |
  | - | - | - |
  | 1 | 40 | Personal Workstation |
  | 2 | 20 | Spare |
  | 3 | 20 | n100 Mini PC |
  | 4 | 20 | WD MyCloud EX2 Ultra |
  | 5 | 20 | Spare |
  | 6 | 90 | "Guest" (Roomate's) switch (unknown make/model) |
  | 7 | Trunk | Trunk to MikroTik cAP ax Access Point |
  | 8 | Trunk | Trunk to OPNsense |

- Vlan table:

  | | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
  | - | - | - | - | - | - | - | - | - |
  | 1 |  |  |  |  |  |  | U | U |
  | 10 |  |  |  |  |  |  | T | T |
  | 20 |  | U | U | U | U |  |  | T |
  | 30 |  |  |  |  |  |  | T | T |
  | 40 | U |  |  |  |  |  | T | T |
  | 50 |  |  |  |  |  |  | T | T |
  | 90 |  |  |  |  |  | U | T | T |

## MikroTik cAP ax (Access Point)

- Static reservation: `capax` / `10.0.99.3`
- SSIDs:

  | SSID | Interface | VLAN |
  | --- | --- | --- |
  | `digiurnet-trusted` | `wifi1` (5GHz) | 40 |
  | `digiurnet` | `wifi2` (2.4GHz) | 90 |
  | `digiurnet-iot` | `wifi3` (virtual) | 30 |
  | `digiurnet-tv` | `wifi4` (virtual) | 10 |
  | `digiurnet-infra` | `wifi5` (virtual) | 50 |

- Bridge VLAN table:

  |  | bridge | ether1 | wifi1 | wifi2 | wifi3 | wifi4 | wifi5 |
  | - | - | - | - | - | - | - | - |
  |  1 | U | U |  |  |  |  |  |
  | 10 |  | T |  |  |  | U |  |
  | 30 |  | T |  |  | U |  |  |
  | 40 |  | T | U |  |  |  |  |
  | 50 |  | T |  |  |  |  | U |
  | 90 |  | T |  | U |  |  |  |

## Beelink Mini PC, 12th Gen Intel N100 (n100)

- Static reservation: `n100` / `10.0.20.x` (VLAN 20 - Servers)

## Western Digital MyCloud EX2 Ultra (mycloud)

- Static reservation: `mycloud` / `10.0.20.x` (VLAN 20 - Servers)
