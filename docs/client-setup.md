# Instructions for APT Client Setup

This document provides instructions for configuring an APT client to use the Aptly repository.

## Prerequisites

- Ensure that the Aptly repository is set up and accessible.
- Have root or sudo access on the client machine.

## Steps to Configure APT Client

1. **Add the GPG Key**

   First, you need to add the GPG key used to sign the packages in the Aptly repository. Run the following command:

   ```bash
   wget -qO - http://ubuntu.yourdomain.com/gpg.key | sudo apt-key add -
   ```

2. **Add the Repository**

   Next, add the Aptly repository to your APT sources list. Create a new file in the `/etc/apt/sources.list.d/` directory:

   ```bash
   echo "deb http://ubuntu.yourdomain.com jammy main universe" | sudo tee /etc/apt/sources.list.d/aptly.list
   ```

3. **Update APT Cache**

   After adding the repository, update the APT package cache:

   ```bash
   sudo apt update
   ```

4. **Install Packages**

   You can now install packages from the Aptly repository using the standard APT commands. For example:

   ```bash
   sudo apt install <package-name>
   ```

## Troubleshooting

- If you encounter issues with the GPG key, ensure that the URL is correct and accessible.
- If the repository is not found, verify that the Aptly server is running and the repository is published correctly.

## Conclusion

Your APT client is now configured to use the Aptly repository. You can install packages as needed and benefit from the high availability and features provided by the Aptly setup.
