import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

// Storage-free image handling. The app runs on Firebase's free Spark plan,
// which doesn't include Cloud Storage, so images are compressed on-device
// (via image_picker's maxWidth/imageQuality) and stored as base64 text in
// Firestore instead. Keep the picked-image dimensions small so the encoded
// string stays well under Firestore's 1 MiB per-document limit.

/// Hard ceiling on a stored image's base64 length. Firestore documents cap at
/// ~1,048,576 bytes total; this leaves headroom for the rest of the document.
const int kMaxImageBase64Chars = 900000;

/// Reads an already-resized image file and returns it as base64, or null if the
/// result would be too large to store in a single Firestore document (the
/// caller should surface a "photo too large" message in that rare case).
Future<String?> fileToBase64(File file) async {
  final bytes = await file.readAsBytes();
  final encoded = base64Encode(bytes);
  if (encoded.length > kMaxImageBase64Chars) return null;
  return encoded;
}

/// Resolves a stored image value to an [ImageProvider]. The value may be:
///  - empty  → null (caller shows a placeholder),
///  - an http(s) URL (a Google profile photo, or a legacy Storage URL) →
///    [NetworkImage],
///  - otherwise a base64-encoded image → [MemoryImage].
/// Returns null on empty or undecodable input so callers can fall back cleanly.
ImageProvider? imageProviderFor(String value) {
  if (value.isEmpty) return null;
  if (value.startsWith('http')) return NetworkImage(value);
  try {
    return MemoryImage(base64Decode(value));
  } catch (_) {
    return null;
  }
}

/// A drop-in replacement for `Image.network(value, …)` that also renders base64
/// values. Shows [fallback] (or nothing) when the value is empty/undecodable or
/// fails to load.
Widget storedImage(
  String value, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? fallback,
}) {
  final provider = imageProviderFor(value);
  final fb = fallback ?? const SizedBox.shrink();
  if (provider == null) return fb;
  return Image(
    image: provider,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, _, _) => fb,
  );
}
