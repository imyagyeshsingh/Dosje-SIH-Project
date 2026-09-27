from risk_engine import calculate_risk_score
from ai_event_manager import AIEventManager


class RiskAlertEngine:

    def __init__(self):
        self.event_manager = AIEventManager()

    def process(
        self,
        activity,
        people_count,
        confidence,
        inactive_seconds
    ):
        # Generate risk score
        risk = calculate_risk_score(
            activity,
            people_count,
            confidence,
            inactive_seconds
        )

        # Generate event / alert
        event = self.event_manager.process(
            activity,
            people_count,
            confidence,
            inactive_seconds
        )

        # Combine everything
        result = {
            "activity": activity,
            "people_detected": people_count,
            "confidence": confidence,
            "inactive_seconds": round(inactive_seconds, 2),

            "risk_score": risk["risk_score"],
            "risk_level": risk["risk_level"],
            "risk_reasons": risk["reasons"],

            "event_type": event["event_type"],
            "severity": event["severity"],
            "alert_reason": event["reason"],
            "timestamp": event["timestamp"]
        }

        return result