import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const WLDecantApp());
}

class WLDecantApp extends StatelessWidget {
  const WLDecantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WL Decant - Mesclador',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFE8ECEF),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _etiquetaFile;
  File? _daceFile;
  final TextEditingController _pedidoController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _selecionarEtiqueta() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _etiquetaFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _selecionarDace() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _daceFile = File(result.files.single.path!);
      });
    }
  }

  /// Recorta bordas brancas usando amostragem compativel
  Uint8List _removerBordasBrancas(Uint8List inputBytes) {
    try {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) return inputBytes;

      int minX = decoded.width;
      int minY = decoded.height;
      int maxX = 0;
      int maxY = 0;

      for (int y = 0; y < decoded.height; y += 2) {
        for (int x = 0; x < decoded.width; x += 2) {
          final pixel = decoded.getPixel(x, y);
          final r = pixel.r;
          final g = pixel.g;
          final b = pixel.b;

          if (r < 240 || g < 240 || b < 240) {
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }

      if (minX >= maxX || minY >= maxY) return inputBytes;

      final cropped = img.copyCrop(
        decoded,
        x: minX,
        y: minY,
        width: maxX - minX,
        height: maxY - minY,
      );

      return Uint8List.fromList(img.encodePng(cropped));
    } catch (_) {
      return inputBytes;
    }
  }

  Future<pw.ImageProvider> _carregarEProcessarImagem(File file) async {
    final bytes = await file.readAsBytes();
    Uint8List pngBytes = bytes;

    if (file.path.toLowerCase().endsWith('.pdf')) {
      await for (final page in Printing.raster(bytes, pages: [0], dpi: 300)) {
        pngBytes = await page.toPng();
        break;
      }
    }

    final bytesSemBorda = _removerBordasBrancas(pngBytes);
    return pw.MemoryImage(bytesSemBorda);
  }

  Future<void> _gerarPdf() async {
    if (_etiquetaFile == null || _daceFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ambos os arquivos!')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final pdf = pw.Document();

      final etiquetaImage = await _carregarEProcessarImagem(_etiquetaFile!);
      final daceImage = await _carregarEProcessarImagem(_daceFile!);

      // Tamanho padrao 150mm x 100mm
      const double widthPt = 150 * 2.83465;
      const double heightPt = 100 * 2.83465;

      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(widthPt, heightPt),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Row(
              cross: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Image(
                    etiquetaImage,
                    fit: pw.BoxFit.fill,
                  ),
                ),
                pw.Container(
                  width: 1,
                  color: PdfColors.grey400,
                ),
                pw.Expanded(
                  child: pw.Image(
                    daceImage,
                    fit: pw.BoxFit.fill,
                  ),
                ),
              ],
            );
          },
        ),
      );

      final pedido = _pedidoController.text.trim();
      final nomeArquivo = pedido.isNotEmpty
          ? 'Etiqueta Mesclada - Pedido $pedido.pdf'
          : 'Etiqueta Mesclada.pdf';

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: nomeArquivo,
      );

      setState(() {
        _etiquetaFile = null;
        _daceFile = null;
        _pedidoController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao processar: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WL Decant - Mesclador'),
        backgroundColor: const Color(0xFF3B82C4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _selecionarEtiqueta,
              icon: const Icon(Icons.label),
              label: Text(_etiquetaFile == null
                  ? '1. Selecionar Etiqueta'
                  : 'Etiqueta: ${_etiquetaFile!.path.split('/').last}'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: _selecionarDace,
              icon: const Icon(Icons.receipt),
              label: Text(_daceFile == null
                  ? '2. Selecionar DACE'
                  : 'DACE: ${_daceFile!.path.split('/').last}'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pedidoController,
              decoration: const InputDecoration(
                labelText: 'Número do Pedido',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            _isProcessing
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _gerarPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82C4),
                      minimumSize: const Size.fromHeight(55),
                    ),
                    child: const Text(
                      'GERAR E IMPRIMIR PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
