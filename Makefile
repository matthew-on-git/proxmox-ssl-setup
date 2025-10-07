# Proxmox SSL Setup Makefile

.PHONY: help install test clean

# Default target
help:
	@echo "Proxmox SSL Setup - Available targets:"
	@echo ""
	@echo "  install    - Install the script to /usr/local/bin"
	@echo "  test       - Run the test script to validate setup"
	@echo "  clean      - Clean up temporary files"
	@echo "  help       - Show this help message"
	@echo ""

install:
	@echo "Installing Proxmox SSL setup script..."
	sudo cp setup-proxmox-ssl.sh /usr/local/bin/proxmox-ssl-setup
	sudo chmod +x /usr/local/bin/proxmox-ssl-setup
	@echo "Installation complete! You can now run 'proxmox-ssl-setup' from anywhere."

test:
	@echo "Running Proxmox SSL setup tests..."
	sudo ./test-ssl-setup.sh

clean:
	@echo "Cleaning up temporary files..."
	rm -f *.log *.tmp *.backup.*
	@echo "Cleanup complete."

# Example usage targets
example-ve:
	@echo "Example for Proxmox VE:"
	@echo "sudo ./setup-proxmox-ssl.sh -d proxmox.example.com -e admin@example.com -t your_cf_token -p ve"

example-pbs:
	@echo "Example for Proxmox Backup Server:"
	@echo "sudo ./setup-proxmox-ssl.sh -d pbs.example.com -e admin@example.com -t your_cf_token -p pbs"
