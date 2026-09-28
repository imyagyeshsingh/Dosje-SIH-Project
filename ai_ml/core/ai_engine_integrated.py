import cv2
import time
from datetime import datetime, timezone
from collections import defaultdict, deque

from ultralytics import YOLO

from .ai_client import send_detection
from .risk_alert_engine import RiskAlertEngine


# ============================================================
# CONFIGURATION
# ============================================================

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parents[1]
MODEL_PATH = BASE_DIR / "models" / "yolo11n-pose.pt"

VIDEO_SOURCE = BASE_DIR / "videos" / "istockphoto-2160472791-640_adpp_is.mp4"

CONFIDENCE_THRESHOLD = 0.35

# Pose movement thresholds
KEYPOINT_MOVEMENT_THRESHOLD = 0.012
ACTIVE_POSE_THRESHOLD = 0.012

# Inactivity thresholds
MIN_INACTIVITY_SECONDS = 15
STRONG_INACTIVITY_SECONDS = 30

# Activity smoothing
SMOOTHING_WINDOW = 8

# Send one detection to backend every N seconds
EVENT_INTERVAL = 5

# Backend identifiers
PROJECT_ID = 163
CAMERA_ID = 65


# ============================================================
# COCO KEYPOINT INDICES
# ============================================================

NOSE = 0

LEFT_SHOULDER = 5
RIGHT_SHOULDER = 6

LEFT_ELBOW = 7
RIGHT_ELBOW = 8

LEFT_WRIST = 9
RIGHT_WRIST = 10


# ============================================================
# LOAD MODEL AND VIDEO
# ============================================================

print("Loading pose model...")

model = YOLO(MODEL_PATH)

print("Pose model loaded.")

cap = cv2.VideoCapture(str(VIDEO_SOURCE))

if not cap.isOpened():
    print("ERROR: Could not open video.")
    exit()

print("Video opened successfully.")


# ============================================================
# TRACKING DATA
# ============================================================

previous_keypoints = {}

last_movement_time = defaultdict(lambda: time.time())

activity_history = deque(maxlen=SMOOTHING_WINDOW)

last_event_time = 0


# ============================================================
# AI RISK / ALERT ENGINE
# ============================================================

risk_alert_engine = RiskAlertEngine()


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_keypoint_movement(previous_points, current_points, bbox):
    """
    Calculate normalized movement of body keypoints.

    Movement is normalized using bounding-box dimensions so
    movement remains comparable for people at different sizes.
    """

    if previous_points is None:
        return 0.0

    if current_points is None:
        return 0.0

    if len(previous_points) == 0 or len(current_points) == 0:
        return 0.0

    x1, y1, x2, y2 = bbox

    box_width = max(x2 - x1, 1)
    box_height = max(y2 - y1, 1)

    total_movement = 0.0
    valid_points = 0

    point_count = min(
        len(previous_points),
        len(current_points)
    )

    for i in range(point_count):

        previous_x = float(previous_points[i][0])
        previous_y = float(previous_points[i][1])

        current_x = float(current_points[i][0])
        current_y = float(current_points[i][1])

        # Ignore invalid keypoints
        if (
            previous_x <= 0
            or previous_y <= 0
            or current_x <= 0
            or current_y <= 0
        ):
            continue

        dx = abs(current_x - previous_x) / box_width
        dy = abs(current_y - previous_y) / box_height

        movement = (dx + dy) / 2

        total_movement += movement
        valid_points += 1

    if valid_points == 0:
        return 0.0

    return total_movement / valid_points


def calculate_upper_body_activity(previous_points, current_points, bbox):
    """
    Focus on upper-body movement.

    This is particularly useful for seated workers because
    their body bounding box may remain almost stationary while
    their head, shoulders, elbows and wrists move.
    """

    important_points = [
        NOSE,
        LEFT_SHOULDER,
        RIGHT_SHOULDER,
        LEFT_ELBOW,
        RIGHT_ELBOW,
        LEFT_WRIST,
        RIGHT_WRIST
    ]

    if previous_points is None or current_points is None:
        return 0.0

    movements = []

    for index in important_points:

        if index >= len(previous_points):
            continue

        if index >= len(current_points):
            continue

        previous_x = float(previous_points[index][0])
        previous_y = float(previous_points[index][1])

        current_x = float(current_points[index][0])
        current_y = float(current_points[index][1])

        if (
            previous_x <= 0
            or previous_y <= 0
            or current_x <= 0
            or current_y <= 0
        ):
            continue

        x1, y1, x2, y2 = bbox

        box_width = max(x2 - x1, 1)
        box_height = max(y2 - y1, 1)

        dx = abs(current_x - previous_x) / box_width
        dy = abs(current_y - previous_y) / box_height

        movement = (dx + dy) / 2

        movements.append(movement)

    if not movements:
        return 0.0

    return sum(movements) / len(movements)


def classify_activity(
    people_count,
    active_people,
    average_pose_activity,
    longest_inactive_seconds
):
    """
    Activity classification for PS 26095.

    IMPORTANT:

    SUSPICIOUS does NOT mean intrusion.

    SUSPICIOUS means:
    people are present but prolonged inactivity is detected.
    """

    # Nobody detected
    if people_count == 0:
        return "NO_ACTIVITY"

    # People are actively moving.
    # Treat this as normal working activity.
    if (
        active_people >= 1
        and average_pose_activity >= ACTIVE_POSE_THRESHOLD
    ):
        return "NORMAL"

    # People are present but have been inactive
    # for a prolonged period.
    if longest_inactive_seconds >= STRONG_INACTIVITY_SECONDS:
        return "SUSPICIOUS"

    # Some inactivity, but not enough for suspicious state.
    if longest_inactive_seconds >= MIN_INACTIVITY_SECONDS:
        return "LOW"

    # People are present but movement evidence is weak.
    return "LOW"


def smooth_activity(activity):
    """
    Prevent rapid activity switching between states.
    """

    activity_history.append(activity)

    if not activity_history:
        return activity

    counts = {}

    for item in activity_history:
        counts[item] = counts.get(item, 0) + 1

    return max(
        counts,
        key=counts.get
    )


def calculate_activity_evidence(
    full_pose_activity,
    upper_body_activity
):
    """
    Combine whole-body and upper-body movement.

    Upper-body movement receives more weight because workers
    can remain seated while still actively working.
    """

    evidence = (
        0.4 * full_pose_activity
        + 0.6 * upper_body_activity
    )

    return round(evidence, 3)


def calculate_confidence(detection_confidences):
    """
    Average YOLO detection confidence.
    """

    if not detection_confidences:
        return 0.0

    return round(
        sum(detection_confidences)
        / len(detection_confidences),
        2
    )


def create_event(
    activity,
    people_count,
    confidence,
    inactive_seconds=0,
    active_people=0,
    event_type=None
):
    """
    Create a structured AI event.

    Existing backend fields are preserved for compatibility.
    Additional AI context is included for future risk/alert processing.
    """

    return {
        "project_id": PROJECT_ID,
        "camera_id": CAMERA_ID,
        "people_detected": people_count,
        "activity": activity,
        "confidence": confidence,
        "inactive_seconds": round(inactive_seconds, 2),
        "active_people": active_people,
        "event_type": event_type,
        "timestamp": datetime.now(
            timezone.utc
        ).isoformat()
    }


# ============================================================
# MAIN VIDEO PROCESSING LOOP
# ============================================================

while True:

    ret, frame = cap.read()

    if not ret:
        print("Video processing completed.")
        break

    current_time = time.time()

    # --------------------------------------------------------
    # YOLO POSE + BYTE TRACK
    # --------------------------------------------------------

    results = model.track(
        frame,
        persist=True,
        tracker="bytetrack.yaml",
        conf=CONFIDENCE_THRESHOLD,
        iou=0.5,
        verbose=False
    )

    people_count = 0
    active_people = 0

    detection_confidences = []

    current_pose_activities = []

    longest_inactive_seconds = 0

    # --------------------------------------------------------
    # PROCESS DETECTIONS
    # --------------------------------------------------------

    for result in results:

        if result.boxes is None:
            continue

        if result.keypoints is None:
            continue

        for index, box in enumerate(result.boxes):

            confidence = float(box.conf[0])

            if confidence < CONFIDENCE_THRESHOLD:
                continue

            people_count += 1

            detection_confidences.append(confidence)

            # Bounding box
            x1, y1, x2, y2 = map(
                int,
                box.xyxy[0]
            )

            # Track ID
            if box.id is not None:
                track_id = int(box.id[0])
            else:
                track_id = index

            # ------------------------------------------------
            # KEYPOINTS
            # ------------------------------------------------

            keypoints = result.keypoints.data[index]

            current_points = []

            for point in keypoints:

                px = float(point[0])
                py = float(point[1])

                current_points.append(
                    [px, py]
                )

            # ------------------------------------------------
            # GET PREVIOUS KEYPOINTS
            # ------------------------------------------------

            previous_points = previous_keypoints.get(
                track_id
            )

            # ------------------------------------------------
            # CALCULATE MOVEMENT BEFORE UPDATING HISTORY
            # ------------------------------------------------

            full_pose_activity = calculate_keypoint_movement(
                previous_points,
                current_points,
                (x1, y1, x2, y2)
            )

            upper_body_activity = calculate_upper_body_activity(
                previous_points,
                current_points,
                (x1, y1, x2, y2)
            )

            pose_activity = calculate_activity_evidence(
                full_pose_activity,
                upper_body_activity
            )

            current_pose_activities.append(
                pose_activity
            )

            # ------------------------------------------------
            # UPDATE PREVIOUS KEYPOINTS
            # ------------------------------------------------

            previous_keypoints[track_id] = current_points

            # ------------------------------------------------
            # MOVEMENT / INACTIVITY
            # ------------------------------------------------

            if pose_activity >= KEYPOINT_MOVEMENT_THRESHOLD:

                last_movement_time[track_id] = current_time

            inactive_seconds = (
                current_time
                - last_movement_time[track_id]
            )

            longest_inactive_seconds = max(
                longest_inactive_seconds,
                inactive_seconds
            )

            # Active person
            if pose_activity >= ACTIVE_POSE_THRESHOLD:
                active_people += 1

            # ------------------------------------------------
            # DRAW PERSON
            # ------------------------------------------------

            cv2.rectangle(
                frame,
                (x1, y1),
                (x2, y2),
                (0, 255, 0),
                2
            )

            label = (
                f"Person {track_id} "
                f"{confidence:.2f}"
            )

            cv2.putText(
                frame,
                label,
                (x1, max(y1 - 10, 20)),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.55,
                (0, 255, 0),
                2
            )

            # ------------------------------------------------
            # DRAW POSE KEYPOINTS
            # ------------------------------------------------

            for point in current_points:

                px = int(point[0])
                py = int(point[1])

                if px <= 0 or py <= 0:
                    continue

                cv2.circle(
                    frame,
                    (px, py),
                    4,
                    (255, 0, 0),
                    -1
                )

    # ========================================================
    # ACTIVITY ANALYSIS
    # ========================================================

    if current_pose_activities:

        average_pose_activity = (
            sum(current_pose_activities)
            / len(current_pose_activities)
        )

    else:

        average_pose_activity = 0.0

    average_pose_activity = round(
        average_pose_activity,
        3
    )

    raw_activity = classify_activity(
        people_count,
        active_people,
        average_pose_activity,
        longest_inactive_seconds
    )

    activity = smooth_activity(
        raw_activity
    )

    # ========================================================
    # CONFIDENCE
    # ========================================================

    if people_count == 0:

        confidence = 1.0

    else:

        confidence = calculate_confidence(
            detection_confidences
        )

    # ========================================================
    # RISK + ALERT ANALYSIS
    # ========================================================

    risk_result = risk_alert_engine.process(
        activity=activity,
        people_count=people_count,
        confidence=confidence,
        inactive_seconds=longest_inactive_seconds
    )

    risk_score = risk_result["risk_score"]
    risk_level = risk_result["risk_level"]

    event_type = risk_result["event_type"]
    severity = risk_result["severity"]

    # ========================================================
    # SEND EVENT TO BACKEND
    # ========================================================

    if (
        current_time - last_event_time
        >= EVENT_INTERVAL
    ):

        event = create_event(
            activity,
            people_count,
            confidence,
            inactive_seconds=longest_inactive_seconds,
            active_people=active_people,
            event_type=event_type
        )

        print("\nAI EVENT")
        print(event)

        send_detection(event)

        last_event_time = current_time

    # ========================================================
    # DISPLAY INFORMATION
    # ========================================================

    cv2.putText(
        frame,
        f"People: {people_count}",
        (20, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.9,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Active Pose: {active_people}",
        (20, 75),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.9,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Activity: {activity}",
        (20, 110),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.9,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Pose Evidence: {average_pose_activity:.3f}",
        (20, 145),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Inactive: {longest_inactive_seconds:.1f}s",
        (20, 180),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Risk: {risk_score} ({risk_level})",
        (20, 215),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 0),
        2
    )

    # --------------------------------------------------------
    # ALERT DISPLAY
    # --------------------------------------------------------

    if event_type == "ALERT_STARTED":

        cv2.putText(
            frame,
            "ALERT: PROLONGED INACTIVITY",
            (20, 255),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            (0, 0, 255),
            2
        )

    elif event_type == "ALERT_CONTINUING":

        cv2.putText(
            frame,
            "ALERT CONTINUING",
            (20, 255),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            (0, 0, 255),
            2
        )

    elif event_type == "ALERT_CLEARED":

        cv2.putText(
            frame,
            "ALERT CLEARED",
            (20, 255),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.75,
            (0, 255, 255),
            2
        )

    # ========================================================
    # SHOW VIDEO
    # ========================================================

    cv2.imshow(
        "PS 26095 - Pose Activity Analysis",
        frame
    )

    # Press Q to quit
    if cv2.waitKey(1) & 0xFF == ord("q"):
        break


# ============================================================
# CLEANUP
# ============================================================

cap.release()
cv2.destroyAllWindows()

print("\nAI processing finished.")

