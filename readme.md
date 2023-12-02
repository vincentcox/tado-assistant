# 🏡 Tado Assistant: Your User-Friendly, Free Tado Auto-Assist Alternative

Discover the ultimate free alternative to Tado's Auto-Assist with Tado Assistant! This innovative utility enhances your
Tado smart home experience by seamlessly integrating with the Tado API, offering advanced features like mobile
device-based home state monitoring, open window detection in various zones, and customizable settings for open window
duration. Ideal for those in search of a "Tado Auto
Assist free" solution, Tado Assistant provides an efficient and cost-effective way to automate and optimize your home
environment. It's designed to be user-friendly and accessible, requiring minimal dependencies, making it a perfect
choice for both technical and non-technical users.

## 🚀 Key Features - Free Tado Auto Assist

- **State Monitoring**: Tado Assistant vigilantly tracks your home's status (HOME or AWAY) in real-time, offering a free
  alternative to Tado's Auto-Assist feature.
- **Smart Adjustments**: Detects discrepancies, such as no devices at home but the state is set to HOME, and adjusts
  accordingly.
- **Open Window Detection**: Recognizes open windows in different zones and activates the appropriate mode.
- **Customizable Open Window Duration**: Set your preferred duration for the 'Open Window' detection feature, allowing
  for personalized energy-saving adjustments.

## ⚠️ **Disclaimer**

This project is an independent initiative and is not affiliated, endorsed, or sponsored by Tado GmbH. All trademarks and
logos mentioned are the property of their respective owners. Please use this software responsibly and at your own risk.

## 🛠 Prerequisites

- A Unix-based system (Linux distributions or macOS).
- `git` installed to clone the repository.
- Root or sudo privileges for the installation script.
- `curl` and `jq` (Don't worry, our installer will help you set these up if they're not present).
- Ensure both scripts (`install.sh` and `tado-assistant.sh`) reside in the same directory.

## 📥 Installation

1. Clone this repository to dive in:

   ```bash
   git clone https://github.com/BrainicHQ/tado-assistant.git
   ```

   ```bash
   cd tado-assistant
   ```

2. Grant the installation script the necessary permissions:

   ```bash
   chmod +x install.sh
   ```

3. Kick off the installation with root or sudo privileges:

   ```bash 
   sudo ./install.sh
   ```

During the installation, the script will:

- Set up the required dependencies.
- Prompt you for your Tado credentials and other optional configurations.
- Initialize `tado-assistant.sh` as a background service.
- Introduce a new configuration option for the 'Open Window' feature. You will be prompted to enter the maximum
  duration (in seconds) that the system should wait before resuming normal operation after an open window is detected.
  You can specify a custom duration or leave it empty to use the default duration set in the Tado app.


## 🐳 Docker Installation

Tado Assistant can also be run as a Docker container, making it platform-independent and simplifying the setup process. Here's how you can get it up and running with Docker:

1. **Build the Docker Image:**
   First, build the Docker image from the Dockerfile provided in the repository.

   ```bash
   docker build -t tado-assistant .
   ```

2. **Run the Docker Container:**
   Once the image is built, you can run Tado Assistant in a Docker container. Replace `<LOG_FILE_PATH>` with your desired log file path if you want to specify a custom one.

   ```bash
   docker run -d --name tado-assistant \
              -e TADO_USERNAME='your_username' \
              -e TADO_PASSWORD='your_password' \
              -e CHECKING_INTERVAL=15 \
              -e ENABLE_LOG=true \
              -e LOG_FILE=<LOG_FILE_PATH> \
              -e MAX_OPEN_WINDOW_DURATION= \
              tado-assistant
   ```

   Note: The above command includes the most common environment variables. Adjust them according to your needs.

3. **Docker Logs:**
   To check the logs of your Tado Assistant Docker container, use:

   ```bash
   docker logs tado-assistant
   ```

4. **Stopping and Removing the Container:**
   When you need to stop and remove the container, use the following commands:

   ```bash
   docker stop tado-assistant
   docker rm tado-assistant
   ```

This Docker setup offers a straightforward way to deploy Tado Assistant without the need for manual environment setup on your host system.

## 🔄 Updating

To ensure you're running the latest version of Tado Assistant, follow these steps:

1. Navigate to the `tado-assistant` directory:

    ```bash
    cd path/to/tado-assistant
    ```

2. To update normally, run the installation script with the `--update` flag:

    ```bash
    sudo ./install.sh --update
    ```

   This will check for the latest version of the script, update any dependencies if necessary, and restart the service.

3. If you need to force an update (for instance, to revert local changes to the official version), use
   the `--force-update` flag:

    ```bash
    sudo ./install.sh --force-update
    ```

   This option will update Tado Assistant to the latest version from the repository, regardless of any local changes.
   It's useful for ensuring your script matches the official release.

### Note on Local Changes

- When updating, the script automatically detects and backs up any local modifications. These backups are stored as
  patch files, allowing you to restore your changes if needed.
- In case of conflicts during a normal update, the script will halt and prompt you to resolve these manually, ensuring
  your modifications are not unintentionally overwritten.

## 🔧 Configuration

Several environment variables drive the Tado Assistant:

- `TADO_USERNAME`: Your Tado account username.
- `TADO_PASSWORD`: Your Tado account password.
- `CHECKING_INTERVAL`: Frequency (in seconds) for home state checks. Default is every 15 seconds.
- `ENABLE_LOG`: Toggle logging. Values: `true` or `false`. Default is `false`.
- `LOG_FILE`: Destination for the log file. Default is `/var/log/tado-assistant.log`.
- `MAX_OPEN_WINDOW_DURATION`: Define the maximum duration (in seconds) for the 'Open Window' detection feature to be
  active. Leave this field empty to use the default duration set in the Tado app.

These variables are stored in `/etc/tado-assistant.env`. Feel free to tweak them directly if needed.

## 🔄 Usage

After successfully installing the Tado Assistant, it will run silently in the background, ensuring your home's
environment is always optimal. Here's how you can interact with it:

1. **Checking Service Status**:
    - **Linux**:
   ```bash
   sudo systemctl status tado-assistant.service
    ``` 
    - **macOS**:
   ```bash
   launchctl list | grep com.user.tadoassistant
    ``` 

2. **Manual Adjustments**: If you ever need to make manual adjustments to your Tado settings, simply use the Tado app.
   Tado Assistant will recognize these changes and adapt accordingly.

3. **Logs**: To understand what Tado Assistant is doing behind the scenes, refer to the logs. If logging is enabled, you
   can tail the log file for real-time updates:
    ```bash
    tail -f /var/log/tado-assistant.log
    ```

4. **Adjusting 'Open Window' Duration**: The 'Open Window' detection feature's duration can be customized to suit your
   preferences. To modify this setting:
    - Edit the `/etc/tado-assistant.env` file.
    - Locate the `MAX_OPEN_WINDOW_DURATION` variable.
    - Set its value to the desired number of seconds. For example, `MAX_OPEN_WINDOW_DURATION=300` for a 5-minute
      duration.
    - Save the changes and restart the service for them to take effect.
        - For Linux:
          ```bash
          sudo systemctl restart tado-assistant.service
          ```
        - For macOS:
          ```bash
          launchctl unload ~/Library/LaunchAgents/com.user.tadoassistant.plist
          launchctl load ~/Library/LaunchAgents/com.user.tadoassistant.plist
          ```
   This setting defines how long the system should wait before resuming normal operation after an open window is
   detected, allowing for energy-saving adjustments tailored to your needs.

Remember, Tado Assistant is designed to be hands-off. Once set up, it should require minimal interaction, letting you
enjoy a comfortable home environment without any fuss.

## 🌟 Running Tado Assistant Continuously

Ensuring Tado Assistant runs continuously is crucial for maintaining an optimal home environment. Here are some
cost-effective solutions for running the software 24/7, suitable for both technical and non-technical users.

### ☁️ Free Tier Cloud Services

Cloud services offer reliable and free solutions to run small-scale projects like Tado Assistant. Here are some popular
options:

#### AWS EC2

- **Amazon Web Services (AWS)** provides a free tier EC2 instance which is more than capable of handling small
  applications.
- [AWS EC2 Free Tier Guide](https://aws.amazon.com/free/)

#### Google Cloud Platform

- **Google Cloud Platform (GCP)** offers a free tier with a micro VM instance.
- [GCP Free Tier Guide](https://cloud.google.com/free/docs/free-cloud-features)

#### Microsoft Azure

- **Microsoft Azure** also provides a free tier with virtual machines.
- [Azure Free Tier Guide](https://azure.microsoft.com/en-us/free/)

### 🖥️ Raspberry Pi or Old Laptop/PC

For those who prefer a more hands-on approach or wish to utilize existing hardware:

#### Raspberry Pi

- A **Raspberry Pi** can be a cost-effective and energy-efficient server.
- [Setting up Tado Assistant on Raspberry Pi](https://www.raspberrypi.com/documentation/computers/getting-started.html)

#### Repurposed Old Laptop/PC

- Use an **old laptop or PC** as a dedicated server for Tado Assistant.
- Ensure it's configured to run the software on startup and adjust power settings for continuous operation.

## 📜 Logs

If you've enabled logging (`ENABLE_LOG=true`), you can peek into the log file (default
location: `/var/log/tado-assistant.log`) for real-time updates and messages.

## 🗑️ Uninstallation

Currently, a dedicated uninstallation script is not provided. To manually uninstall:

1. Stop the service.
    - For Linux:
   ```bash 
   sudo systemctl stop tado-assistant.service
    ```
    - For macOS:
   ```bash 
   launchctl unload ~/Library/LaunchAgents/com.user.tadoassistant.plist
    ```

2. Remove the service configuration.
    - For Linux:
   ```bash 
   sudo rm /etc/systemd/system/tado-assistant.service
    ```
    - For macOS:
   ```bash 
   rm ~/Library/LaunchAgents/com.user.tadoassistant.plist
    ```

3. Remove the main script:
   ```bash 
   sudo rm /usr/local/bin/tado-assistant.sh
    ```

4. Remove the environment variables file:
   ```bash
   sudo rm /etc/tado-assistant.env
    ```

5. Optionally, uninstall `curl` and `jq` if they were installed by the script and are no longer needed.

## 🤝 Contributing

Your insights can make Tado Assistant even better! We welcome contributions. Please ensure your code aligns with the
project's ethos. Feel free to submit pull requests or open issues for suggestions, improvements, or bug reports.

## 🍕 Support

Love Tado Assistant? You can show your support by starring the repository, sharing it with others,
or [buying me a pizza](https://www.buymeacoffee.com/silviu). All contributions are greatly appreciated and help keep the
project running.

Alternatively, contributions to the codebase or documentation are also welcome. Every bit of help counts!