import cv2
from ultralytics import YOLO
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parents[1]


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

    results = model.track(
        frame,
        persist=True,
        tracker="bytetrack.yaml",
        classes=[0],
        conf=0.35,
        iou=0.5,
        verbose=False
    )

    people_count = 0

    for result in results:

        if result.boxes is None:
            continue

        for box in result.boxes:

            confidence = float(box.conf[0])

            x1, y1, x2, y2 = map(int, box.xyxy[0])

            people_count += 1

            if box.id is not None:

                track_id = int(box.id[0])

                label = f"Person ID: {track_id}"

            else:

                label = "Person"

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
                (x1, y1 - 10),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.6,
                (0, 255, 0),
                2
            )

    cv2.putText(
        frame,
        f"People detected: {people_count}",
        (20, 40),
        cv2.FONT_HERSHEY_SIMPLEX,
        1,
        (0, 255, 0),
        2
    )

    cv2.imshow(
        "SIH AI - Stable Person Tracking",
        frame
    )

    if cv2.waitKey(1) & 0xFF == ord("q"):
        break


cap.release()
cv2.destroyAllWindows()
