# HydroPower Data Collection
This Python script is used to collect power usage data from Kasa HS300 devices and store it in an InfluxDB database.

## Getting Started
These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

## Prerequisites
You need to have Python installed on your machine. All dependencies can be found in `src/requirements.txt`

You can install these using pip: `pip install -r requirements.txt`


## Environment Variables
You need to set the following environment variables:

`SECRET_ID` - The ID of your secret in Google Secret Manager.

## Running the Script
To run the script, simply execute the main.py file:

`python main.py`

## Terraform
Terraform deployment could be found in `terraform/` directory.

## Functionality
The script does the following:

- Loads secrets from Google Secret Manager.
- Connects to the Kasa Cloud and retrieves power usage data from devices.
- Connects to an InfluxDB database.
- Writes the power usage data to the InfluxDB database.

## License
This project is licensed under the MIT License - see the LICENSE.md file for details.

## Acknowledgments
Thanks to the creators of the `tplinkcloud` and `influxdb_client_3` libraries for making this project possible.