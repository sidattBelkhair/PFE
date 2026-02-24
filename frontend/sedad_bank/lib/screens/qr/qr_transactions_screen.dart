import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';

class QrTransactionsScreen extends StatefulWidget {
  const QrTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<QrTransactionsScreen> createState() => _QrTransactionsScreenState();
}

class _QrTransactionsScreenState extends State<QrTransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey _qrKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Transactions QR',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Mon QR'), Tab(text: 'Scanner')],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyQR(), const _ScannerTab()],
      ),
    );
  }

  Widget _buildMyQR() {
    return Consumer2<AuthProvider, AccountProvider>(
      builder: (context, auth, ap, _) {
        final user = auth.currentUser;
        final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);

        if (account == null) {
          return const Center(
            child: Text(
              'Aucun compte disponible',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        // QR data: JSON-like string with account info
        final qrData = '{"account":"${account.accountNumber}","name":"${user?.getFullName() ?? ''}","currency":"${account.currency}"}';

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    // Real QR code
                    RepaintBoundary(
                      key: _qrKey,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 200,
                          gapless: true,
                          embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(40, 40)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      user?.getFullName() ?? 'Utilisateur',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.accountNumber,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        account.currency,
                        style: const TextStyle(color: AppTheme.darkGold, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Partagez ce QR code pour recevoir des paiements instantanément.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _shareQr(context),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Partager'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGold,
                          side: const BorderSide(color: AppTheme.primaryGold),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadQr(context),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Télécharger'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Future<Uint8List?> _captureQr() async {
    try {
      final RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareQr(BuildContext ctx) async {
    final bytes = await _captureQr();
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/sedad_qr.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'Mon QR code SEDAD BANK – Scannez pour me payer',
    );
  }

  Future<void> _downloadQr(BuildContext ctx) async {
    final bytes = await _captureQr();
    if (bytes == null) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la capture'), backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'sedad_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('QR enregistré : $fileName'),
            backgroundColor: AppTheme.successColor,
            action: SnackBarAction(
              label: 'Partager',
              textColor: Colors.white,
              onPressed: () async {
                await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')]);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}

// ── Onglet Scanner ────────────────────────────────────────────────────────────
class _ScannerTab extends StatefulWidget {
  const _ScannerTab();

  @override
  State<_ScannerTab> createState() => _ScannerTabState();
}

class _ScannerTabState extends State<_ScannerTab> {
  bool _scanning = false;
  String? _scannedData;
  MobileScannerController? _controller;

  void _startScan() {
    setState(() {
      _scanning = true;
      _scannedData = null;
      _controller = MobileScannerController();
    });
  }

  void _stopScan() {
    _controller?.stop();
    setState(() {
      _scanning = false;
      _controller = null;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _controller?.stop();
      setState(() {
        _scanning = false;
        _scannedData = barcode!.rawValue;
        _controller = null;
      });
      _handleScannedData(barcode!.rawValue!);
    }
  }

  void _handleScannedData(String data) {
    // Try to parse account info from QR data
    String? accountNumber;
    String? name;
    try {
      // Simple parsing since we encoded as JSON-like string
      final accountMatch = RegExp(r'"account":"([^"]+)"').firstMatch(data);
      final nameMatch = RegExp(r'"name":"([^"]+)"').firstMatch(data);
      accountNumber = accountMatch?.group(1);
      name = nameMatch?.group(1);
    } catch (_) {
      accountNumber = data;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ScannedResultSheet(
        accountNumber: accountNumber ?? data,
        name: name,
        rawData: data,
        onTransfer: () {
          Navigator.pop(ctx);
          context.push('/transfer');
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_scanning && _controller != null) {
      return Stack(
        children: [
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
          ),
          // Overlay
          Container(
            color: Colors.black.withOpacity(0.4),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryGold, width: 3),
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
              ),
            ),
          ),
          // Cancel button
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _stopScan,
                icon: const Icon(Icons.close),
                label: const Text('Annuler'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Pointez la caméra vers le QR code',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppTheme.lightGold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, size: 60, color: AppTheme.primaryGold),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scanner un QR code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scannez le QR code d\'un compte SEDAD BANK pour effectuer un virement instantané.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (_scannedData != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lightGold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Dernier scan : $_scannedData',
                  style: const TextStyle(fontSize: 12, color: AppTheme.darkGold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text(
                  'Ouvrir la caméra',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feuille résultat scan ─────────────────────────────────────────────────────
class _ScannedResultSheet extends StatelessWidget {
  final String accountNumber;
  final String? name;
  final String rawData;
  final VoidCallback onTransfer;

  const _ScannedResultSheet({
    required this.accountNumber,
    this.name,
    required this.rawData,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.dividerColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 56),
          const SizedBox(height: 12),
          const Text(
            'QR Code scanné !',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          if (name != null && name!.isNotEmpty) ...[
            Text(
              name!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            accountNumber,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, letterSpacing: 1.2),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTransfer,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Effectuer un virement'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ),
    );
  }
}
