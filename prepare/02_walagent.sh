#!/bin/sh

# Define the repository to clone
REPO="Azure/WALinuxAgent"

# Update all installed packages
pkg upgrade -y

PYTHON_PKG=$(pkg search python | grep -E "python3[0-9.]+" | head -n 1 | awk '{print $1}')

# Install essential packages
pkg install -y sudo bash git curl "${PYTHON_PKG}"

# Detect the installed Python version dynamically
PYTHON_VERSION=$(pkg info | grep -oE 'python3[0-9.]+' | grep -oE '[0-9.]+')
if [ -z "${PYTHON_VERSION}" ]; then
    echo "Python3 is not installed. Exiting."
    exit 1
fi

# Install setuptools dynamically based on Python version
SETUPTOOLS_PKG=$(pkg search py | grep -E "py${PYTHON_VERSION}-setuptools" | head -n 1 | awk '{print $1}')
if [ -n "${SETUPTOOLS_PKG}" ]; then
    pkg install -y "${SETUPTOOLS_PKG}"
else
    echo "Failed to find setuptools for ${PYTHON_VERSION}. Exiting."
    exit 1
fi

PYTHON_BINARY=$(find /usr/local/bin -type f -name 'python3*' | grep -E '/usr/local/bin/python3\.[0-9]+$' | sort | tail -n 1)

# Validate the Python binary
if [ -z "${PYTHON_BINARY}" ] || [ ! -x "${PYTHON_BINARY}" ]; then
    echo "No valid Python binary found in /usr/local/bin. Searching for alternatives..."
    # Fallback to locate any Python 3 binary
    PYTHON_BINARY=$(find /usr/local/bin -type f -name 'python3*' | sort | tail -n 1)
    if [ -z "${PYTHON_BINARY}" ] || [ ! -x "${PYTHON_BINARY}" ]; then
        echo "Python binary not found or not executable. Please ensure Python is installed. Exiting."
        exit 1
    fi
fi

echo "Detected Python binary: ${PYTHON_BINARY}"
# Create symlinks for Python and Python3
ln -sf "${PYTHON_BINARY}" /usr/local/bin/python
ln -sf "${PYTHON_BINARY}" /usr/local/bin/python3

# Clone the Git repository
if [ ! -d "WALinuxAgent" ]; then
    git clone "https://github.com/${REPO}.git"
fi

cd WALinuxAgent || { echo "Failed to enter repository directory"; exit 1; }

# Fetch the latest release tag from GitHub API
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
response=$(curl -s "${API_URL}")
latest_tag=$(echo "${response}" | awk -F'"' '/"tag_name":/{print $4}')

# Validate the fetched tag
if [ -n "${latest_tag}" ]; then
    echo "Latest release tag: ${latest_tag}"
else
    echo "Failed to fetch the latest release tag for ${REPO}."
    exit 1
fi

# Check out the latest release tag
git fetch --tags
git checkout "${latest_tag}"

# Install the agent
python3 setup.py install --register-service

echo 'waagent_enable="YES"' >> /etc/rc.conf.local

echo "#!/bin/sh" > /usr/local/etc/rc.d/waagent.sh
echo "service waagent start" >> /usr/local/etc/rc.d/waagent.sh
chmod +x /usr/local/etc/rc.d/waagent.sh

# Disable waagent firewall + provisioning agent
waagent_config="/etc/waagent.conf"
sed -i '' '/^Provisioning\.Agent=/s/=.*$/=disabled/' "${waagent_config}"
sed -i '' '/^OS\.EnableFirewall=/s/=.*$/=n/' "${waagent_config}"

# Print success message
echo "WALinux Agent has been successfully installed and registered."
