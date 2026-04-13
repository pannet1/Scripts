#!/usr/bin/env python3
"""Mailbox and Alias Configuration Viewer"""

import subprocess
import os

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else f"Error: {result.stderr}"

def main():
    print("=== Mailboxes (/etc/postfix/vmailboxes) ===")
    if os.path.exists("/etc/postfix/vmailboxes"):
        with open("/etc/postfix/vmailboxes") as f:
            print(f.read())
    
    print("\n=== Virtual Aliases (/etc/postfix/virtual) ===")
    if os.path.exists("/etc/postfix/virtual"):
        with open("/etc/postfix/virtual") as f:
            print(f.read())
    
    print("\n=== Postfix Virtual Mailbox Config ===")
    print(run_cmd("postconf | grep -E '^virtual_'"))
    
    print("\n=== Dovecot User Database ===")
    if os.path.exists("/etc/dovecot/vmail.passwd"):
        with open("/etc/dovecot/vmail.passwd") as f:
            print(f.read())

if __name__ == "__main__":
    main()