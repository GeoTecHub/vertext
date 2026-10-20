import 'package:flutter/material.dart';
import '../../utils/conversions.dart';

enum UnitCategory { length, specializedArea, volume, angle }

class UnitConverterScreen extends StatelessWidget {
  const UnitConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Conversion Type')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GridView.extent(
          maxCrossAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCategoryTile(
              context,
              title: 'Length',
              icon: Icons.straighten,
              color: Colors.blue,
              category: UnitCategory.length,
            ),
            _buildCategoryTile(
              context,
              title: 'Area',
              icon: Icons.square_foot,
              color: Colors.green,
              category: UnitCategory.specializedArea,
            ),
            _buildCategoryTile(
              context,
              title: 'Volume',
              icon: Icons.view_in_ar,
              color: Colors.orange,
              category: UnitCategory.volume,
            ),
            _buildCategoryTile(
              context,
              title: 'Angle',
              icon: Icons.explore,
              color: Colors.purple,
              category: UnitCategory.angle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required UnitCategory category,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ActiveUnitConverterScreen(category: category, title: title),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveUnitConverterScreen extends StatefulWidget {
  final UnitCategory category;
  final String title;

  const ActiveUnitConverterScreen({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<ActiveUnitConverterScreen> createState() =>
      _ActiveUnitConverterScreenState();
}

class _ActiveUnitConverterScreenState extends State<ActiveUnitConverterScreen> {
  late UnitCategory _selectedCategory;

  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  late String _fromUnit;
  late String _toUnit;

  // Area converter specific state (Card 1)
  String _specializedAreaUnit1 = 'Hectares';
  final _specializedAreaCtrl1 = TextEditingController();
  final _acresCtrl1 = TextEditingController();
  final _roodsCtrl1 = TextEditingController();
  final _perchesCtrl1 = TextEditingController();

  // Area converter specific state (Card 2)
  String _specializedAreaUnit2 = 'Acres/Roods/Perches';
  final _specializedAreaCtrl2 = TextEditingController();
  final _acresCtrl2 = TextEditingController();
  final _roodsCtrl2 = TextEditingController();
  final _perchesCtrl2 = TextEditingController();

  final Map<UnitCategory, List<String>> _units = {
    UnitCategory.length: [
      'Meters',
      'Kilometers',
      'Centimeters',
      'Millimeters',
      'Miles',
      'Yards',
      'Feet',
      'Inches'
    ],
    UnitCategory.specializedArea: [
      'Square Meters',
      'Hectares',
      'Square Kilometers',
      'Acres',
      'Square Feet',
      'Square Yards',
      'Acres/Roods/Perches'
    ],
    UnitCategory.volume: [
      'Cubic Meters',
      'Liters',
      'Milliliters',
      'Gallons (US)',
      'Cubic Feet',
      'Cubic Yards'
    ],
    UnitCategory.angle: ['Degrees', 'Radians', 'Gradians'],
  };

  // Base unit conversions to a common base
  final Map<String, double> _conversionFactors = {
    // Length (Base: Meters)
    'Meters': 1.0,
    'Kilometers': 1000.0,
    'Centimeters': 0.01,
    'Millimeters': 0.001,
    'Miles': 1609.344,
    'Yards': 0.9144,
    'Feet': 0.3048,
    'Inches': 0.0254,

    // Area (Base: Square Meters)
    'Square Meters': 1.0,
    'Hectares': 10000.0,
    'Square Kilometers': 1000000.0,
    'Acres': 4046.85642,
    'Square Feet': 0.09290304,
    'Square Yards': 0.83612736,

    // Volume (Base: Cubic Meters)
    'Cubic Meters': 1.0,
    'Liters': 0.001,
    'Milliliters': 0.000001,
    'Gallons (US)': 0.00378541,
    'Cubic Feet': 0.0283168,
    'Cubic Yards': 0.764555,

    // Angle (Base: Degrees)
    'Degrees': 1.0,
    'Radians': 57.295779513, // 180 / pi
    'Gradians': 0.9, // 90 degrees = 100 gradians
  };

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    if (_selectedCategory != UnitCategory.specializedArea) {
      _fromUnit = _units[_selectedCategory]![0];
      _toUnit = _units[_selectedCategory]![1];
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    _specializedAreaCtrl1.dispose();
    _acresCtrl1.dispose();
    _roodsCtrl1.dispose();
    _perchesCtrl1.dispose();
    _specializedAreaCtrl2.dispose();
    _acresCtrl2.dispose();
    _roodsCtrl2.dispose();
    _perchesCtrl2.dispose();
    super.dispose();
  }

  void _convert() {
    final inputValue = double.tryParse(_inputController.text.trim());
    if (inputValue == null) {
      _outputController.text = '';
      return;
    }

    final fromFactor = _conversionFactors[_fromUnit]!;
    final toFactor = _conversionFactors[_toUnit]!;

    // Convert from source to base, then from base to target
    final baseValue = inputValue * fromFactor;
    final targetValue = baseValue / toFactor;

    _outputController.text = _formatValue(targetValue);
  }

  String _formatValue(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(6)
        .replaceAll(RegExp(r'0*$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _formatSpecializedAreaValue(double v, String unit) {
    if (unit == 'Hectares') return v.toStringAsFixed(4);
    return _formatValue(v);
  }

  void _swapUnits() {
    setState(() {
      final temp = _fromUnit;
      _fromUnit = _toUnit;
      _toUnit = temp;

      final tempText = _inputController.text;
      _inputController.text = _outputController.text;
      _outputController.text = tempText;
    });
    _convert();
  }

  void _swapAreaUnits() {
    setState(() {
      final tempU = _specializedAreaUnit1;
      _specializedAreaUnit1 = _specializedAreaUnit2;
      _specializedAreaUnit2 = tempU;

      final tempV = _specializedAreaCtrl1.text;
      _specializedAreaCtrl1.text = _specializedAreaCtrl2.text;
      _specializedAreaCtrl2.text = tempV;

      final tempA = _acresCtrl1.text;
      _acresCtrl1.text = _acresCtrl2.text;
      _acresCtrl2.text = tempA;

      final tempR = _roodsCtrl1.text;
      _roodsCtrl1.text = _roodsCtrl2.text;
      _roodsCtrl2.text = tempR;

      final tempP = _perchesCtrl1.text;
      _perchesCtrl1.text = _perchesCtrl2.text;
      _perchesCtrl2.text = tempP;
    });
    _recalcFromArea1();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} Converter')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedCategory == UnitCategory.specializedArea)
                  _buildAreaConverter()
                else
                  _buildStandardConverter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==== Standard Converter Sub-View ====
  Widget _buildStandardConverter() {
    return Column(
      children: [
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _fromUnit,
                        decoration: const InputDecoration(
                            labelText: 'From', border: OutlineInputBorder()),
                        items: _units[_selectedCategory]!.map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _fromUnit = val);
                            _convert();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _inputController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter Value',
                  ),
                  onChanged: (_) => _convert(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: IconButton(
            icon: const Icon(Icons.swap_vert, size: 40, color: Colors.blueGrey),
            onPressed: _swapUnits,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _toUnit,
                        decoration: const InputDecoration(
                            labelText: 'To', border: OutlineInputBorder()),
                        items: _units[_selectedCategory]!.map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _toUnit = val);
                            _convert();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _outputController,
                  readOnly: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Result',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==== Specialized Area Converter Logic ====
  void _recalcFromArea1() {
    double baseSqMeters = 0;

    if (_specializedAreaUnit1 == 'Acres/Roods/Perches') {
      final a = double.tryParse(_acresCtrl1.text.trim()) ?? 0;
      final r = double.tryParse(_roodsCtrl1.text.trim()) ?? 0;
      final p = double.tryParse(_perchesCtrl1.text.trim()) ?? 0;
      baseSqMeters = arpToHectares(a, r, p) * 10000.0;
    } else {
      final value = double.tryParse(_specializedAreaCtrl1.text.trim());
      if (value == null) return;
      baseSqMeters = value * _conversionFactors[_specializedAreaUnit1]!;
    }

    _updateArea2FromBase(baseSqMeters);
  }

  void _recalcFromArea2() {
    double baseSqMeters = 0;

    if (_specializedAreaUnit2 == 'Acres/Roods/Perches') {
      final a = double.tryParse(_acresCtrl2.text.trim()) ?? 0;
      final r = double.tryParse(_roodsCtrl2.text.trim()) ?? 0;
      final p = double.tryParse(_perchesCtrl2.text.trim()) ?? 0;
      baseSqMeters = arpToHectares(a, r, p) * 10000.0;
    } else {
      final value = double.tryParse(_specializedAreaCtrl2.text.trim());
      if (value == null) return;
      baseSqMeters = value * _conversionFactors[_specializedAreaUnit2]!;
    }

    _updateArea1FromBase(baseSqMeters);
  }

  void _updateArea1FromBase(double baseSqMeters) {
    if (_specializedAreaUnit1 == 'Acres/Roods/Perches') {
      final h = baseSqMeters / 10000.0;
      final arp = hectaresToARP(h);
      _updateIfChanged(_acresCtrl1, arp['acres']!.toInt().toString());
      _updateIfChanged(_roodsCtrl1, arp['roods']!.toInt().toString());
      _updateIfChanged(_perchesCtrl1, arp['perches']!.toString());
    } else {
      final val = baseSqMeters / _conversionFactors[_specializedAreaUnit1]!;
      _updateIfChanged(_specializedAreaCtrl1,
          _formatSpecializedAreaValue(val, _specializedAreaUnit1));
    }
  }

  void _updateArea2FromBase(double baseSqMeters) {
    if (_specializedAreaUnit2 == 'Acres/Roods/Perches') {
      final h = baseSqMeters / 10000.0;
      final arp = hectaresToARP(h);
      _updateIfChanged(_acresCtrl2, arp['acres']!.toInt().toString());
      _updateIfChanged(_roodsCtrl2, arp['roods']!.toInt().toString());
      _updateIfChanged(_perchesCtrl2, arp['perches']!.toString());
    } else {
      final val = baseSqMeters / _conversionFactors[_specializedAreaUnit2]!;
      _updateIfChanged(_specializedAreaCtrl2,
          _formatSpecializedAreaValue(val, _specializedAreaUnit2));
    }
  }

  void _updateIfChanged(TextEditingController ctrl, String val) {
    if (ctrl.text != val) {
      ctrl.text = val;
    }
  }

  // ==== Specialized Area Converter UI ====
  Widget _buildAreaConverter() {
    return Column(
      children: [
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _specializedAreaUnit1,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: _units[UnitCategory.specializedArea]!
                            .map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _specializedAreaUnit1 = val);
                            _recalcFromArea1();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_specializedAreaUnit1 == 'Acres/Roods/Perches')
                  Row(
                    children: [
                      Expanded(
                          child: _buildUnitField(
                              'Acres', _acresCtrl1, _recalcFromArea1)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildUnitField(
                              'Roods', _roodsCtrl1, _recalcFromArea1)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildUnitField(
                              'Perches', _perchesCtrl1, _recalcFromArea1)),
                    ],
                  )
                else
                  TextField(
                    controller: _specializedAreaCtrl1,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, color: Colors.blue),
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (_) => _recalcFromArea1(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: IconButton(
            icon: const Icon(Icons.swap_vert, size: 40, color: Colors.blueGrey),
            onPressed: _swapAreaUnits,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _specializedAreaUnit2,
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: _units[UnitCategory.specializedArea]!
                            .map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _specializedAreaUnit2 = val);
                            _recalcFromArea2();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_specializedAreaUnit2 == 'Acres/Roods/Perches')
                  Row(
                    children: [
                      Expanded(
                          child: _buildUnitField(
                              'Acres', _acresCtrl2, _recalcFromArea2)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildUnitField(
                              'Roods', _roodsCtrl2, _recalcFromArea2)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildUnitField(
                              'Perches', _perchesCtrl2, _recalcFromArea2)),
                    ],
                  )
                else
                  TextField(
                    controller: _specializedAreaCtrl2,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, color: Colors.blue),
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (_) => _recalcFromArea2(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _specializedAreaCtrl1.clear();
              _acresCtrl1.clear();
              _roodsCtrl1.clear();
              _perchesCtrl1.clear();

              _specializedAreaCtrl2.clear();
              _acresCtrl2.clear();
              _roodsCtrl2.clear();
              _perchesCtrl2.clear();
            });
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Clear All'),
          style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        ),
      ],
    );
  }

  Widget _buildUnitField(
      String label, TextEditingController ctrl, VoidCallback onChanged) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder()),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
