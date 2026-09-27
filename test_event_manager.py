from ai_event_manager import AIEventManager


manager = AIEventManager()


test_sequence = [
    ("NORMAL", 2, 0.91, 0),
    ("NORMAL", 2, 0.92, 0),
    ("SUSPICIOUS", 2, 0.90, 15),
    ("SUSPICIOUS", 2, 0.91, 20),
    ("SUSPICIOUS", 2, 0.89, 25),
    ("NORMAL", 2, 0.93, 0),
]


for activity, people, confidence, inactive in test_sequence:

    event = manager.process(
        activity,
        people,
        confidence,
        inactive
    )

    print()
    print("EVENT")
    print("--------------------------------")
    print("Type       :", event["event_type"])
    print("Severity   :", event["severity"])
    print("Activity   :", event["activity"])
    print("People     :", event["people_detected"])
    print("Confidence :", event["confidence"])
    print("Inactive   :", event["inactive_seconds"])
    print("Reason     :", event["reason"])