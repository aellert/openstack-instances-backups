# OpenStack automatic instances & volumes snapshots
Nova, OpenStack compute service is used for hosting and managing cloud computing systems.

Below we gonna see how to automate the backups of your volumes & instances

cf. tutorial
https://raymii.org/s/tutorials/OpenStack_Quick_and_automatic_instance_snapshot_backups.html

## Dependencies
### OpenStack Command lines tools

The script requires to have the command line tools dmidecode, wget & python-pip

```
# Ubuntu/Debian
apt-get install python-openstackclient
# CentOS/RHEL
yum install python2-openstackclient
```

### Mail agent
To send the errors at the end of the script you need swaks (http://www.jetmore.org/john/code/swaks/)

```
# Ubuntu/Debian
apt-get install swaks
# CentOS/RHEL
yum install swaks
```

## Configuration
### Credentials file
Firstable you need to create the file :

```
nano .openstack_snapshotrc

export OS_AUTH_URL="https://identity.stack.cloudvps.com/v2.0"
export OS_TENANT_NAME="PROJECT_UUID"
export OS_TENANT_ID="PROJECT_UUID"
export OS_USERNAME="USERNAME"
export OS_PASSWORD="PASSWORD"
export OS_REGION_NAME="REGION"

export LOG_EMAIL_FROM="backup@domain.com"
export LOG_EMAIL_TO="admin@domain.com"
export LOG_SMTP_HOST=smtp.domain.com
export LOG_SMTP_PORT=587
export LOG_SMTP_TLS="-tls"
export LOG_SMTP_AUTH_TYPE=PLAIN
export LOG_SMTP_AUTH_USER="user@domain.com"
export LOG_SMTP_AUTH_PWD="secret"

```
Please note that the last line `OS_REGION_NAME` is needed for **OVH Cloud**

Then you need to source it to apply the credentials :

```
source .openstack_snapshotrc
```

### Install the scripts

For example in your /home/user/ directory you can paste the `create_snapshot.sh` & `count_volume_snapshots.sh`

or use the following commands:

```
wget -q -O - https://raw.githubusercontent.com/aellert/openstack-instances-backups/master/create_snapshot.sh > create_snapshot.sh
wget -q -O - https://raw.githubusercontent.com/aellert/openstack-instances-backups/master/count_volume_snapshots.sh > count_volume_snapshots.sh
```

Then you need to set the executable permission on the files :
```
chmod +x /home/user/create_snapshot.sh
chmod +x /home/user/count_volume_snapshots.sh
```

### Rotations configuration
About the rotations, the second parameter gonna program it.
For the volumes the `nova backup` command already has a native parameter, but for the instances the `count_volume_snapshots.sh` bash script is going to do the work !

### Try it with the dry run !
By default the dry run mode is disable. You need to add a third `--dry-run` argument to enable it and test the command :

```
# dry run mode
/home/user/create_snapshot.sh daily 7 --dry-run

# do it mode
/home/user/create_snapshot.sh daily 7
```
