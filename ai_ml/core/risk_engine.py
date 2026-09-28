def calculate_risk_score(
    activity,
    people_count,
    confidence,
    inactive_seconds
):
    """
    Calculate a simple explainable risk score from 0 to 100.

    Higher score = higher inspection priority.
    """

    score = 0
    reasons = []

    # 1. Suspicious inactivity
    if activity == "SUSPICIOUS":
        score += 50
        reasons.append("People detected with prolonged inactivity")

    # 2. No activity
    elif activity == "NO_ACTIVITY":
        score += 10
        reasons.append("No people detected")

    # 3. Low activity
    elif activity == "LOW":
        score += 20
        reasons.append("Low activity detected")

    # 4. High activity
    elif activity == "HIGH":
        score += 15
        reasons.append("High activity detected")

    # 5. Prolonged inactivity
    if inactive_seconds >= 30:
        score += 20
        reasons.append("Very prolonged inactivity")
    elif inactive_seconds >= 15:
        score += 10
        reasons.append("Prolonged inactivity")

    # 6. Large number of people
    if people_count >= 8:
        score += 15
        reasons.append("High number of people detected")
    elif people_count >= 5:
        score += 5
        reasons.append("Multiple people detected")

    # 7. Detection confidence
    if confidence < 0.50:
        score += 5
        reasons.append("Low detection confidence")

    # Keep score between 0 and 100
    score = min(score, 100)

    # Risk level
    if score >= 75:
        risk_level = "CRITICAL"
    elif score >= 50:
        risk_level = "HIGH"
    elif score >= 25:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"

    return {
        "risk_score": score,
        "risk_level": risk_level,
        "reasons": reasons
    }