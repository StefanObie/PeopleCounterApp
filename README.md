# People Counter App

People Counter App is a Flutter mobile app for counting people in images with a local YOLOv5 TensorFlow Lite model. It is designed around on-device processing, private storage, and manual review tools such as masking, threshold tuning, collections, and count correction.

Images are processed locally on the device, detections are reviewed visually, and saved sessions remain in app-private storage.

> ## Get the App on Google Play
> [Download People Counter App](https://play.google.com/store/apps/details?id=com.people.counter)

## What the App Does

- Counts people in images using a YOLOv5 TensorFlow Lite model.
- Uses head detections instead of full-body detections for better performance in crowded scenes.
- Lets the user draw exclusion masks on top of an image so specific regions are ignored.
- Supports adjustable confidence and IoU thresholds for tuning detection behavior.
- Organizes saved results into collections that can contain multiple images.
- Stores the original count, manual correction, notes, thresholds, and mask data for each saved session.

## Privacy Model

Privacy is a core requirement of the app.

- Inference runs on-device using TensorFlow Lite.
- The production Android manifest does not request internet access.
- Images are not uploaded to any external service.
- There is no account system, analytics pipeline, or cloud processing layer in this project.
- Saved images are copied into app-private storage and referenced locally.

Android permissions are limited to what the app needs for image input:

- `CAMERA` for capturing a photo.
- `READ_MEDIA_IMAGES` for selecting an image from device media.

## Stack

- Flutter and Dart for the mobile app UI and app logic.
- TensorFlow Lite with a YOLOv5 model for on-device detection.
- `image` for decoding, resizing, and applying masks before inference.
- `image_picker` for camera and gallery import.
- `sqflite`, `path_provider`, and `shared_preferences` for local data and saved settings.

## Detection Pipeline

The app loads the TensorFlow Lite model once and reuses it while the app is running. High-level flow:

1. The user selects or captures an image.
2. The image is resized to the model input size of `640 x 640`.
3. Any drawn mask regions are applied before inference.
4. The image is normalized and sent to the YOLOv5 TensorFlow Lite model.
5. The app keeps head detections, removes overlapping boxes, and maps the results back onto the original image.
6. The final detections are drawn on the image and used for the count.

## Masking and Review Workflow

The app includes drawing tools so the user can exclude parts of an image from the count.

- Drawn paths are captured in original image coordinates.
- Before inference, those paths are transformed into the resized letterboxed image space.
- The mask is applied before model execution so excluded regions do not contribute detections.
- Saved sessions keep the serialized mask paths, which allows the same review context to be restored later.

## Collections and Corrections

Collections are the app's way of grouping related counting sessions. Each collection can contain multiple saved images, and each saved session records:

- The detected people count
- A manual correction value
- The corrected total
- Notes
- The image path
- Confidence threshold
- IoU threshold
- Serialized mask paths
- Timestamp

This lets the app support both automated counting and human review. A detection result is not treated as immutable. The user can revisit a saved session, reload the image and masking state, and refine the final number.

## Local Storage Design

The app stores everything locally:

- SQLite stores collections and saved count sessions, including the detected count, manual correction, notes, thresholds, and mask data.
- Saved images are copied into app-private storage under `collection_images/` so the app does not depend on the original media path.
- Confidence and IoU threshold settings are saved with `SharedPreferences` and restored when the app restarts.

<!-- ## Technical Notes

- Input tensor shape is `1 x 640 x 640 x 3` float32.
- Input color order is RGB.
- Pixel values are normalized to `[0, 1]`.
- Post-processing includes greedy non-maximum suppression in Dart.
- The app stores completed mask strokes in original image coordinates so they remain stable across UI resizes.
- Saved sessions include enough metadata to recreate the review state later. -->

## Credits

- [Ilham Fitrotul Hayat](https://www.flaticon.com/free-icons/user) for the user icons through Flaticon.
- [matthewrt](https://huggingface.co/spaces/matthewrt/people-counting) for providing the PyTorch YOLOv5 model used in this app, which was converted to TensorFlow Lite format for use in this app.
