import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

      final etiquetaImage = await _carregarImagem(_etiquetaFile!);
      final daceImage = await _carregarImagem(_daceFile!);

      // Tamanho padrão de etiqueta térmica (150mm x 100mm)
      const double widthPt = 150 * 2.83465;
      const double heightPt = 100 * 2.83465;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(widthPt, heightPt),
          margin: pw.EdgeInsets.zero, // Zera margens externas da página
          build: (pw.Context context) {
            return pw.Row(
              cross: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    margin: pw.EdgeInsets.zero,
                    child: pw.Image(
                      etiquetaImage,
                      fit: pw.BoxFit.fill, // Expande a etiqueta preenchendo toda a metade esquerda
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    margin: pw.EdgeInsets.zero,
                    child: pw.Image(
                      daceImage,
                      fit: pw.BoxFit.fill, // Expande o DACE preenchendo toda a metade direita
                    ),
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

  Future<pw.ImageProvider> _carregarImagem(File file) async {
    final bytes = await file.readAsBytes();
    if (file.path.endsWith('.pdf')) {
      await for (final page in Printing.raster(bytes, pages: [0], dpi: 300)) {
        final pngBytes = await page.toPng();
        return pw.MemoryImage(pngBytes);
      }
    }
    return pw.MemoryImage(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WL Decant - Etiquetas'),
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
                  ? 'Selecionar Etiqueta'
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
                  ? 'Selecionar DACE'
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
                          color: Colors.white),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
