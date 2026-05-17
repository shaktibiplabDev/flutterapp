import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Converts any image file to JPEG format before uploading to API.
///
/// This ensures that images captured from camera (which may be HEIC on iOS)
/// or picked from gallery (which may be PNG, WebP, etc.) are always converted
/// to JPEG before being sent to the API.
///
/// [quality] ranges from 0 to 100 (default 85) — higher means better quality.
///
/// Returns a new [File] with the JPEG-encoded image. If decoding fails,
/// returns the original file as a fallback.
Future<File> convertToJpeg(File imageFile, {int quality = 85}) async {
  try {
    final Uint8List originalBytes = await imageFile.readAsBytes();

    // Quick check: if already a valid JPEG, return as-is
    if (_isJpeg(originalBytes)) {
      debugPrint('ImageUtils: File is already JPEG — ${imageFile.path}');
      return imageFile;
    }

    // Decode the image (supports PNG, WebP, BMP, TIFF, GIF, HEIC*, etc.)
    // *HEIC support depends on platform; the image package handles common formats.
    final img.Image? decoded = await compute(_decodeImage, originalBytes);

    if (decoded == null) {
      debugPrint('ImageUtils: Could not decode image, returning original file');
      return imageFile;
    }

    // Encode as JPEG
    final Uint8List jpegBytes = Uint8List.fromList(
      img.encodeJpg(decoded, quality: quality),
    );

    // Write to a temp file with .jpg extension
    final Directory tempDir = await getTemporaryDirectory();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String jpegPath = '${tempDir.path}/converted_$timestamp.jpg';
    final File jpegFile = File(jpegPath);
    await jpegFile.writeAsBytes(jpegBytes);

    debugPrint(
      'ImageUtils: Converted ${imageFile.path} → $jpegPath '
      '(${originalBytes.length} → ${jpegBytes.length} bytes)',
    );
    return jpegFile;
  } catch (e) {
    debugPrint('ImageUtils: Error converting image to JPEG: $e');
    return imageFile;
  }
}

/// Converts a list of image files to JPEG format.
///
/// Useful for damage images or batch uploads.
Future<List<File>> convertMultipleToJpeg(
  List<File> imageFiles, {
  int quality = 85,
}) async {
  final List<File> convertedFiles = [];
  for (final file in imageFiles) {
    final converted = await convertToJpeg(file, quality: quality);
    convertedFiles.add(converted);
  }
  return convertedFiles;
}

/// Checks if the given bytes represent a JPEG file by examining the magic bytes.
/// JPEG files start with FF D8 FF.
bool _isJpeg(Uint8List bytes) {
  if (bytes.length < 3) return false;
  return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
}

/// Decodes image bytes in an isolate to avoid blocking the UI thread.
img.Image? _decodeImage(Uint8List bytes) {
  return img.decodeImage(bytes);
}
