from risk_engine import calculate_risk_score


test_cases = [
    ("NORMAL", 2, 0.90, 0),
    ("LOW", 2, 0.88, 5),
    ("SUSPICIOUS", 2, 0.91, 15),
    ("SUSPICIOUS", 3, 0.89, 35),
    ("HIGH", 8, 0.92, 0),
    ("NO_ACTIVITY", 0, 1.0, 0),
]


for activity, people, confidence, inactive in test_cases:

    result = calculate_risk_score(
        activity,
        people,
        confidence,
        inactive
    )

    print("\n-----------------------------")
    print("Activity   :", activity)
    print("People     :", people)
    print("Confidence :", confidence)
    print("Inactive   :", inactive)
    print("Risk Score :", result["risk_score"])
    print("Risk Level :", result["risk_level"])
    print("Reasons    :", result["reasons"])