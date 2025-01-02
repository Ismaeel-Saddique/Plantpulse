import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'ui/onboarding_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; // For loading label file

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: OnboardingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? filePath;
  String label = '';
  double confidence = 0.0;
  List<String>? labels; // For storing loaded labels

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _tfLteInit();
    _loadLabels(); // Load labels on initialization
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.storage,
    ].request();

    if (statuses[Permission.camera] != PermissionStatus.granted ||
        statuses[Permission.storage] != PermissionStatus.granted) {
      setState(() {
        label = "Permissions granted!";
      });
    }
  }

  Future<void> _tfLteInit() async {
  String? res;
  try {
    res = await Tflite.loadModel(
      model: "assets/model_unquant.tflite", // Ensure this path is correct
      labels: "assets/labels.txt", // Make sure to load the labels file too
      numThreads: 1,
      isAsset: true,  // Make sure this is set to true when loading from assets
      useGpuDelegate: false,
    );
    print('Model loaded: $res');
  } catch (e) {
    print('Error loading model: $e');
  }
}

  // Load labels from the file
  Future<void> _loadLabels() async {
    String labelData = await rootBundle.loadString('assets/labels.txt'); // Assuming labels.txt in assets folder
    setState(() {
      labels = labelData.split('\n');
    });
  }

  Future<void> _runModelOnImage(String path) async {
    var recognitions = await Tflite.runModelOnImage(
      path: path,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 1,
      threshold: 0,
      asynch: true,
    );

    if (recognitions == null || recognitions.isEmpty) {
      setState(() {
        label = "Recognition failed!";
        confidence = 0.0;
      });
      return;
    }

  
    int labelIndex = recognitions[0]['index']; 
    String labelName = labels != null && labelIndex < labels!.length
        ? labels![labelIndex]
        : "Unknown Label";

    setState(() {
      confidence = (recognitions[0]['confidence'] * 100);
      label = recognitions[0]['label'].toString();
    });
  }

  Future<void> pickImageGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() {
      filePath = File(image.path);
    });

    await _runModelOnImage(image.path);
  }

  Future<void> pickImageCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    setState(() {
      filePath = File(image.path);
    });

    await _runModelOnImage(image.path);
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PlantPulse", style: TextStyle(fontSize: 20)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Card(
                elevation: 20,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 300,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        Container(
                          height: 280,
                          width: 280,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            image: const DecorationImage(
                              image: AssetImage('assets/upload.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: filePath == null
                              ? const Text('')
                              : Image.file(
                                  filePath!,
                                  fit: BoxFit.fill,
                                ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "The Accuracy is ${confidence.toStringAsFixed(0)}%",
                                style: const TextStyle(
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: pickImageCamera,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Pick from Camera",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: pickImageGallery,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Pick from Gallery",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
