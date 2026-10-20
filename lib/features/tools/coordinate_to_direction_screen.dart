import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/sld99_converter.dart';

enum CoordinateInputType { sld99, wgs84 }

class CoordinateToDirectionScreen extends StatefulWidget {
  const CoordinateToDirectionScreen({super.key});

  @override
  State<CoordinateToDirectionScreen> createState() =>
      _CoordinateToDirectionScreenState();
}

class _CoordinateToDirectionScreenState
    extends State<CoordinateToDirectionScreen> {
  CoordinateInputType _inputType = CoordinateInputType.sld99;

  // Controllers for SLD99 input
  final _northCtrl = TextEditingController();
  final _eastCtrl = TextEditingController();

  // Controllers for WGS84 input
  final _latCtrl = TextEditingController();
  final _lonCtrl = TextEditingController();

  // Result state
  String? _resultText;
  double? _mapLat;
  double? _mapLon;

  void _convert() {
    if (_inputType == CoordinateInputType.sld99) {
      final n = double.tryParse(_northCtrl.text.trim());
      final e = double.tryParse(_eastCtrl.text.trim());

      if (n == null || e == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter valid numeric SLD99 coordinates')),
        );
        return;
      }

      final res = Sld99Converter.toWgs84(e, n);
      setState(() {
        _mapLat = res['lat'];
        _mapLon = res['lon'];
        _resultText =
            "WGS84 Coordinates\nLatitude: ${_mapLat!.toStringAsFixed(6)}\nLongitude: ${_mapLon!.toStringAsFixed(6)}";
      });
    } else {
      final lat = double.tryParse(_latCtrl.text.trim());
      final lon = double.tryParse(_lonCtrl.text.trim());

      if (lat == null || lon == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter valid numeric WGS84 coordinates')),
        );
        return;
      }

      final res = Sld99Converter.toSld99(lat, lon);
      setState(() {
        _mapLat = lat;
        _mapLon = lon;
        _resultText =
            "SLD99 Grid Coordinates\nEasting: ${res['easting']!.toStringAsFixed(3)} m\nNorthing: ${res['northing']!.toStringAsFixed(3)} m";
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_mapLat == null || _mapLon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No valid coordinates to open Google Maps')),
      );
      return;
    }

    final url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$_mapLat,$_mapLon");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  void _onInputTypeChanged(CoordinateInputType? newValue) {
    if (newValue != null && newValue != _inputType) {
      setState(() {
        _inputType = newValue;
        _resultText = null;
        _mapLat = null;
        _mapLon = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coordinate Converter')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<CoordinateInputType>(
              segments: const [
                ButtonSegment(
                  value: CoordinateInputType.sld99,
                  label: Text('SLD99 to WGS84'),
                ),
                ButtonSegment(
                  value: CoordinateInputType.wgs84,
                  label: Text('WGS84 to SLD99'),
                ),
              ],
              selected: {_inputType},
              onSelectionChanged: (Set<CoordinateInputType> newSelection) {
                _onInputTypeChanged(newSelection.first);
              },
            ),
            const SizedBox(height: 32),
            if (_inputType == CoordinateInputType.sld99) ...[
              const Text('SLD99 Grid Coordinates Input',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _northCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Northing (m)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.north),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _eastCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Easting (m)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.east),
                ),
              ),
            ] else ...[
              const Text('WGS84 Coordinates Input',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(
                controller: _latCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _lonCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _convert,
              style:
                  ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              child: const Text('Convert Coordinates',
                  style: TextStyle(fontSize: 18)),
            ),
            if (_resultText != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text('Conversion Result',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(_resultText!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.5)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _openInGoogleMaps,
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Google Maps'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(16)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
