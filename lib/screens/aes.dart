import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/aes.service.dart';
import 'scanner.dart';

class AESMediaPage extends StatefulWidget {
  const AESMediaPage({super.key});

  @override
  State<AESMediaPage> createState() => _AESMediaPageState();
}

class _AESMediaPageState extends State<AESMediaPage> {
  final AESService _aesService = AESService(keySize: 128);
  String _selectedMediaPath = '';
  File? _previewImage;
  File? _outputFile;
  int _selectedSecurityLevel = 128;
  final List<Map<String, Uint8List>> _selectedDataSources = [];
  bool _showEncryptedPreview = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medya Şifreleme'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[700]!, Colors.blue[50]!],
            stops: const [0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 16),
                _buildSecurityLevelCard(),
                const SizedBox(height: 16),
                _buildSourcesCard(),
                const SizedBox(height: 16),
                _buildMediaCard(),
                if (_previewImage != null || _outputFile != null)
                  const SizedBox(height: 16),
                if (_previewImage != null && !_showEncryptedPreview)
                  _buildPreviewCard(),
                if (_outputFile != null && _showEncryptedPreview)
                  _buildOutputCard(),
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'AES Medya Şifreleme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'İki veri kaynağı seçin ve medya dosyanızı şifreleyin.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityLevelCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Güvenlik Seviyesi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [128, 192, 256]
                  .map((level) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('AES-$level'),
                            selected: _selectedSecurityLevel == level,
                            selectedColor: Colors.blue[100],
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedSecurityLevel = level);
                              }
                            },
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Veri Kaynakları',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  '${_selectedDataSources.length}/2',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildSourceButton(
                  icon: Icons.qr_code,
                  label: 'QR Kod',
                  onTap: () => _showSourcePicker('qr'),
                ),
                _buildSourceButton(
                  icon: Icons.qr_code_scanner,
                  label: 'Barkod',
                  onTap: () => _showSourcePicker('barcode'),
                ),
                _buildSourceButton(
                  icon: Icons.image,
                  label: 'Görüntü',
                  onTap: () => _showSourcePicker('image'),
                ),
                _buildSourceButton(
                  icon: Icons.audio_file,
                  label: 'Ses',
                  onTap: () => _showSourcePicker('audio'),
                ),
              ],
            ),
            if (_selectedDataSources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedDataSources
                    .map((source) => Chip(
                          label: Text(source.keys.first),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() => _selectedDataSources.remove(source));
                          },
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool isDisabled = _selectedDataSources.length >= 2;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.blue[700]),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _selectMedia,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                _selectedMediaPath.isEmpty
                    ? Icons.add_photo_alternate_outlined
                    : _getMediaIcon(),
                size: 48,
                color: Colors.blue[700],
              ),
              const SizedBox(height: 16),
              Text(
                _selectedMediaPath.isEmpty
                    ? 'Medya Dosyası Seç'
                    : _selectedMediaPath.split('/').last,
                style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (_selectedMediaPath.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _getMediaType(),
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Önizleme',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _previewImage!,
                fit: BoxFit.contain,
                height: 200,
                width: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Şifrelenmiş Dosya',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_outputFile != null) ...[
              FutureBuilder<Uint8List>(
                future: _outputFile!.readAsBytes(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final data = snapshot.data!;
                    final preview = base64Encode(data);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dosya Adı: ${_outputFile!.path.split('/').last}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text('Boyut: ${_formatSize(data.length)}'),
                        const SizedBox(height: 16),
                        const Text(
                          'Şifrelenmiş Veri Önizleme:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _showFullPreview(
                            data,
                            _outputFile!.path.split('/').last,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preview.length > 100
                                      ? '${preview.substring(0, 100)}...'
                                      : preview,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                                if (preview.length > 100) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tamamını görüntülemek için tıklayın',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _saveFile,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                                _isProcessing ? 'Kaydediliyor...' : 'Kaydet'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const CircularProgressIndicator();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _canProcess ? () => _processMedia(true) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isProcessing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[100]!,
                      ),
                    ),
                  )
                : const Icon(Icons.lock),
            label: Text(_isProcessing ? 'Şifreleniyor...' : 'Şifrele'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _canProcess ? () => _processMedia(false) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isProcessing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.green[100]!,
                      ),
                    ),
                  )
                : const Icon(Icons.lock_open),
            label: Text(_isProcessing ? 'Çözülüyor...' : 'Şifre Çöz'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveFile() async {
    if (_outputFile == null || !mounted) return;

    try {
      setState(() => _isProcessing = true);

      // Dosya içeriğini oku
      final bytes = await _outputFile!.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Dosya boş veya okunamadı');
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String originalFileName = _outputFile!.path.split('/').last;
      final String newFileName = 'encrypted_${timestamp}_$originalFileName';

      // Android için
      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }

          final File newFile = File('${downloadDir.path}/$newFileName');
          await newFile.writeAsBytes(bytes);

          if (mounted) {
            _showMessage('Dosya kaydedildi: ${newFile.path}');
          }
        } else {
          throw Exception('Depolama dizini bulunamadı');
        }
      }
      // iOS için
      else {
        final directory = await getApplicationDocumentsDirectory();
        final File newFile = File('${directory.path}/$newFileName');
        await newFile.writeAsBytes(bytes);

        if (mounted) {
          _showMessage('Dosya kaydedildi: ${newFile.path}');
        }
      }
    } catch (e) {
      debugPrint('Dosya kaydetme hatası: $e');
      if (mounted) {
        _showMessage('Dosya kaydedilemedi: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processMedia(bool encrypt) async {
    if (_selectedMediaPath.isEmpty) {
      _showMessage('Lütfen bir medya dosyası seçin');
      return;
    }

    if (_selectedDataSources.length < 2) {
      _showMessage('Lütfen 2 veri kaynağı seçin');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      _aesService.changeSecurityLevel(_selectedSecurityLevel);

      List<Uint8List> sourceKeys =
          _selectedDataSources.map((source) => source.values.first).toList();
      _aesService.generateKeyFromSources(sourceKeys);

      final mediaFile = File(_selectedMediaPath);
      final mediaBytes = await mediaFile.readAsBytes();

      Uint8List processedBytes;
      if (encrypt) {
        processedBytes = await _aesService.encryptFile(mediaBytes);
      } else {
        processedBytes = await _aesService.decryptFile(mediaBytes);
      }

      final extension = _selectedMediaPath.split('.').last;
      final fileName = '${encrypt ? 'encrypted' : 'decrypted'}_file.$extension';

      final tempDir = await getTemporaryDirectory();
      _outputFile = File('${tempDir.path}/$fileName');
      await _outputFile!.writeAsBytes(processedBytes);

      if (mounted) {
        setState(() {
          _showEncryptedPreview = encrypt;
          if (!encrypt &&
              ['jpg', 'jpeg', 'png'].contains(extension.toLowerCase())) {
            _previewImage = _outputFile;
          }
        });
        _showMessage('${encrypt ? 'Şifreleme' : 'Şifre çözme'} tamamlandı');
      }
    } catch (e) {
      debugPrint('İşlem hatası: $e');
      if (mounted) {
        _showMessage('İşlem sırasında hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSourcePicker(String type) {
    if (_selectedDataSources.length >= 2) {
      _showMessage('En fazla 2 veri kaynağı seçebilirsiniz');
      return;
    }

    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: const Text('Veri Kaynağı Seç'),
          actions: [
            if (type == 'qr')
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _captureQRCode();
                },
                child: const Text('Kamera ile QR Kod Tara'),
              ),
            if (type == 'barcode')
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _captureBarcode();
                },
                child: const Text('Kamera ile Barkod Tara'),
              ),
            if (type == 'image')
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _selectSourceImage();
                },
                child: const Text('Galeriden Seç'),
              ),
            if (type == 'audio')
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _selectSourceAudio();
                },
                child: const Text('Ses Dosyası Seç'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            isDestructiveAction: true,
            child: const Text('İptal'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == 'qr')
              ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('Kamera ile QR Kod Tara'),
                onTap: () {
                  Navigator.pop(context);
                  _captureQRCode();
                },
              ),
            if (type == 'barcode')
              ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Kamera ile Barkod Tara'),
                onTap: () {
                  Navigator.pop(context);
                  _captureBarcode();
                },
              ),
            if (type == 'image')
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _selectSourceImage();
                },
              ),
            if (type == 'audio')
              ListTile(
                leading: const Icon(Icons.audio_file),
                title: const Text('Ses Dosyası Seç'),
                onTap: () {
                  Navigator.pop(context);
                  _selectSourceAudio();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('İptal'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _captureQRCode() async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => WillPopScope(
            onWillPop: () async {
              Navigator.pop(context);
              return false;
            },
            child: const ScannerPage(title: 'QR Kod Tara'),
          ),
        ),
      );

      if (result != null && mounted) {
        var qrBytes = Uint8List.fromList(result.codeUnits);
        setState(() {
          _selectedDataSources.add({'QR Kod': qrBytes});
        });
        _showMessage('QR Kod başarıyla okundu');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('QR Kod okumada hata: $e');
      }
    }
  }

  Future<void> _captureBarcode() async {
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => WillPopScope(
            onWillPop: () async {
              Navigator.pop(context);
              return false;
            },
            child: const ScannerPage(title: 'Barkod Tara'),
          ),
        ),
      );

      if (result != null && mounted) {
        var barcodeBytes = Uint8List.fromList(result.codeUnits);
        setState(() {
          _selectedDataSources.add({'Barkod': barcodeBytes});
        });
        _showMessage('Barkod başarıyla okundu');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Barkod okumada hata: $e');
      }
    }
  }

  Future<void> _selectSourceImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        var imageBytes = await image.readAsBytes();
        setState(() {
          _selectedDataSources.add({'Görüntü': imageBytes});
        });
        _showMessage('Görüntü başarıyla eklendi');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Görüntü seçiminde hata: $e');
      }
    }
  }

  Future<void> _selectSourceAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav'],
      );

      if (result != null && mounted) {
        var audioBytes = await File(result.files.single.path!).readAsBytes();
        setState(() {
          _selectedDataSources.add({'Ses': audioBytes});
        });
        _showMessage('Ses dosyası başarıyla eklendi');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Ses dosyası seçiminde hata: $e');
      }
    }
  }

  Future<void> _selectMedia() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'mp3', 'wav'],
      );

      if (result != null && mounted) {
        setState(() {
          _selectedMediaPath = result.files.single.path!;
          _outputFile = null;
          _showEncryptedPreview = false;
          _previewImage = null;
        });
        await _generatePreview();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Medya seçiminde hata: $e');
      }
    }
  }

  Future<void> _generatePreview() async {
    if (_selectedMediaPath.isEmpty) return;

    try {
      final extension = _selectedMediaPath.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png'].contains(extension)) {
        setState(() {
          _previewImage = File(_selectedMediaPath);
        });
      }
    } catch (e) {
      debugPrint('Önizleme oluşturmada hata: $e');
    }
  }

  void _showFullPreview(Uint8List data, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Şifrelenmiş Veri'),
            backgroundColor: Colors.blue[700],
            actions: [
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: base64Encode(data)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kopyalandı')),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dosya: $fileName'),
                        Text('Boyut: ${_formatSize(data.length)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  base64Encode(data),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  IconData _getMediaIcon() {
    final extension = _selectedMediaPath.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      return Icons.image;
    } else if (['mp3', 'wav'].contains(extension)) {
      return Icons.audio_file;
    }
    return Icons.file_present;
  }

  String _getMediaType() {
    final extension = _selectedMediaPath.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png'].contains(extension)) {
      return 'Görüntü Dosyası';
    } else if (['mp3', 'wav'].contains(extension)) {
      return 'Ses Dosyası';
    }
    return 'Bilinmeyen Dosya Türü';
  }

  bool get _canProcess =>
      !_isProcessing &&
      _selectedMediaPath.isNotEmpty &&
      _selectedDataSources.length == 2;

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
