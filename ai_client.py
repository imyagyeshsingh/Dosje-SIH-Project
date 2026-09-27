import requests

BACKEND_URL = "http://127.0.0.1:8000"
DETECTION_ENDPOINT = f"{BACKEND_URL}/ai/detection"


def send_detection(event):
    try:
        response = requests.post(
            DETECTION_ENDPOINT,
            json=event,
            timeout=15
        )

        if response.status_code == 201:
            print("BACKEND: Detection sent successfully")
            return True

        print(f"BACKEND: Detection rejected (HTTP {response.status_code})")
        print(response.text)
        return False

    except requests.exceptions.Timeout:
        print("BACKEND: Timeout after 15 seconds")
    except requests.exceptions.ConnectionError:
        print("BACKEND: Connection error")
    except requests.exceptions.RequestException as error:
        print(f"BACKEND: Error - {error}")

    return False