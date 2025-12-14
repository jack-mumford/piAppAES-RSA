# FPGA Encryption System

Simple C++ encryption tool that encrypts data locally and sends it to an FPGA via Raspberry Pi.

## Overview

1. **Local encryption** - Encrypt `secret.txt` using XOR with SHA256 key
2. **GitHub Actions** - Automatically deploy to Raspberry Pi on push
3. **Pi to FPGA** - Send encrypted data via UART serial (115200 baud)

## Dependencies

**Local (Mac/Linux):**
- g++ compiler
- OpenSSL library (`brew install openssl` on Mac)

**Raspberry Pi:**
- g++ compiler
- GitHub Actions self-hosted runner

**Hardware:**
- Raspberry Pi (with self-hosted runner installed)
- FPGA board connected via USB serial

## Build

```bash
make
```

This builds:
- `encrypt_local` - Local encryption tool
- `fpga_sender` - Raspberry Pi sender application

## Usage

### 1. Encrypt locally
```bash
# Edit your secret
nano piApp/secret.txt

# Encrypt it
./encrypt_local
# Creates piApp/encrypted.txt
```

### 2. Deploy to FPGA
```bash
# Commit and push
git add piApp/encrypted.txt
git commit -m "Update encrypted data"
git push
```

GitHub Actions automatically:
- Runs on Raspberry Pi (self-hosted runner)
- Builds the sender
- Sends encrypted data to FPGA via serial

### 3. Test locally (without FPGA)
```bash
./fpga_sender --test --file piApp/encrypted.txt
```

## Files

```
encrypt_local.cpp       # Local encryption tool
piApp/
  ├── main.cpp          # Pi sender (sends to FPGA)
  ├── secret.txt        # Your plaintext (NOT committed)
  └── encrypted.txt     # Encrypted output (safe to commit)
Makefile                # Build configuration
.github/workflows/
  └── deploy.yml        # GitHub Actions workflow
```

## Serial Configuration

- **Port:** `/dev/ttyUSB0` (or `/dev/ttyACM0`)
- **Baud rate:** 115200
- **Format:** 8N1 (8 data bits, no parity, 1 stop bit)

## Encryption

- **Algorithm:** XOR with SHA256-derived key
- **Key:** SHA256 hash of "FPGA_ENCRYPTION_KEY"
- **Output:** Hex-encoded string

## GitHub Actions Setup

1. Install self-hosted runner on Raspberry Pi:
   - Repo → Settings → Actions → Runners → New self-hosted runner
   - Follow installation instructions

2. Connect FPGA to Pi via USB serial

3. Push changes to trigger deployment