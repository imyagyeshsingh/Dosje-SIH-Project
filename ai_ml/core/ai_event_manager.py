import time
from datetime import datetime, timezone


class AIEventManager:
    """
    Converts continuous AI activity states into meaningful events.

    Example:

        NORMAL
        NORMAL
        SUSPICIOUS
        SUSPICIOUS
        SUSPICIOUS
        NORMAL

    becomes:

        SUSPICIOUS ALERT
        SUSPICIOUS CONTINUING
        SUSPICIOUS CLEARED
    """

    def __init__(self, alert_cooldown=30):

        self.current_activity = None
        self.previous_activity = None

        self.suspicious_since = None
        self.alert_sent = False

        self.alert_cooldown = alert_cooldown
        self.last_alert_time = 0

        self.event_history = []


    def process(self, activity, people_count, confidence, inactive_seconds):

        now = time.time()

        event_type = "STATE_UPDATE"
        severity = "INFO"
        reason = ""

        # ----------------------------------------------------
        # FIRST OBSERVED STATE
        # ----------------------------------------------------

        if self.current_activity is None:

            self.current_activity = activity

            if activity == "SUSPICIOUS":

                self.suspicious_since = now
                self.alert_sent = False

            return self._create_event(
                event_type,
                severity,
                activity,
                people_count,
                confidence,
                inactive_seconds,
                reason
            )


        self.previous_activity = self.current_activity
        self.current_activity = activity


        # ----------------------------------------------------
        # SUSPICIOUS STATE STARTED
        # ----------------------------------------------------

        if (
            activity == "SUSPICIOUS"
            and self.previous_activity != "SUSPICIOUS"
        ):

            self.suspicious_since = now
            self.alert_sent = False

            event_type = "ALERT_STARTED"
            severity = "HIGH"

            reason = (
                "People detected with prolonged inactivity"
            )


        # ----------------------------------------------------
        # SUSPICIOUS STATE CONTINUING
        # ----------------------------------------------------

        elif activity == "SUSPICIOUS":

            event_type = "ALERT_CONTINUING"
            severity = "HIGH"

            reason = (
                "Prolonged inactivity is continuing"
            )


        # ----------------------------------------------------
        # SUSPICIOUS STATE CLEARED
        # ----------------------------------------------------

        elif (
            self.previous_activity == "SUSPICIOUS"
            and activity != "SUSPICIOUS"
        ):

            event_type = "ALERT_CLEARED"
            severity = "INFO"

            reason = (
                "Activity detected again; "
                "suspicious condition cleared"
            )

            self.suspicious_since = None
            self.alert_sent = False


        # ----------------------------------------------------
        # NORMAL STATE
        # ----------------------------------------------------

        elif activity == "NORMAL":

            event_type = "NORMAL_ACTIVITY"
            severity = "INFO"

            reason = "Normal activity detected"


        # ----------------------------------------------------
        # LOW ACTIVITY
        # ----------------------------------------------------

        elif activity == "LOW":

            event_type = "LOW_ACTIVITY"
            severity = "MEDIUM"

            reason = "Low activity detected"


        # ----------------------------------------------------
        # HIGH ACTIVITY
        # ----------------------------------------------------

        elif activity == "HIGH":

            event_type = "HIGH_ACTIVITY"
            severity = "MEDIUM"

            reason = "High activity detected"


        # ----------------------------------------------------
        # NO ACTIVITY
        # ----------------------------------------------------

        elif activity == "NO_ACTIVITY":

            event_type = "NO_ACTIVITY"
            severity = "INFO"

            reason = "No people detected"


        event = self._create_event(
            event_type,
            severity,
            activity,
            people_count,
            confidence,
            inactive_seconds,
            reason
        )

        self.event_history.append(event)

        return event


    def _create_event(
        self,
        event_type,
        severity,
        activity,
        people_count,
        confidence,
        inactive_seconds,
        reason
    ):

        return {
            "event_type": event_type,
            "severity": severity,
            "activity": activity,
            "people_detected": people_count,
            "confidence": confidence,
            "inactive_seconds": round(
                inactive_seconds,
                2
            ),
            "reason": reason,
            "timestamp": datetime.now(
                timezone.utc
            ).isoformat()
        }


    def get_history(self):

        return self.event_history