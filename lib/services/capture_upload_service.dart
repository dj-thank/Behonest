import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CaptureUploadService {
  CaptureUploadService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  Future<File> buildCombinedPreview({
    required XFile backPhoto,
    required XFile frontPhoto,
  }) {
    return _combineImages(backPhoto: backPhoto, frontPhoto: frontPhoto);
  }

  Future<void> uploadPost({
    required String uid,
    required String tripId,
    required String momentId,
    required String displayName,
    required XFile backPhoto,
    required XFile frontPhoto,
    File? combinedPhoto,
  }) async {
    final combined = combinedPhoto ?? await _combineImages(
      backPhoto: backPhoto,
      frontPhoto: frontPhoto,
    );

    final basePath = 'trips/$tripId/moments/$momentId/posts/$uid';
    final frontUrl = await _uploadFile(
      File(frontPhoto.path),
      '$basePath/front.jpg',
    );
    final backUrl = await _uploadFile(
      File(backPhoto.path),
      '$basePath/back.jpg',
    );
    final combinedUrl = await _uploadFile(
      combined,
      '$basePath/combined.jpg',
    );

    await _db
        .collection('trips')
        .doc(tripId)
        .collection('moments')
        .doc(momentId)
        .collection('posts')
        .doc(uid)
        .set({
      'uid': uid,
      'displayName': displayName.trim().isEmpty ? 'Friend' : displayName.trim(),
      'frontImageUrl': frontUrl,
      'backImageUrl': backUrl,
      'combinedImageUrl': combinedUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtClient': Timestamp.now(),
      'captureOrder': 'back_then_front',
    }, SetOptions(merge: true));
  }

  Future<String> _uploadFile(File file, String path) async {
    final ref = _storage.ref(path);
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  Future<File> _combineImages({
    required XFile backPhoto,
    required XFile frontPhoto,
  }) async {
    final backBytes = await backPhoto.readAsBytes();
    final frontBytes = await frontPhoto.readAsBytes();

    final decodedBack = img.decodeImage(backBytes);
    final decodedFront = img.decodeImage(frontBytes);
    if (decodedBack == null || decodedFront == null) {
      throw StateError('写真の読み込みに失敗しました。');
    }

    final back = img.copyResize(
      img.bakeOrientation(decodedBack),
      width: 1200,
    );
    final front = img.bakeOrientation(decodedFront);
    final pipWidth = (back.width * 0.34).round();
    final pip = img.copyResize(front, width: pipWidth);

    const margin = 36;
    const border = 10;
    final framed = img.Image(
      width: pip.width + border * 2,
      height: pip.height + border * 2,
    );
    img.fill(framed, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(framed, pip, dstX: border, dstY: border);

    img.compositeImage(
      back,
      framed,
      dstX: back.width - framed.width - margin,
      dstY: margin,
    );

    final dir = await getTemporaryDirectory();
    final output = File(
      '${dir.path}/be_honest_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await output.writeAsBytes(img.encodeJpg(back, quality: 88));
    return output;
  }
}
