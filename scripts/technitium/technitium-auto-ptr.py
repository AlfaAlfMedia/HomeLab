#!/usr/bin/env python3
"""
Technitium DNS Auto-PTR Generator
==================================
Automatically creates PTR (reverse DNS) records for all A and AAAA records in a zone.

Author: AlfaAlfMedia
Repository: https://github.com/AlfaAlfMedia/HomeLab/tree/main/scripts/technitium
License: MIT

Requirements:
    - Python 3.6+
    - requests library (pip install requests)
    - Technitium DNS Server with API access

Usage:
    1. Edit the configuration section below
    2. Run: python3 technitium-auto-ptr.py
"""

import requests
import ipaddress
import sys
import json
from typing import List, Dict, Tuple

# ============================================================================
# CONFIGURATION - Edit these values
# ============================================================================

API_URL = "http://localhost:5380"
API_TOKEN = "YOUR_API_TOKEN_HERE"  # Get from Technitium Web UI -> Settings -> API
ZONE_NAME = "alfaalf-media.com"     # The forward zone to process

# Optional: Dry run mode - if True, only shows what would be done without making changes
DRY_RUN = False

# ============================================================================
# Script Logic - No need to edit below this line
# ============================================================================

class TechnitiumAPI:
    """Wrapper for Technitium DNS API"""
    
    def __init__(self, base_url: str, token: str):
        self.base_url = base_url.rstrip('/')
        self.token = token
        self.session = requests.Session()
    
    def _request(self, endpoint: str, params: Dict = None) -> Dict:
        """Make API request"""
        if params is None:
            params = {}
        params['token'] = self.token
        
        url = f"{self.base_url}/api/{endpoint}"
        try:
            response = self.session.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"❌ API Error: {e}")
            sys.exit(1)
    
    def get_zone_records(self, zone: str, record_type: str = None) -> List[Dict]:
        """Get all records from a zone"""
        params = {'domain': zone}
        if record_type:
            params['type'] = record_type
        
        result = self._request('zones/records/get', params)
        if result.get('status') == 'ok':
            return result.get('records', [])
        else:
            print(f"❌ Failed to get records: {result.get('errorMessage', 'Unknown error')}")
            return []
    
    def zone_exists(self, zone: str) -> bool:
        """Check if a zone exists"""
        result = self._request('zones/list')
        if result.get('status') == 'ok':
            zones = result.get('zones', [])
            return any(z.get('name') == zone for z in zones)
        return False
    
    def create_zone(self, zone: str) -> bool:
        """Create a new primary zone"""
        params = {'zone': zone, 'type': 'Primary'}
        result = self._request('zones/create', params)
        return result.get('status') == 'ok'
    
    def add_ptr_record(self, reverse_zone: str, ptr_name: str, target: str) -> bool:
        """Add a PTR record"""
        params = {
            'zone': reverse_zone,
            'domain': f"{ptr_name}.{reverse_zone}",
            'type': 'PTR',
            'ptrName': target,
            'ttl': 3600
        }
        result = self._request('zones/records/add', params)
        return result.get('status') == 'ok'


def ip_to_reverse_zone(ip: str) -> Tuple[str, str]:
    """
    Convert IP address to reverse zone name and PTR record name
    
    Returns:
        (reverse_zone, ptr_record_name)
        
    Examples:
        192.168.1.10 -> ('1.168.192.in-addr.arpa', '10')
        2001:db8::1 -> ('0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa', '1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0')
    """
    try:
        ip_obj = ipaddress.ip_address(ip)
        
        if isinstance(ip_obj, ipaddress.IPv4Address):
            # IPv4: 192.168.1.10 -> 1.168.192.in-addr.arpa + 10
            octets = ip.split('.')
            # Use /24 network for reverse zone (common practice)
            reverse_zone = f"{octets[2]}.{octets[1]}.{octets[0]}.in-addr.arpa"
            ptr_name = octets[3]
            return (reverse_zone, ptr_name)
            
        elif isinstance(ip_obj, ipaddress.IPv6Address):
            # IPv6: expand and reverse
            expanded = ip_obj.exploded.replace(':', '')
            reversed_nibbles = '.'.join(reversed(expanded))
            # Use /64 prefix (16 nibbles) for reverse zone
            reverse_zone = '.'.join(reversed_nibbles.split('.')[16:]) + '.ip6.arpa'
            ptr_name = '.'.join(reversed_nibbles.split('.')[:16])
            return (reverse_zone, ptr_name)
            
    except ValueError as e:
        print(f"⚠️  Invalid IP address: {ip} - {e}")
        return (None, None)


def main():
    print("=" * 70)
    print("Technitium DNS Auto-PTR Generator")
    print("=" * 70)
    print()
    
    # Validate configuration
    if API_TOKEN == "YOUR_API_TOKEN_HERE":
        print("❌ ERROR: Please configure your API_TOKEN in the script!")
        print("   Get your token from: Technitium Web UI -> Settings -> API")
        sys.exit(1)
    
    if DRY_RUN:
        print("🔍 DRY RUN MODE - No changes will be made")
        print()
    
    # Initialize API
    print(f"🔌 Connecting to Technitium at {API_URL}")
    api = TechnitiumAPI(API_URL, API_TOKEN)
    
    # Get all A and AAAA records
    print(f"📋 Fetching records from zone: {ZONE_NAME}")
    print()
    
    a_records = api.get_zone_records(ZONE_NAME, 'A')
    aaaa_records = api.get_zone_records(ZONE_NAME, 'AAAA')
    
    all_records = a_records + aaaa_records
    
    if not all_records:
        print(f"⚠️  No A or AAAA records found in zone {ZONE_NAME}")
        sys.exit(0)
    
    print(f"✅ Found {len(a_records)} A records and {len(aaaa_records)} AAAA records")
    print()
    
    # Track reverse zones we need
    reverse_zones_needed = {}
    ptr_records_to_create = []
    
    # Process each record
    for record in all_records:
        record_name = record.get('name', '')
        record_type = record.get('type', '')
        
        # Get IP address from record data
        if record_type == 'A':
            ip_address = record.get('rData', {}).get('ipAddress')
        elif record_type == 'AAAA':
            ip_address = record.get('rData', {}).get('ipAddress')
        else:
            continue
        
        if not ip_address:
            continue
        
        # Calculate reverse zone and PTR name
        reverse_zone, ptr_name = ip_to_reverse_zone(ip_address)
        
        if not reverse_zone:
            continue
        
        # Track this reverse zone
        if reverse_zone not in reverse_zones_needed:
            reverse_zones_needed[reverse_zone] = []
        
        ptr_records_to_create.append({
            'forward_name': record_name,
            'ip': ip_address,
            'reverse_zone': reverse_zone,
            'ptr_name': ptr_name,
            'record_type': record_type
        })
    
    # Check and create reverse zones
    print("🔍 Checking reverse zones...")
    print()
    
    for reverse_zone in reverse_zones_needed.keys():
        exists = api.zone_exists(reverse_zone)
        
        if exists:
            print(f"  ✅ {reverse_zone} - exists")
        else:
            print(f"  ⚠️  {reverse_zone} - does not exist")
            
            if DRY_RUN:
                print(f"      [DRY RUN] Would create zone: {reverse_zone}")
            else:
                print(f"      Creating zone: {reverse_zone}")
                if api.create_zone(reverse_zone):
                    print(f"      ✅ Zone created successfully")
                else:
                    print(f"      ❌ Failed to create zone")
    
    print()
    print("=" * 70)
    print("Creating PTR records...")
    print("=" * 70)
    print()
    
    success_count = 0
    skip_count = 0
    error_count = 0
    
    for ptr in ptr_records_to_create:
        forward = ptr['forward_name']
        ip = ptr['ip']
        reverse_zone = ptr['reverse_zone']
        ptr_name = ptr['ptr_name']
        record_type = ptr['record_type']
        
        full_ptr = f"{ptr_name}.{reverse_zone}"
        
        print(f"📝 {forward} ({record_type}) -> {ip}")
        print(f"   PTR: {full_ptr} -> {forward}")
        
        if DRY_RUN:
            print(f"   [DRY RUN] Would create PTR record")
            success_count += 1
        else:
            if api.add_ptr_record(reverse_zone, ptr_name, forward):
                print(f"   ✅ Created")
                success_count += 1
            else:
                print(f"   ❌ Failed")
                error_count += 1
        
        print()
    
    # Summary
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"✅ Successfully created: {success_count}")
    if error_count > 0:
        print(f"❌ Failed: {error_count}")
    if DRY_RUN:
        print()
        print("🔍 This was a DRY RUN - no actual changes were made")
        print("   Set DRY_RUN = False to apply changes")
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
