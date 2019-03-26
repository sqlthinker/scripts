#!/bin/bash
#
# SCRIPT: install-db2.sh
# AUTHOR: Anibal Santiago - @SQLThinker
# DATE:   2018-12-14
#
# DESCRIPTION: Automatically install DB2 and create instances
#
#  Paramaters:
#     INSTFILENAME - Filename with a list of Instances and Ports to create. One instnce per line.
#                    The Instance and port should be delimitted by the ":" character like "db2inst1:50000"
#
#   EXAMPLE:
#      install-db2.sh ~/instance-list.txt
#

## Update fhe following 4 variables as appropiate for your environment
# Full path of the DB2 media file (gzip file)
DB2MEDIA=/media/sf_Downloads/v11.1_linuxx64_server_t.tar.gz

# Path where the gzip file will be uncompressed and the path of the db2setup program
DB2MEDIAFILES=/opt/IBM
DB2SETUP=/opt/IBM/server_t/db2setup

# Path where the DB2 software will be installed
INSTALLPATH=/opt/ibm/db2/V11.1


# Find the path of this script. We will reference other files based on this path.
#export SCRIPTPATH=`dirname "$0"`
#if [ $SCRIPTPATH = "." ]; then
#  export SCRIPTPATH=`pwd`
#fi
SCRIPTPATH="$( cd "$( dirname "$0" )" && pwd )"

# We expect the $INSTFILENAME as the first parameter. If not provided use the file instance-list.txt.
INSTFILENAME=$1
if ([ "$INSTFILENAME" = "" ]); then
  INSTFILENAME=${SCRIPTPATH}/instance-list.txt
fi

# The script should only run as root
if [ "$USER" != "root" ]; then
  echo "ERROR: You need to run this script as root"
  exit -1
fi

# Print all variables
echo "DB2MEDIA      : $DB2MEDIA"
echo "DB2MEDIAFILES : $DB2MEDIAFILES"
echo "DB2SETUP      : $DB2SETUP"
echo "INSTALLPATH   : $INSTALLPATH"
echo "INSTFILENAME  : $INSTFILENAME"

# Uncompress the DB2 media
echo "Uncompress the DB2 media to $DB2MEDIAFILES"
mkdir -p $DB2MEDIAFILES
tar -xzf $DB2MEDIA --directory $DB2MEDIAFILES

# Add groups and users needed for DB2 response file
echo "Create users and groups"
groupadd db2iadm1
groupadd db2fadm1
useradd db2fenc1
usermod -aG db2fadm1 db2fenc1

# Enable firewall
echo "Enable firewall"
systemctl enable firewalld
systemctl start firewalld

# Generate a random password for the DAS user
PassWD=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15 ; echo ''`

# Start creating the first part of the response file
echo -e "
PROD = DB2_SERVER_EDITION
FILE = $INSTALLPATH
LIC_AGREEMENT = ACCEPT
INSTALL_TYPE = CUSTOM
COMP = BASE_CLIENT
COMP = JAVA_SUPPORT
COMP = SQL_PROCEDURES
COMP = BASE_DB2_ENGINE
COMP = CONNECT_SUPPORT
COMP = DB2_DATA_SOURCE_SUPPORT
COMP = JDK
COMP = LDAP_EXPLOITATION
COMP = INSTANCE_SETUP_SUPPORT
COMP = ACS
COMP = COMMUNICATION_SUPPORT_TCPIP
COMP = DB2_UPDATE_SERVICE
COMP = REPL_CLIENT
COMP = DB2_SAMPLE_DATABASE
COMP = ORACLE_DATA_SOURCE_SUPPORT
COMP = FIRST_STEPS
COMP = GUARDIUM_INST_MNGR_CLIENT
*--------------------------
* Installed Languages
*--------------------------
LANG = EN
*--------------------------
* DAS Properties
*__________________________
DAS_USERNAME = dasusr1
DAS_UID = 1301
DAS_GROUP_NAME = dasadm1
DAS_GID = 130
DAS_HOME_DIRECTORY = /home/dasusr1
DAS_PASSWORD = $PassWD " > ~/db2-install.rsp


# We need to keep a counter of how many instances we are creating to assign a unique UID
COUNTER=1
FCM=60000

# Loop through every instance and add them to the response file
cat $INSTFILENAME |
while IFS=\: read INSTANCE PORT; do
  echo "Adding instance: $INSTANCE:$PORT to reponse file"

  # Generate a random password for the instance user
  PassWD=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 15 ; echo ''`

  # Assign a unique UID starting at 1201
  CUID=`expr $COUNTER + 1200`
  
  echo -e "
  *--------------------------
  * Instance $INSTANCE
  *--------------------------
  INSTANCE = $INSTANCE
  ${INSTANCE}.NAME = $INSTANCE
  ${INSTANCE}.UID = $CUID
  ${INSTANCE}.GROUP_NAME = db2iadm1
  ${INSTANCE}.HOME_DIRECTORY = /home/${INSTANCE}
  ${INSTANCE}.PASSWORD = $PassWD
  ${INSTANCE}.AUTOSTART = YES
  ${INSTANCE}.SVCENAME = db2c_${INSTANCE}
  ${INSTANCE}.PORT_NUMBER = $PORT
  ${INSTANCE}.FCM_PORT_NUMBER = $FCM
  ${INSTANCE}.MAX_LOGICAL_NODES = 4
  ${INSTANCE}.CONFIGURE_TEXT_SEARCH = NO
  ${INSTANCE}.TYPE = ese
  ${INSTANCE}.FENCED_USERNAME = db2fenc1" >> ~/db2-install.rsp

  # Increase the Counter and the next FCM port number
  COUNTER=`expr $COUNTER + 1`
  FCM=`expr $FCM + 10`

done

echo "*** Below is the response file ***"
cat ~/db2-install.rsp


## Do the DB2 installation using the response file
echo "Installing DB2"
$DB2SETUP -u ~/db2-install.rsp


# Loop through every instance and do some configuration
# This is where you add any configuration that is standard for all DB2 instances
cat $INSTFILENAME |
while IFS=\: read INSTANCE PORT; do
  echo "Configuring instance: $INSTANCE on Port: $PORT"

  # Open firewall port
  echo "Open firewall port"
  firewall-cmd --permanent --add-port=${PORT}/tcp
  firewall-cmd --reload

  # Example: Set MySQL compatability
  su -l $INSTANCE -c 'db2set DB2_COMPATIBILITY_VECTOR=MYS'

  # Example: Turn on monitoring switches
  su -l $INSTANCE -c 'db2 -v update dbm cfg using DFT_MON_BUFPOOL ON DFT_MON_LOCK ON DFT_MON_SORT ON DFT_MON_STMT ON DFT_MON_TABLE ON DFT_MON_UOW ON HEALTH_MON OFF'
done
