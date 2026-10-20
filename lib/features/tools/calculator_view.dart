import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class SimpleCalculator extends StatefulWidget {
  const SimpleCalculator({super.key});

  @override
  State<SimpleCalculator> createState() => _SimpleCalculatorState();
}

class _SimpleCalculatorState extends State<SimpleCalculator> {
  String _equation = "";
  String _result = "0";
  String _expression = "";
  final double _equationFontSize = 38.0;
  final double _resultFontSize = 48.0;

  final List<String> _history = [];

  void _buttonPressed(String buttonText) {
    setState(() {
      if (buttonText == "C") {
        _equation = "";
        _result = "0";
      } else if (buttonText == "⌫") {
        if (_equation.isNotEmpty) {
          _equation = _equation.substring(0, _equation.length - 1);
        }
      } else if (buttonText == "=") {
        _expression = _equation;
        _expression = _expression.replaceAll('×', '*');
        _expression = _expression.replaceAll('÷', '/');

        try {
          GrammarParser p = GrammarParser();
          Expression exp = p.parse(_expression);

          ContextModel cm = ContextModel();
          // ignore: deprecated_member_use
          double eval = exp.evaluate(EvaluationType.REAL, cm);

          if (eval % 1 == 0) {
            _result = eval.toInt().toString();
          } else {
            _result = eval.toString();
          }

          _history.add("$_equation = $_result");
        } catch (e) {
          _result = "Error";
        }
      } else {
        if (_equation == "0") {
          _equation = buttonText;
        } else {
          _equation = _equation + buttonText;
        }
      }
    });
  }

  Widget _buildButton(
      String buttonText, double height, Color buttonColor, Color textColor,
      {bool isEquals = false}) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.1 * height,
      color: Colors.transparent,
      margin: const EdgeInsets.all(5),
      child: LayoutBuilder(builder: (ctx, constraints) {
        return ElevatedButton(
          onPressed: () => _buttonPressed(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            elevation: 2,
            shape: isEquals
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20))
                : const CircleBorder(),
            padding: const EdgeInsets.all(16.0),
          ),
          child: Text(
            buttonText,
            style: TextStyle(
                fontSize: 30.0,
                fontWeight: FontWeight.normal,
                color: textColor),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // App Colors
    const Color primaryRed = Color(0xFFD32F2F);
    const Color bgWhite = Colors.white;
    const Color textBlack = Colors.black87;
    final Color btnGrey = Colors.grey[200]!;
    const Color btnTextGreu = Colors.black;

    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: const Text('Survey Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  builder: (ctx) => ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (c, i) => ListTile(
                          title: Text(_history[i],
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 18)),
                        ),
                      ));
            },
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: <Widget>[
              // Display Area
              Expanded(
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _equation,
                        style: TextStyle(
                            fontSize: _equationFontSize, color: textBlack),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _result,
                        style: TextStyle(
                            fontSize: _resultFontSize, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(color: Colors.grey),

              // Buttons
              // Operators: Primary Red. Numbers: White/Grey. Utility: Red/Grey.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildButton("C", 1, primaryRed, Colors.white),
                  _buildButton("%", 1, btnGrey, primaryRed),
                  _buildButton("⌫", 1, btnGrey, primaryRed),
                  _buildButton("÷", 1, btnGrey, primaryRed),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildButton("7", 1, Colors.white, btnTextGreu),
                  _buildButton("8", 1, Colors.white, btnTextGreu),
                  _buildButton("9", 1, Colors.white, btnTextGreu),
                  _buildButton("×", 1, btnGrey, primaryRed),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildButton("4", 1, Colors.white, btnTextGreu),
                  _buildButton("5", 1, Colors.white, btnTextGreu),
                  _buildButton("6", 1, Colors.white, btnTextGreu),
                  _buildButton("-", 1, btnGrey, primaryRed),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildButton("1", 1, Colors.white, btnTextGreu),
                  _buildButton("2", 1, Colors.white, btnTextGreu),
                  _buildButton("3", 1, Colors.white, btnTextGreu),
                  _buildButton("+", 1, btnGrey, primaryRed),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildButton("00", 1, Colors.white, btnTextGreu),
                  _buildButton("0", 1, Colors.white, btnTextGreu),
                  _buildButton(".", 1, Colors.white, btnTextGreu),
                  // Special Equals Button
                  Container(
                    height: MediaQuery.of(context).size.height * 0.1,
                    width: MediaQuery.of(context).size.width * 0.22,
                    margin: const EdgeInsets.all(5),
                    child: ElevatedButton(
                      onPressed: () => _buttonPressed("="),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed, // Primary Red
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text("=",
                          style: TextStyle(fontSize: 30, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }
}
