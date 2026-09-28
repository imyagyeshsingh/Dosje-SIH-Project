from ultralytics import YOLO
from pathlib import Path
BASE_DIR = Path(__file__).resolve().parents[1]

model = YOLO(str(BASE_DIR / "models" / "yolo11n.pt"))

results = model("https://ultralytics.com/images/bus.jpg")

for result in results:
    for box in result.boxes:
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        class_name = model.names[class_id]

        print(
            f"Detected: {class_name} | "
            f"Confidence: {confidence:.2f}"
        )
