import 'dart:io';
// import 'dart:typed_data'; // Uint8List için - file_saver kullandığı için genellikle gerekmez
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/receipt_parser.dart'; // Kendi dosyanız
import 'package:myapp/excel_exporter.dart'; // Kendi dosyanız
import 'firebase_options.dart'; // flutterfire configure tarafından oluşturulur
// import 'package:path_provider/path_provider.dart'; // FileSaver kullandığı için doğrudan import etmeye gerek yok
import 'package:file_saver/file_saver.dart'; // Dosya kaydetme için

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // To use Firebase services like ML Kit, you need to initialize Firebase.
  // Uncomment the following lines and run `flutterfire configure` to generate `firebase_options.dart`.\n
  // make sure you have created a firebase project and added your android/ios app to it
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Receipt OCR App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ReceiptScannerPage(),
    );
  }
}

class ReceiptScannerPage extends StatefulWidget {
  const ReceiptScannerPage({super.key});

  @override
  State<ReceiptScannerPage> createState() => _ReceiptScannerPageState();
}

class _ReceiptScannerPageState extends State<ReceiptScannerPage> {
  XFile? _pickedImage;
  ReceiptData? _receiptData;
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false; // İşlem durumunu takip etmek için

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isProcessing = true; // İşlem başladı
      _pickedImage = null; // Önceki resmi temizle
      _receiptData = null; // Önceki veriyi temizle
    });

    final XFile? image = await _picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
      await _recognizeText(image.path);
    } else {
      setState(() {
        _isProcessing = false; // İşlem tamamlandı (resim seçilmedi)
      });
    }
  }

  Future<void> _recognizeText(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final InputImage inputImage = InputImage.fromFilePath(imagePath);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Metin tanıma başarılı, şimdi ayrıştır
      final ReceiptData parsedData = parseReceiptText(recognizedText.text);

      if (!mounted) return; // mounted kontrolü
      setState(() {
        _receiptData = parsedData;
        _isProcessing = false; // İşlem tamamlandı
      });

    } catch (e) {
      // Hata durumunda
      if (!mounted) return; // mounted kontrolü
      setState(() {
        _receiptData = null; // Veriyi temizle
        _isProcessing = false; // İşlem tamamlandı
      });
      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Metin tanıma hatası: $e')),
      );
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> _exportToExcel() async {
    if (_receiptData == null) {
      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarılacak fiş verisi yok.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true; // İşlem başladı
    });

    try {
      // Sadece mevcut ayrıştırılmış fiş verisini listeye koyuyoruz
      final excelBytes = await exportReceiptsToExcel([_receiptData!]);

      if (excelBytes != null) {
        // Dosya kaydetme
        final String fileName = "receipts_${DateTime.now().millisecondsSinceEpoch}.xlsx";
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: excelBytes,
          ext: "xlsx",
          mimeType: MimeType.microsoftExcel,
        );

        if (!mounted) return; // mounted kontrolü
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel dosyası kaydedildi: $fileName')),
        );
      } else {
        if (!mounted) return; // mounted kontrolü
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel dosyası oluşturulamadı.')),
        );
      }
    } catch (e) {
      if (!mounted) return; // mounted kontrolü
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya kaydetme hatası: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false; // İşlem tamamlandı
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ElevatedButton(
                onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                child: const Text('Take Picture (Camera)'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                child: const Text('Pick from Gallery'),
              ),
              const SizedBox(height: 20),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else if (_pickedImage != null) ...[
                Image.file(
                  File(_pickedImage!.path),
                  height: 300,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Parsed Receipt Data:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Ayrıştırılmış fiş bilgilerini göster
                if (_receiptData != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Date: ${_receiptData!.date ?? "N/A"}'),
                      Text('Total Amount: ${_receiptData!.totalAmount?.toStringAsFixed(2) ?? "N/A"}'),
                      // Diğer bilgileri de buraya ekleyebilirsiniz (_receiptData.items gibi)
                      const SizedBox(height: 10),
                       Text('Raw Parsed Data: ${_receiptData.toString()}'), // Hata ayıklama için
                    ],
                  )
                else
                  const Text('No receipt data parsed yet.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _exportToExcel,
                  child: const Text('Export to Excel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}