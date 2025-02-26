import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

void main() {
  runApp(MaterialApp(home: DiseasePredictionScreen()));
}

class DiseasePredictionScreen extends StatefulWidget {
  @override
  _DiseasePredictionScreenState createState() =>
      _DiseasePredictionScreenState();
}

class _DiseasePredictionScreenState extends State<DiseasePredictionScreen> {
  File? _image;
  String? _result;
  double? _probability;
  String? _solution;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _predictDisease(_image!);
    }
  }

  Future<void> _predictDisease(File image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://192.168.43.39:8000/classify_all'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    var response = await request.send();
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      setState(() {
        _result = jsonResponse['classification'];
        _probability = jsonResponse['probability'];

        // Mapping disease to solutions
        _solution = _getSolution(_result);
      });
    }
  }

  String _getSolution(String? disease) {
    // Define your solutions mapping here
    Map<String, String> solutions = {
      "Blight": "Use copper-based fungicides.",
      "Rust": "Apply sulfur-based fungicides.",
      "Healthy": "No treatment needed.",
    };
    return solutions[disease] ?? "No solution available.";
  }

  Future<void> _generatePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build:
            (pw.Context context) => pw.Column(
              children: [
                pw.Text(
                  "Plant Disease Report",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text("Predicted Disease: $_result"),
                pw.Text(
                  "Confidence: ${(_probability! * 100).toStringAsFixed(2)}%",
                ),
                pw.Text("Recommended Solution: $_solution"),
              ],
            ),
      ),
    );

    final output = await getExternalStorageDirectory();
    final file = File("${output!.path}/plant_disease_report.pdf");

    await file.writeAsBytes(await pdf.save());
    OpenFile.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Plant Disease Prediction")),
      body: Column(
        children: [
          _image != null ? Image.file(_image!, height: 200) : Container(),
          ElevatedButton(
            onPressed: () => _pickImage(ImageSource.camera),
            child: Text("Take Photo"),
          ),
          ElevatedButton(
            onPressed: () => _pickImage(ImageSource.gallery),
            child: Text("Upload from Gallery"),
          ),
          if (_result != null) ...[
            Text("Disease: $_result"),
            Text("Probability: ${(_probability! * 100).toStringAsFixed(2)}%"),
            Text("Solution: $_solution"),
            ElevatedButton(onPressed: _generatePDF, child: Text("Save as PDF")),
          ],
        ],
      ),
    );
  }
}
