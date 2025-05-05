import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Monitoring Kualitas Udara',
      theme: ThemeData(primarySwatch: Colors.green),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double coValue = 0.0;
  double suhu = 0.0;
  double kelembaban = 0.0;
  bool kipas = false; // Changed to boolean
  String kualitasUdara = 'Sedang'; // Will be one of: 'Baik', 'Sedang', 'Buruk'
  bool isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    fetchData();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      setState(() => isLoading = true);
      
      final snapshot = await FirebaseFirestore.instance
          .collection('history')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        setState(() {
          coValue = (data['co2'] ?? 0.0).toDouble();
          suhu = (data['suhu'] ?? 0.0).toDouble();
          kelembaban = (data['kelembaban'] ?? 0.0).toDouble();
          
          // Convert kipas value to boolean
          var kipasValue = data['kipas'];
          if (kipasValue is String) {
            kipas = kipasValue.toLowerCase() == 'true';
          } else if (kipasValue is bool) {
            kipas = kipasValue;
          } else {
            kipas = false;
          }
          
          // Handle udara with specific string values
          String udara = data['udara'] ?? 'Sedang';
          kualitasUdara = ['Baik', 'Sedang', 'Buruk'].contains(udara) ? udara : 'Sedang';
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('PlantAir Guard')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade100, Colors.green.shade400],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    InfoCard(
                      title: 'Kadar CO (MQ-7)',
                      value: '$coValue ppm',
                      icon: Icons.cloud,
                    ),
                    InfoCard(
                      title: 'Kualitas Udara',
                      value: kualitasUdara,
                      icon: Icons.air,
                    ),
                    InfoCard(
                      title: 'Suhu',
                      value: '$suhu °C',
                      icon: Icons.thermostat,
                    ),
                    InfoCard(
                      title: 'Kelembaban',
                      value: '$kelembaban %',
                      icon: Icons.water_drop,
                    ),
                    InfoCard(
                      title: 'Status Kipas',
                      value: kipas ? 'Aktif' : 'Nonaktif',
                      icon: Icons.toys,
                    ),
                  ],
                ),
                SizedBox(height: 20),
                isLoading
                    ? CircularProgressIndicator()
                    : ElevatedButton.icon(
                        onPressed: fetchData,
                        icon: Icon(Icons.refresh),
                        label: Text("Refresh"),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  double? getNumericValue() {
    if (value.contains('ppm')) {
      return double.tryParse(value.replaceAll(' ppm', ''));
    } else if (value.contains('°C')) {
      return double.tryParse(value.replaceAll(' °C', ''));
    } else if (value.contains('%')) {
      return double.tryParse(value.replaceAll(' %', ''));
    }
    return null;
  }

  Widget _buildGauge() {
    final numericValue = getNumericValue();
    if (numericValue == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      );
    }

    double maxValue = 100;
    String unit = '';
    Color gaugeColor;

    // Determine color and range based on the type of measurement
    if (value.contains('ppm')) {
      maxValue = 1000;
      unit = 'ppm';
      double percentage = numericValue / maxValue;
      gaugeColor = percentage <= 0.3
          ? Colors.green
          : percentage <= 0.6
              ? Colors.orange
              : Colors.red;
    } else if (value.contains('°C')) {
      maxValue = 50;
      unit = '°C';
      double percentage = numericValue / maxValue;
      gaugeColor = percentage <= 0.4
          ? Colors.blue
          : percentage <= 0.7
              ? Colors.green
              : Colors.red;
    } else {
      unit = '%';
      double percentage = numericValue / maxValue;
      gaugeColor = percentage <= 0.3
          ? Colors.red
          : percentage <= 0.7
              ? Colors.orange
              : Colors.green;
    }

    return SizedBox(
      height: 120,
      child: SfRadialGauge(
        enableLoadingAnimation: true,
        animationDuration: 2000,
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: maxValue,
            showLabels: false,
            showTicks: false,
            startAngle: 180, // Start from bottom left
            endAngle: 360, // End at bottom right
            axisLineStyle: AxisLineStyle(
              thickness: 0.25,
              thicknessUnit: GaugeSizeUnit.factor,
              color: Colors.grey[200],
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: numericValue,
                width: 0.25,
                sizeUnit: GaugeSizeUnit.factor,
                color: gaugeColor,
                enableAnimation: true,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 30), // Push the text down a bit
                    Text(
                      numericValue.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: gaugeColor,
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                angle: 270, // Center the text
                positionFactor: 0.5,
              ),
            ],
          ),
        ],
      ),
    );
  }



// teesting

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.green, size: 28),
            SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(child: _buildGauge()),
          ],
        ),
      ),
    );
  }
}