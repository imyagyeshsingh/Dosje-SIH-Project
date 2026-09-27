from risk_alert_engine import RiskAlertEngine


engine = RiskAlertEngine()


test_cases = [
    ("NORMAL", 3, 0.92, 0),
    ("LOW", 2, 0.88, 5),
    ("SUSPICIOUS", 2, 0.91, 15),
    ("SUSPICIOUS", 3, 0.89, 35),
    ("HIGH", 8, 0.93, 0),
    ("NO_ACTIVITY", 0, 1.0, 0),
]


for activity, people, confidence, inactive in test_cases:

    result = engine.process(
        activity,
        people,
        confidence,
        inactive
    )

    print("\n================================")
    print("Activity        :", result["activity"])
    print("People detected :", result["people_detected"])
    print("Confidence      :", result["confidence"])
    print("Inactive        :", result["inactive_seconds"], "sec")

    print("Risk Score      :", result["risk_score"])
    print("Risk Level      :", result["risk_level"])

    print("Event Type      :", result["event_type"])
    print("Severity        :", result["severity"])

    print("Risk Reasons    :", result["risk_reasons"])
    print("Alert Reason    :", result["alert_reason"])