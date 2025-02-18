# pfSense Community Edition on Azure

## Purpose

The scripts in this repo are to assist in creating an Azure virtual instance of [pfSense Community Edition](https://www.pfsense.org/download/) running in Azure on a [Generation 2](https://learn.microsoft.com/en-us/azure/virtual-machines/generation-2) Azure Virtual Machine.

## Pre-requisites

To create the custom image necessary to upload to the Azure Blob Storage, you need a Hyper-V virtual machine and a copy of the pfSense Community Edition installation media.

Assuming you'll be running these scripts from the same machine that you use to create the Hyper-V virtual machine you will also need WSL installed with an appropriate linux distro with the [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/) installed and [jq](https://jqlang.org/).

## Scripts

Scripts in the `./prepare` folder are scripts that need to be downloaded onto the pfSense virtual machine during image preperation.  Execution in order `00_os_changes.sh`, `01_pfsense_config.sh`, and `02_walagent.sh` will prepare the pfsense image to a state where a succesful virtual machine create can occur.

Script `./upload/00_create_sa_and_upload.sh` will upload a VHD file to azure blob storage required for virtual machine creation.

Script `./deploy/00_create_azure_vm.sh` will create a vm image from the uploaded VHD and create an azure virtual machine and supporting resources.



