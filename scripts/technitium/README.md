# Technitium DNS Auto-PTR Generator

Automatically create reverse DNS (PTR) records in Technitium DNS Server from existing A and AAAA records.

## 🎯 Problem

Managing reverse DNS (PTR records) manually is tedious and error-prone, especially when you have dozens or hundreds of forward DNS records. This script automates the entire process.

## ✨ Features

- ✅ Automatically processes all A and AAAA records in a zone
- ✅ Calculates correct reverse zones for both IPv4 and IPv6
- ✅ Creates reverse zones if they don't exist
- ✅ Supports multiple IP networks in a single forward zone
- ✅ Dry-run mode to preview changes
- ✅ Clear progress output with emojis
- ✅ Error handling and validation

## 📋 Requirements

- Python 3.6 or higher
- Technitium DNS Server with API enabled
- `requests` library

## 🚀 Installation

Download the script directly from GitHub:

```bash
# Download the script
wget https://raw.githubusercontent.com/AlfaAlfMedia/HomeLab/main/scripts/technitium/technitium-auto-ptr.py

# Make it executable
chmod +x technitium-auto-ptr.py

# Install Python dependencies
pip3 install requests
```

## ⚙️ Configuration

1. Get your API token from Technitium:
   - Open Technitium Web UI
   - Go to **Settings** → **API**
   - Copy your API token

2. Edit the script configuration:
```python
API_URL = "http://localhost:5380"  # Default Technitium API URL
API_TOKEN = "YOUR_API_TOKEN_HERE"   # Paste your API token here
ZONE_NAME = "example.com"           # Your forward DNS zone
DRY_RUN = False                     # Set to True to test without making changes
```

## 🎮 Usage

### Test run (recommended first):
```bash
# Edit script and set DRY_RUN = True
python3 technitium-auto-ptr.py
```

### Actual execution:
```bash
# Edit script and set DRY_RUN = False
python3 technitium-auto-ptr.py
```

## 📖 Example Output

```
======================================================================
Technitium DNS Auto-PTR Generator
======================================================================

🔌 Connecting to Technitium at http://localhost:5380
📋 Fetching records from zone: alfaalf-media.com

✅ Found 75 A records and 15 AAAA records

🔍 Checking reverse zones...

  ✅ 1.168.192.in-addr.arpa - exists
  ⚠️  5.10.172.in-addr.arpa - does not exist
      Creating zone: 5.10.172.in-addr.arpa
      ✅ Zone created successfully

======================================================================
Creating PTR records...
======================================================================

📝 server.alfaalf-media.com (A) -> 192.168.1.10
   PTR: 10.1.168.192.in-addr.arpa -> server.alfaalf-media.com
   ✅ Created

📝 nas.alfaalf-media.com (A) -> 172.10.5.20
   PTR: 20.5.10.172.in-addr.arpa -> nas.alfaalf-media.com
   ✅ Created

...

======================================================================
Summary
======================================================================
✅ Successfully created: 90
```

## 🔧 How It Works

1. **Fetches all A and AAAA records** from your specified zone via Technitium API
2. **Calculates reverse zones**:
   - IPv4: Uses /24 networks (e.g., `192.168.1.x` → `1.168.192.in-addr.arpa`)
   - IPv6: Uses /64 networks (e.g., `2001:db8::/64` → reverse IP6.ARPA zone)
3. **Creates missing reverse zones** automatically as Primary zones
4. **Adds PTR records** for each forward record

## 🏗️ Reverse Zone Creation

The script automatically determines which reverse zones are needed based on your IP addresses:

**IPv4 Example:**
- Forward: `server.example.com` → `192.168.1.10`
- Creates zone: `1.168.192.in-addr.arpa`
- Adds PTR: `10.1.168.192.in-addr.arpa` → `server.example.com`

**IPv6 Example:**
- Forward: `server.example.com` → `2001:db8::1`
- Creates zone: `[appropriate ip6.arpa zone]`
- Adds PTR: `[full reverse notation]` → `server.example.com`

## 🛡️ Safety Features

- **Dry-run mode**: Test the script without making any changes
- **API validation**: Checks API connectivity before processing
- **Zone verification**: Confirms reverse zones exist before adding records
- **Error handling**: Gracefully handles API errors and invalid IPs
- **Progress output**: Clear feedback on what's happening

## ⚠️ Important Notes

- The script uses **Technitium's REST API** - ensure API access is enabled
- PTR records are created with a **3600 second (1 hour) TTL** by default
- If you run the script multiple times, it may create duplicate PTR records (Technitium allows multiple PTR records per IP)
- For IPv4, the script assumes **/24 networks** for reverse zones
- For IPv6, the script assumes **/64 networks** for reverse zones

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License - feel free to use and modify as needed.

## 🙏 Credits

Part of the [AlfaAlfMedia HomeLab](https://github.com/AlfaAlfMedia/HomeLab) script collection.

## 📚 Related Resources

- [AlfaAlfMedia HomeLab Repository](https://github.com/AlfaAlfMedia/HomeLab)
- [Technitium DNS Server](https://technitium.com/dns/)
- [Technitium API Documentation](https://github.com/TechnitiumSoftware/DnsServer/blob/master/APIDOCS.md)
- [RFC 1035 - Domain Names](https://www.rfc-editor.org/rfc/rfc1035)
- [RFC 3596 - DNS Extensions for IPv6](https://www.rfc-editor.org/rfc/rfc3596)

## ❓ Troubleshooting

**"API Error: Connection refused"**
- Check that Technitium is running
- Verify API_URL is correct (default: `http://localhost:5380`)

**"Please configure your API_TOKEN"**
- You need to set your actual API token from Technitium Settings → API

**"No A or AAAA records found"**
- Check that ZONE_NAME is correct
- Ensure the zone exists and has records

**PTR records not resolving**
- Ensure your DNS clients are configured to use your Technitium server
- Check that reverse zones are properly delegated if using public IPs
