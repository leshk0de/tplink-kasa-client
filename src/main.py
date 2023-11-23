import base64
import logging
import os
import json
import os
from google.cloud import secretmanager
from tplinkcloud import TPLinkDeviceManager
from influxdb_client_3 import InfluxDBClient3, Point

from dotenv import load_dotenv
import asyncio
import json



# Get environment variables
SECRETS = None

def load_secrets():
    global SECRETS
    load_dotenv()
    #this needs to change to its own secret
    SECRET_ID = os.getenv('SECRET_ID', "projects/953089058593/secrets/kasa-h300-hydrop-secrets")
    try:
        # Create the Secret Manager client.
        client = secretmanager.SecretManagerServiceClient()
        # Build the resource name of the secret version.
        name = f"{SECRET_ID}/versions/latest"
        # Access the secret version.
        print("Loading secrets from Secret Manager ({}).".format(name))
        response = client.access_secret_version(request={"name": name})
        # Return the decoded payload of the secret.
    
        SECRETS = json.loads(response.payload.data.decode("UTF-8"))
    except Exception as e:
        print("Error loading secrets: ", e)
        return False
    
    return True

load_secrets()


# Get device information from Kasa
async def get_power_usage(_device_prefix):

    device_manager = TPLinkDeviceManager(SECRETS['KASA_USERNAME'], SECRETS['KASA_PASSWORD'])
    device_names_like = _device_prefix
    devices = await device_manager.find_devices(device_names_like)
    data = []
    if devices:
        print(f'Found {len(devices)} matching devices')
        for device in devices:
            print(f'{device.model_type.name} device called {device.get_alias()}')
            power_usage = await device.get_power_usage_realtime()
            json_string = json.dumps(power_usage, default=lambda x: x.__dict__)
            json_object = json.loads(json_string)
            json_object["name"] = device.get_alias().replace(_device_prefix, "")
            data.append(json_object)
    
    return data


def pull_data(event, context):

    if 'data' not in event:
        print('Error: Invalid Pub/Sub message format')
        return
    
    if 'data' in event:
        try:
            pubsub_message = base64.b64decode(event['data']).decode('utf-8')
        except Exception as e:
            print('Error: Failed to decode Pub/Sub message:', e)
            return

        print(f"Received Pub/Sub message: {pubsub_message}")
    
        if not load_secrets():
            print("Failed to load secrets.")
            return

        #connect to influxdb
        try:
            client = InfluxDBClient3(host=SECRETS['INFLUXDB_HOST'], token=SECRETS['INFLUXDB_TOKEN'], org=SECRETS['INFLUXDB_ORG'], database=SECRETS['INFLUXDB_DATABASE'])

        except Exception as e:
            print('Error: Failed to connect to InfluxDB:', e)
            return
        
        # get device information from KaSa
        try:
            prefix = "HP1 - "
            data = asyncio.run(get_power_usage(prefix))
        except Exception as e:
            print('Error: Failed to connect to Kasa Cloud:', e)
            return
        
    
        # write data to influxdb
        try:
            for item in data:
                
                point_current_ma = Point("HydroPower").tag("alias", item['name'] ).tag("measurement", 'current_ma' ).field("value", item["current_ma"])
                point_total_wh = Point("HydroPower").tag("alias", item['name'] ).tag("measurement", "total_wh" ).field("value", item["total_wh"])
                point_voltage_mv = Point("HydroPower").tag("alias", item['name'] ).tag("measurement", "voltage_mv" ).field("value", item["voltage_mv"])
                point_power_mw = Point("HydroPower").tag("alias", item['name'] ).tag("measurement", "power_mw" ).field("value", item["power_mw"])
                print(item)
                # print(point_current_ma)
                # print(point_voltage_mv)
                # print(point_total_wh)
                # print(point_power_mw)
                client.write(point_current_ma)
                client.write(point_total_wh)
                client.write(point_voltage_mv)
                client.write(point_power_mw)
                print("Wrote {} device data to InfluxDB successfully.".format(item['name']))  

        except Exception as e:
            print('Error: Failed to write points to InfluxDB:', e)




# Just for testing
# Encode the JSON string using base64
data_bytes = base64.b64encode(json.dumps({ "dummy": "data" }).encode('utf-8'))

# Create the Pub/Sub message
pubsub_message = {
    "data": data_bytes.decode('utf-8')
}
pull_data(pubsub_message, "")