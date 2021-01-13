#!/bin/bash

#
# usb-libvirt-hotplug.sh
#
# This script can be used to hotplug USB devices to libvirt virtual
# machines from udev rules.
#
# This can be used to attach devices when they are plugged into a
# specific port on the host machine.
#
# See: https://github.com/olavmrk/usb-libvirt-hotplug
#

# Abort script execution on errors
set -e

PROG="$(basename "$0")"

if [ ! -t 1 ]; then
  # stdout is not a tty. Send all output to syslog.
  coproc logger --tag "${PROG}"
  exec >&${COPROC[1]} 2>&1
fi

DOMAIN="$1"
if [ -z "${DOMAIN}" ]; then
  echo "Missing libvirt domain parameter for ${PROG}." >&2
  exit 1
fi


#
# Do some sanity checking of the udev environment variables.
#

if [ -z "${SUBSYSTEM}" ]; then
  echo "Missing udev SUBSYSTEM environment variable." >&2
  exit 1
fi
if [ "${SUBSYSTEM}" != "usb" ]; then
  echo "Invalid udev SUBSYSTEM: ${SUBSYSTEM}" >&2
  echo "You should probably add a SUBSYSTEM=\"USB\" match to your udev rule." >&2
  exit 1
fi

if [ -z "${DEVTYPE}" ]; then
  echo "Missing udev DEVTYPE environment variable." >&2
  exit 1
fi
if [ "${DEVTYPE}" == "usb_interface" ]; then
  # This is normal -- sometimes the udev rule will match
  # usb_interface events as well.
  exit 0
fi
if [ "${DEVTYPE}" != "usb_device" ]; then
  echo "Invalid udev DEVTYPE: ${DEVTYPE}" >&2
  exit 1
fi

if [ -z "${ACTION}" ]; then
  echo "Missing udev ACTION environment variable." >&2
  exit 1
fi
if [ "${ACTION}" == 'add' ]; then
  COMMAND='attach-device'
elif [ "${ACTION}" == 'remove' ]; then
  COMMAND='detach-device'
else
  echo "Invalid udev ACTION: ${ACTION}" >&2
  exit 1
fi

if [ -z "${VERDOR_ID}" ]; then
  echo "Missing udev VERDOR_ID environment variable." >&2
  exit 1
fi
if [ -z "${PRORUCT_ID}" ]; then
  echo "Missing udev PRORUCT_ID environment variable." >&2
  exit 1
fi


#
# Now we have all the information we need to update the VM.
# Run the appropriate virsh-command, and ask it to read the
# update XML from stdin.
#
echo "Running virsh ${COMMAND} ${DOMAIN} for USB vendor_id=${VERDOR_ID} product_id=${PRORUCT_ID}:" >&2
virsh "${COMMAND}" "${DOMAIN}" /dev/stdin <<END
<hostdev mode='subsystem' type='usb'>
    <source>
        <vendor id='0x03f0'/>
        <product id='0x2b17'/>
    </source>
</hostdev>
END
