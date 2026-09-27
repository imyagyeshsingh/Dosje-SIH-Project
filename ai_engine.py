import cv2
import time
import json
from datetime import datetime, timezone
from collections import defaultdict, deque
from ultralytics import YOLO


# ============================================================
# CONFIGURATION
# ============================================================

MODEL_PATH = "yolo11n.pt"

# 0 = laptop webcam
# Later this can be changed to a video file or CCTV URL.
VIDEO_SOURCE = 0

CONFIDENCE_THRESHOLD = 0.35

# Movement threshold in pixels per second.
# This is intentionally configurable because a webcam has
# no real-world distance calibration.
MOVEMENT_THRESHOLD = 25

# How long people can remain detected with little/no movement
# before we classify the situation as suspicious.
NO_WORKING_THRESHOLD = 15

# Number of recent activity classifications used for smoothing.
SMOOTHING_WINDOW = 8

# Send/display a new JSON event at this interval.
EVENT_INTERVAL = 5

# People-count thresholds.
LOW_PEOPLE = 2
HIGH_PEOPLE = 5


# ============================================================
# MODEL
# ============================================================

model = YOLO(MODEL_PATH)


# ============================================================
# VIDEO
# ============================================================

cap = cv2.VideoCapture(VIDEO_SOURCE)

if not cap.isOpened():
    print("Could not open camera/video.")
    exit()


# ============================================================
# TRACKING DATA
# ============================================================

# Stores recent positions for every tracked person.
position_history = defaultdict(lambda: deque(maxlen=20))

# Stores the last time each person showed meaningful movement.
last_movement_time = {}

# Stores when each person was first detected.
first_seen_time = {}

# Stores recent activity states for temporal smoothing.
activity_history = deque(maxlen=SMOOTHING_WINDOW)

last_event_time = 0


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def calculate_speed(track_id, current_x, current_y, current_time):
    """
    Calculate approximate movement speed in pixels/second.
    """

    history = position_history[track_id]

    if len(history) == 0:
        history.append((current_x, current_y, current_time))
        return 0.0

    previous_x, previous_y, previous_time = history[-1]

    distance = (
        (current_x - previous_x) ** 2
        + (current_y - previous_y) ** 2
    ) ** 0.5

    time_difference = current_time - previous_time

    if time_difference <= 0:
        speed = 0.0
    else:
        speed = distance / time_difference

    history.append((current_x, current_y, current_time))

    return speed


def classify_activity(
    people_count,
    moving_people,
    average_speed,
    longest_inactive_time
):
    """
    Determine project activity state.

    Project interpretation:
    - NO_ACTIVITY = nobody detected
    - LOW = people present but low activity
    - NORMAL = normal working activity
    - HIGH = high activity/crowd
    - SUSPICIOUS = people present but prolonged lack of activity
    """

    if people_count == 0:
        return "NO_ACTIVITY"

    # People are present but no meaningful working activity
    # has been observed for the configured duration.
    if longest_inactive_time >= NO_WORKING_THRESHOLD:
        return "SUSPICIOUS"

    # High number of people or many simultaneously moving people.
    if people_count > HIGH_PEOPLE or moving_people >= 4:
        return "HIGH"

    # Some people and some movement.
    if moving_people > 0 and average_speed >= MOVEMENT_THRESHOLD:
        return "NORMAL"

    # People detected but little movement.
    if people_count <= LOW_PEOPLE:
        return "LOW"

    return "NORMAL"


def smooth_activity(new_activity):
    """
    Temporal smoothing prevents the classification from
    changing wildly from one frame to another.
    """

    activity_history.append(new_activity)

    counts = {}

    for activity in activity_history:
        counts[activity] = counts.get(activity, 0) + 1

    return max(counts, key=counts.get)


def calculate_confidence(detection_confidences, activity):
    """
    Backend requires confidence between 0 and 1.

    For people-present events we use the average YOLO
    detection confidence.

    For NO_ACTIVITY we use 1.0 because the detector has
    consistently found no person in the frame.

    This is detection confidence, not a calibrated probability
    that a person is actually working.
    """

    if activity == "NO_ACTIVITY":
        return 1.0

    if not detection_confidences:
        return 0.0

    return round(
        sum(detection_confidences) / len(detection_confidences),
        3
    )


def create_event(
    people_count,
    activity,
    confidence
):
    """
    Create the exact structure required by the backend AI
    detection endpoint.
    """

    return {
        "project_id": 1,
        "camera_id": 1,
        "people_detected": people_count,
        "activity": activity,
        "confidence": confidence,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }


# ============================================================
# MAIN AI LOOP
# ============================================================

print()
print("==========================================")
print("      DOSJE SENTINEL - AI ENGINE")
print("==========================================")
print("YOLO model      :", MODEL_PATH)
print("Video source    :", VIDEO_SOURCE)
print("Movement limit  :", MOVEMENT_THRESHOLD)
print("Suspicious after:", NO_WORKING_THRESHOLD, "seconds")
print()
print("Press Q to stop.")
print()


while True:

    ret, frame = cap.read()

    if not ret:
        print("Could not read frame.")
        break

    current_time = time.time()

    results = model.track(
        frame,
        persist=True,
        tracker="bytetrack.yaml",
        classes=[0],
        conf=CONFIDENCE_THRESHOLD,
        iou=0.5,
        verbose=False
    )

    people_count = 0
    moving_people = 0

    detection_confidences = []
    speeds = []
    inactive_times = []

    # --------------------------------------------------------
    # PROCESS DETECTED PEOPLE
    # --------------------------------------------------------

    for result in results:

        if result.boxes is None:
            continue

        for box in result.boxes:

            confidence = float(box.conf[0])

            x1, y1, x2, y2 = map(
                int,
                box.xyxy[0]
            )

            people_count += 1
            detection_confidences.append(confidence)

            # ------------------------------------------------
            # TRACK ID
            # ------------------------------------------------

            if box.id is not None:

                track_id = int(box.id[0])

                # Person center
                center_x = (x1 + x2) // 2
                center_y = (y1 + y2) // 2

                # First detection
                if track_id not in first_seen_time:

                    first_seen_time[track_id] = current_time
                    last_movement_time[track_id] = current_time

                # Calculate movement
                speed = calculate_speed(
                    track_id,
                    center_x,
                    center_y,
                    current_time
                )

                speeds.append(speed)

                # Determine whether person is moving
                if speed >= MOVEMENT_THRESHOLD:

                    moving_people += 1
                    last_movement_time[track_id] = current_time

                inactive_time = (
                    current_time
                    - last_movement_time[track_id]
                )

                inactive_times.append(inactive_time)

                # ------------------------------------------------
                # DRAW PERSON
                # ------------------------------------------------

                label = (
                    f"ID {track_id} | "
                    f"{confidence:.2f}"
                )

                cv2.rectangle(
                    frame,
                    (x1, y1),
                    (x2, y2),
                    (0, 255, 0),
                    2
                )

                cv2.putText(
                    frame,
                    label,
                    (x1, max(20, y1 - 10)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.55,
                    (0, 255, 0),
                    2
                )

                cv2.putText(
                    frame,
                    f"Speed: {speed:.1f}",
                    (x1, y2 + 20),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.5,
                    (0, 255, 255),
                    2
                )

    # --------------------------------------------------------
    # CALCULATE OVERALL MOVEMENT
    # --------------------------------------------------------

    if speeds:
        average_speed = sum(speeds) / len(speeds)
    else:
        average_speed = 0.0

    if inactive_times:
        longest_inactive_time = max(inactive_times)
    else:
        longest_inactive_time = 0.0

    # --------------------------------------------------------
    # ACTIVITY CLASSIFICATION
    # --------------------------------------------------------

    raw_activity = classify_activity(
        people_count,
        moving_people,
        average_speed,
        longest_inactive_time
    )

    activity = smooth_activity(raw_activity)

    # --------------------------------------------------------
    # CONFIDENCE
    # --------------------------------------------------------

    confidence = calculate_confidence(
        detection_confidences,
        activity
    )

    # --------------------------------------------------------
    # DISPLAY MAIN INFORMATION
    # --------------------------------------------------------

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
        f"Moving: {moving_people}",
        (20, 75),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 255),
        2
    )

    cv2.putText(
        frame,
        f"Activity: {activity}",
        (20, 110),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 255),
        2
    )

    cv2.putText(
        frame,
        f"Confidence: {confidence:.2f}",
        (20, 145),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (255, 255, 255),
        2
    )

    cv2.putText(
        frame,
        f"Inactive: {longest_inactive_time:.1f}s",
        (20, 180),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.7,
        (255, 255, 255),
        2
    )

    # --------------------------------------------------------
    # JSON EVENT
    # --------------------------------------------------------

    if current_time - last_event_time >= EVENT_INTERVAL:

        event = create_event(
            people_count,
            activity,
            confidence
        )

        print()
        print("AI EVENT")
        print(json.dumps(event, indent=2))

        last_event_time = current_time

    # --------------------------------------------------------
    # SHOW VIDEO
    # --------------------------------------------------------

    cv2.imshow(
        "Dosje Sentinel - AI Engine",
        frame
    )

    # Q = quit
    if cv2.waitKey(1) & 0xFF == ord("q"):
        break


# ============================================================
# CLEANUP
# ============================================================

cap.release()
cv2.destroyAllWindows()

print()
print("AI engine stopped.")