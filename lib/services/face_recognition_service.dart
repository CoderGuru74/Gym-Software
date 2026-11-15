import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset('assets/models/mobile_facenet.tflite');
  }

  /// Extracts a normalized facial embedding vector with square-aspect padding
  Future<List<double>?> extractFaceEmbedding(
    File imageFile, {
    bool flipHorizontal = false,
  }) async {
    await loadModel();
    if (_interpreter == null) return null;

    // 1. Detect face bounding box via ML Kit
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) return null;

    // Pick the largest face in frame
    Face targetFace = faces.first;
    for (final f in faces) {
      if (f.boundingBox.width * f.boundingBox.height >
          targetFace.boundingBox.width * targetFace.boundingBox.height) {
        targetFace = f;
      }
    }

    // 2. Decode and fix EXIF rotation
    final bytes = await imageFile.readAsBytes();
    img.Image? fullImage = img.decodeImage(bytes);
    if (fullImage == null) return null;
    fullImage = img.bakeOrientation(fullImage);

    // 3. Make a SQUARE crop around the face center with 25% margin so face is never stretched
    final Rect box = targetFace.boundingBox;
    final double centerX = box.left + box.width / 2.0;
    final double centerY = box.top + box.height / 2.0;
    final double maxSide = max(box.width, box.height) * 1.25;

    final int x = (centerX - maxSide / 2.0).toInt().clamp(0, fullImage.width - 1);
    final int y = (centerY - maxSide / 2.0).toInt().clamp(0, fullImage.height - 1);
    final int size = maxSide.toInt().clamp(
          1,
          min(fullImage.width - x, fullImage.height - y),
        );

    img.Image croppedFace = img.copyCrop(
      fullImage,
      x: x,
      y: y,
      width: size,
      height: size,
    );

    if (flipHorizontal) {
      croppedFace = img.flipHorizontal(croppedFace);
    }

    // 4. Read model input/output shapes dynamically
    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final int targetHeight = inputShape[1];
    final int targetWidth = inputShape[2];
    final int outDim = outputShape.last;

    final img.Image resizedFace = img.copyResize(
      croppedFace,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // 5. Build 4D input tensor [1, height, width, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        targetHeight,
        (py) => List.generate(
          targetWidth,
          (px) {
            final pixel = resizedFace.getPixel(px, py);
            return [
              (pixel.r - 127.5) / 128.0,
              (pixel.g - 127.5) / 128.0,
              (pixel.b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );

    final output = List.generate(1, (_) => List.filled(outDim, 0.0));
    _interpreter!.run(input, output);

    return _l2Normalize(List<double>.from(output[0]));
  }

  List<double> _l2Normalize(List<double> vector) {
    double sumSq = 0.0;
    for (final val in vector) {
      sumSq += val * val;
    }
    final norm = sqrt(sumSq);
    if (norm == 0.0) return vector;
    return vector.map((val) => val / norm).toList();
  }

  double cosineSimilarity(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < e1.length; i++) {
      dotProduct += e1[i] * e2[i];
      normA += e1[i] * e1[i];
      normB += e2[i] * e2[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    return denominator == 0.0 ? 0.0 : dotProduct / denominator;
  }

  void dispose() {
    _interpreter?.close();
    _faceDetector.close();
  }
}