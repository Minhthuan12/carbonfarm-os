// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
// Quét mã QR trên giấy chứng nhận/nhãn tín chỉ bằng máy ảnh (flutter_zxing: zxing-cpp, Apache-2.0, chạy trên máy, không
// gửi ảnh đi đâu). Trả về nội dung mã cho màn kiểm chứng; mã có thể là số sê-ri hoặc đường link .../kiem-chung?q=...
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../giao_dien.dart';

class ManQuetQr extends StatefulWidget {
  const ManQuetQr({super.key});

  @override
  State<ManQuetQr> createState() => _ManQuetQrState();
}

class _ManQuetQrState extends State<ManQuetQr> {
  bool _daTra = false;

  @override
  Widget build(BuildContext context) {
    final chu = context.chu;
    final khung = MediaQuery.sizeOf(context).width * 0.7;
    // Nền tối: chữ thanh trạng thái màu sáng
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1F1A),
        body: Stack(
          children: [
            ReaderWidget(
              codeFormat: Format.qrCode,
              showGallery: false,
              showToggleCamera: false,
              cropPercent: 0.7,
              actionButtonsBackgroundColor: mauChinhDam,
              scannerOverlay: ScannerOverlayBorder(
                cutOutSize: khung,
                borderColor: const Color(0xFF7FD8B8),
                borderWidth: 5,
                borderRadius: 22,
                borderLength: 40,
                overlayColor: const Color(0xB30B1F1A),
              ),
              onScan: (code) {
                final noiDung = code.text;
                if (_daTra || !code.isValid || noiDung == null || noiDung.trim().isEmpty) return;
                _daTra = true;
                Navigator.of(context).pop(noiDung);
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Quay lại',
                          icon: const Icon(FLucideIcons.arrowLeft, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Text(
                          'Quét mã QR tín chỉ',
                          style: chu.display.lg.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(FLucideIcons.scanQrCode, color: Color(0xFF7FD8B8), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Đưa mã QR trên giấy chứng nhận vào giữa khung. App tự đọc khi thấy mã.',
                              style: chu.body.sm.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
