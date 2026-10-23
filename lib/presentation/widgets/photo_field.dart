// lib/presentation/widgets/photo_field.dart
// Take or choose a photo of a document; hands back the image as base64.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../ui/ui.dart';

class PhotoField extends StatefulWidget {
  final String label;
  final String hint;
  final bool required;
  final ValueChanged<String?> onChanged;
  const PhotoField({super.key, required this.label, required this.onChanged, this.hint = 'Clear photo, all corners visible', this.required = true});

  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  Uint8List? _bytes;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 70);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 2 * 1024 * 1024) {
        if (mounted) dpSnack(context, 'That photo is too large. Please take it again.', error: true);
        return;
      }
      setState(() => _bytes = bytes);
      widget.onChanged(base64Encode(bytes));
    } catch (e) {
      if (mounted) dpSnack(context, 'Couldn\'t open the photo: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DPLabel(widget.required ? widget.label : '${widget.label} (optional)'),
          DPCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DP.rMd),
                  child: b == null
                      ? Container(
                          width: 64,
                          height: 48,
                          color: DP.mint,
                          child: const Icon(DPIcons.camera, color: DP.green),
                        )
                      : Image.memory(b, width: 64, height: 48, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(b == null ? widget.hint : 'Photo added', style: DP.caption)),
                if (b != null)
                  IconButton(
                    tooltip: 'Remove',
                    icon: Icon(DPIcons.close, color: DP.muted, size: 20),
                    onPressed: () {
                      setState(() => _bytes = null);
                      widget.onChanged(null);
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DPOutlineButton(label: 'Take photo', icon: DPIcons.camera, height: 44, onPressed: () => _pick(ImageSource.camera)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DPOutlineButton(label: 'Choose', icon: DPIcons.download, height: 44, onPressed: () => _pick(ImageSource.gallery)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
