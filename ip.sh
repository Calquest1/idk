#!/bin/bash

# Check if the script is run with sudo
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root. Please use sudo."
  exit 1
fi

# Get current network details
current_network=$(iwgetid -r)  # Gets the network name
ip_address=$(hostname -I | awk '{print $1}')  # Gets the first IP address
mac_address=$(cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}')/address)  # Gets the MAC address

echo "Current Network: $current_network"
echo "IP Address: $ip_address"
echo "MAC Address: $mac_address"

# Ask the user to enter the last digit of the private IP
read -p "Enter the last digit of the private IP to locate (e.g., x for 192.168.1.x): " ip_last_digit
base_ip=$(echo $ip_address | cut -d. -f1-3)
new_ip="$base_ip.$ip_last_digit"

# Ping the entered IP to check availability
while true; do
  ping -c 1 -w 1 $new_ip &> /dev/null
  if [[ $? -eq 0 ]]; then
    echo "The IP $new_ip is in use. Please enter another last digit."
    read -p "Enter another last digit: " ip_last_digit
    new_ip="$base_ip.$ip_last_digit"
  else
    echo "The IP $new_ip is available."
    break
  fi
done

# Configure static IP
read -p "Do you want to set $new_ip as your static IP? (yes/no): " confirm
if [[ "$confirm" == "yes" ]]; then
  echo "Setting up static IP for $new_ip..."
  interface=$(ip route show default | awk '/default/ {print $5}')
  cat <<EOF > /etc/network/interfaces.d/$interface
auto $interface
iface $interface inet static
    address $new_ip
    netmask 255.255.255.0
    gateway $(ip route | grep default | awk '{print $3}')
EOF
  echo "Static IP configuration completed. Restarting networking service..."
  systemctl restart networking
  echo "Your new IP address is $new_ip"
fi

# Ask if the user wants to randomize their MAC address
read -p "Would you like to randomize your MAC address? (yes/no): " randomize_mac
if [[ "$randomize_mac" == "yes" ]]; then
  new_mac=$(hexdump -n6 -e '2/1 ":%02X"' /dev/urandom | sed 's/^://')
  echo "Randomizing MAC address to $new_mac..."
  ip link set dev $interface down
  ip link set dev $interface address $new_mac
  ip link set dev $interface up
  echo "Your new MAC address is $new_mac"
fi

echo "Setup complete. Exiting."
