#!/bin/bash

# Variables
NFS_SHARE="//123/ABC"
MOUNT_POINT="/mnt/matlab_nfs"
INSTALLER_ISO="$MOUNT_POINT/MATLAB_R2022b.iso"
MATLAB_INSTALL_DIR="/usr/local/MATLAB/R2022b"
INSTALLER_INPUT_FILE="/tmp/installer_input.txt"

ARTIFACTORY_URL="https://your-artifactory-url/path-to-matlab-installer"
MATLAB_INSTALL_DIR="/usr/local/MATLAB/R2022b"
TOKEN="your_artifactory_token"
MATLAB_MOUNT_POINT="/mnt/matlab_installer"
SSL_CERT_PATH="/root/SSL/your_certificate.pem"
SSL_KEY_PATH="/root/SSL/your_private_key.pem"
WEBAPP_SERVER_PATH="/usr/local/MATLAB/MATLAB_Web_App_Server/R2024a/script"
POLICY_FILE="/usr/local/MATLAB/MATLAB_Web_App_Server/R2024a/script/webapps_private/webapps_acc_ctl.json"



RUNTIMES=("2020b" "2022b" "2024b")
INSTALL_DIR="/usr/local/MATLAB/MATLAB_Runtime"


# Step 0: Install NFS utilities on RedHat
echo "Installing NFS utilities..."
sudo yum install -y nfs-utils

# Step 1: Create mount point and mount NFS share as read-only
echo "Mounting NFS share..."
sudo mkdir -p $MOUNT_POINT
sudo mount -o ro $NFS_SHARE $MOUNT_POINT

# Step 2: Create the installer_input.txt file
echo "Creating installer input file..."
cat <<EOF > $INSTALLER_INPUT_FILE
destinationFolder=$MATLAB_INSTALL_DIR
fileInstallationKey=your_file_installation_key
agreeToLicense=yes
outputFile=/tmp/matlab_install_log.txt
licensePath=/usr/local/MATLAB/license.lic
mode=silent
EOF

# Step 3: Mount the ISO file from the NFS share
echo "Mounting MATLAB installer ISO..."
sudo mount -o loop $INSTALLER_ISO /mnt

# Step 4: Install MATLAB silently using the input file
echo "Installing MATLAB silently..."
sudo /mnt/install -inputFile $INSTALLER_INPUT_FILE

# Step 5: Unmount the ISO and NFS share
echo "Unmounting the installer ISO and NFS share..."
sudo umount /mnt
sudo umount $MOUNT_POINT

# Step 6: Clean up
echo "Cleaning up..."
rm -f $INSTALLER_INPUT_FILE

echo "MATLAB silent installation complete."

########## runtimes ##############

# Step 0: Download MATLAB ISO installer from Artifactory using curl with token
echo "Downloading MATLAB installer ISO..."
curl -H "Authorization: Bearer $TOKEN" -o /tmp/$INSTALLER_ISO "$ARTIFACTORY_URL/$INSTALLER_ISO"



# Step 6: Download and install MATLAB Runtime
echo "Downloading MATLAB Runtime installer..."
curl -H "Authorization: Bearer $TOKEN" -o /tmp/MATLAB_Runtime_R2022b.zip "$ARTIFACTORY_URL/MATLAB_Runtime_R2022b.zip"
unzip /tmp/MATLAB_Runtime_R2022b.zip -d /tmp/matlab_runtime_installer
sudo /tmp/matlab_runtime_installer/install -destinationFolder "$INSTALL_DIR" -mode silent
rm -rf /tmp/MATLAB_Runtime_R2022b.zip /tmp/matlab_runtime_installer
echo "MATLAB Runtime R2022b installation complete."

#ARTIFACTORY_URL="https://your-artifactory-url/path-to-matlab-runtime"
#TOKEN="your_artifactory_token"
#RUNTIMES=("2020b" "2022b" "2024b")
#INSTALL_DIR="/usr/local/MATLAB/MATLAB_Runtime"

for VERSION in "${RUNTIMES[@]}"; do
    RUNTIME_ZIP="MATLAB_Runtime_R${VERSION}.zip"
    
    # Step 1: Download the runtime installer
    echo "Downloading MATLAB Runtime R${VERSION}..."
    curl -H "Authorization: Bearer $TOKEN" -o /tmp/$RUNTIME_ZIP "$ARTIFACTORY_URL/$RUNTIME_ZIP"
    
    # Step 2: Unzip the installer
    echo "Unzipping MATLAB Runtime R${VERSION}..."
    unzip /tmp/$RUNTIME_ZIP -d /tmp/matlab_runtime_installer_$VERSION

    # Step 3: Create installer_input.txt for silent installation
    echo "Creating installer input file for R${VERSION}..."
    cat <<EOF > /tmp/installer_input_${VERSION}.txt
destinationFolder=$INSTALL_DIR/R${VERSION}
agreeToLicense=yes
mode=silent
EOF

    # Step 4: Install the runtime silently using installer_input.txt
    echo "Installing MATLAB Runtime R${VERSION} silently..."
    sudo /tmp/matlab_runtime_installer_$VERSION/install -inputFile /tmp/installer_input_${VERSION}.txt

    # Step 5: Clean up
    echo "Cleaning up..."
    rm -rf /tmp/$RUNTIME_ZIP /tmp/matlab_runtime_installer_$VERSION /tmp/installer_input_${VERSION}.txt

    echo "MATLAB Runtime R${VERSION} installation complete."
done




# Step 7: SSL Configuration
echo "Configuring SSL..."
cd "$WEBAPP_SERVER_PATH"
sudo ./webapps-config set ssl_certificate_file "$SSL_CERT_PATH"
sudo ./webapps-config set ssl_private_key_file "$SSL_KEY_PATH"
sudo ./webapps-config set ssl_enabled true

# Step 7b: Configure MATLAB Web App Server to run on port 443 with DNS mwas.sample.com
echo "Configuring server to run on port 443..."
sudo ./webapps-config set port 443
echo "Configuring server DNS to mwas.sample.com..."
sudo ./webapps-config set hostname mwas.sample.com

# Step 8: Policy-Based Access Control
echo "Creating policy-based access control file..."
cat <<EOF > "$POLICY_FILE"
{
  "version": "1.0.0",
  "policy": [
    {
      "id": "policy_1_app1",
      "description": "Allow marek@google.com to access app1",
      "rule": [
        {
          "id": "rule_app1_user",
          "subject": { "uid": ["marek@google.com"] },
          "resource": { "app": ["app1"] },
          "action": ["execute"]
        }
      ]
    },
    {
      "id": "policy_2_app2",
      "description": "Allow 'testers' group to access app2",
      "rule": [
        {
          "id": "rule_app2_group",
          "subject": { "groups": ["testers"] },
          "resource": { "app": ["app2"] },
          "action": ["execute"]
        }
      ]
    }
  ]
}
EOF

echo "Policy-based access control configured."

# Step 9: Start or Restart MATLAB Web App Server
echo "Starting or restarting MATLAB Web App Server..."
sudo ./webapps-restart

echo "MATLAB Web App Server setup complete with SSL and access control."

