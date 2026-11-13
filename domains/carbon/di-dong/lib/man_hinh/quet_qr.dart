// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Quét mã QR trên giấy chứng nhận/nhãn tín chỉ bằng máy ảnh (flutter_zxing: zxing-cpp, Apache-2.0, chạy trên máy, không
// gửi ảnh đi đâu). Trả về nội dung mã cho màn kiểm chứng; mã có thể là số sê-ri hoặc đường link .../kiem-chung?q=...
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:material_ui/material_ui.dart';

class ManQuetQr extends StatefulWidget {
  const ManQuetQr({super.key});

  @override
  State<ManQuetQr> createState() => _ManQuetQrState();
}

class _ManQuetQrState extends State<ManQuetQr> {
  bool _daTra = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quét mã QR tín chỉ')),
      body: Stack(
        children: [
          ReaderWidget(
            codeFormat: Format.qrCode,
            showGallery: false,
            showToggleCamera: false,
            cropPercent: 0.7,
            onScan: (code) {
              final noiDung = code.text;
              if (_daTra || !code.isValid || noiDung == null || noiDung.trim().isEmpty) return;
              _daTra = true;
              Navigator.of(context).pop(noiDung);
            },
          ),
          const Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Đưa mã QR vào giữa khung. App tự đọc khi thấy mã.', style: TextStyle(fontSize: 17)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
