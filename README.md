# How to build a Windows QEMU KVM qcow2 image

For Linux users, start from the beginning. For Windows users, start from [dependencies installation](https://github.com/AlekseyChudov/windows-kvm-imaging-tools/blob/master/README.md#on-a-windows-machine-install-the-dependencies).


### Enable Nested Virtualization

https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/nested_virt


### Download Windows 10 image

Unofficial, clean, non-activated Windows 10 Pro image built from https://www.microsoft.com/en/software-download/windows10ISO

```
docker pull docker.io/alekseychudov/windows-10-pro:1912
```


## Create a guest disk image

It is further assumed that Docker uses the overlay2 storage driver.

```
$ docker info | grep 'Storage Driver'
 Storage Driver: overlay2
```

```
image="$(docker inspect --format {{.GraphDriver.Data.UpperDir}} docker.io/alekseychudov/windows-10-pro:1912)/images/Windows-10-Pro.qcow2.gz"

sudo pigz -c -d "${image}" | sudo dd of=/var/lib/libvirt/images/win10.localhost.qcow2 status=progress

sudo qemu-img resize /var/lib/libvirt/images/win10.localhost.qcow2 100G

sudo qemu-img info /var/lib/libvirt/images/win10.localhost.qcow2
```


## Create a cloudbase-init ISO image to automate guest configuration

```
mkdir -pv cloudbase-init/openstack/latest

echo '{"admin_pass": "L1bv!rt", "hostname": "win10"}' > cloudbase-init/openstack/latest/meta_data.json

sudo genisoimage -input-charset utf-8 -joliet -rock -volid config-2 \
    -output /var/lib/libvirt/images/win10.localhost.iso cloudbase-init
```


## Provision a new virtual machine

```
sudo virt-install \
    --name win10.localhost \
    --memory 4096 \
    --vcpus 4 \
    --cpu host \
    --import \
    --disk /var/lib/libvirt/images/win10.localhost.qcow2,device=disk,bus=virtio \
    --disk /var/lib/libvirt/images/win10.localhost.iso,device=cdrom \
    --network default \
    --graphics spice \
    --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
    --virt-type kvm \
    --os-variant win10 \
    --noautoconsole
```

The very first start-up takes some time due to initial setup and restarts. Connect to the virtual machine using [Virtual Machine Manager](https://virt-manager.org/) to find out what is going on.


## Connect to virtual machine via Remote Desktop

If the [Libvirt NSS module](https://libvirt.org/nss.html) is installed, you can connect to the virtual machine directly by name. Otherwise, you can find out the address of the virtual machine using the below command.

```
sudo virsh domifaddr win10.localhost
```

Default username is "Administrator" and password is "L1bv!rt". Change it as soon as possible!

```
xfreerdp /v:win10.localhost /u:Administrator
```

The very first login takes some time due to initial setup.


## On a Windows machine, install the dependencies

- [Git](https://git-scm.com/downloads)
- [Windows ADK](https://docs.microsoft.com/en-us/windows-hardware/get-started/adk-install)
- [Hyper-V](https://docs.microsoft.com/en-us/virtualization/hyper-v-on-windows/quick-start/enable-hyper-v)


## Insert the Windows installation disc into the first CDROM device

If using the libvirt virtual machine, type the following commands:

```
$ sudo virsh domblklist win10.localhost
Target     Source
------------------------------------------------
vda        /var/lib/libvirt/images/win10.localhost.qcow2
sda        /var/lib/libvirt/images/win10.localhost.iso

$ sudo virsh change-media win10.localhost sda --eject
Successfully ejected media.

$ sudo virsh change-media win10.localhost sda /var/lib/libvirt/images/windows.iso --insert
Successfully inserted media.
```


## Build a Windows image

Open PowerShell as Administrator and type the following commands.

```
Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser

git clone https://github.com/cloudbase/windows-openstack-imaging-tools.git
cd windows-openstack-imaging-tools

git submodule add https://github.com/AlekseyChudov/windows-kvm-imaging-tools.git

windows-kvm-imaging-tools\create-windows-online-kvm-image.ps1
```

Upon successful completion you will have the following qcow2 image.

```
build\Windows-<version>.qcow2
```

Congrats! You can add Windows image building skills to your resume :)


## Resources

https://github.com/cloudbase/windows-openstack-imaging-tools
