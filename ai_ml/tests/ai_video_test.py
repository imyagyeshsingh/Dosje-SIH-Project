import cv2
from ultralytics import YOLO
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parents[1]


def determine_activity(people_count):
    if people_count == 0:
        return "NO_ACTIVITY"
    elif people_count <= 2:
        return "LOW"
    elif people_count <= 5:
        return "NORMAL"
    else:
        return "HIGH"


model = YOLO(str(BASE_DIR / "models" / "yolo11n.pt"))

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("Could not open camera")
    exit()


while True:

    ret, frame = cap.read()

    if not ret:
        print("Could not read frame")
        break

    results = model(frame, verbose=False)

    people_count = 0

    for result in results:

        for box in result.boxes:

            class_id = int(box.cls[0])
            confidence = float(box.conf[0])

            if class_id == 0 and confidence >= 0.5:

                people_count += 1

                x1, y1, x2, y2 = map(int, box.xyxy[0])

                cv2.rectangle(
                    frame,
                    (x1, y1),
                    (x2, y2),
                    (0, 255, 0),
                    2
                )

                cv2.putText(
                    frame,
                    f"Person {confidence:.2f}",
                    (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.6,
                    (0, 255, 0),
                    2
                )

    activity = determine_activity(people_count)

    cv2.putText(
        frame,
        f"People detected: {people_count}",
        (20, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        1,
        (0, 255, 0),
        2
    )

    cv2.putText(
        frame,
        f"Activity: {activity}",
        (20, 80),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 255, 0),
        2
    )

    cv2.imshow(
        "SIH AI - People Detection",
        frame
    )

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break


cap.release()
cv2.destroyAllWindows()
