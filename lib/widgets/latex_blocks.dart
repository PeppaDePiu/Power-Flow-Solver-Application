import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' as fm;

double _responsiveLatexSize(BuildContext context, double base) {
final w = MediaQuery.of(context).size.width;
if (w < 380) return base * 0.78;
if (w < 450) return base * 0.84;
if (w < 600) return base * 0.90;
if (w < 900) return base * 0.96;
return base;
}

/// Multi-line aligned LaTeX block (for derivations)
Widget latexBlock(List<String> lines, {double size = 18}) => Builder(
builder: (context) {
final responsiveSize = _responsiveLatexSize(context, size);
return Align(
alignment: Alignment.centerLeft,
child: SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: fm.Math.tex(
r'\begin{aligned}' + lines.join(r'\\') + r'\end{aligned}',
textStyle: TextStyle(fontSize: responsiveSize, height: 1.35),
),
),
);
},
);

/// Single-column, flush-left LaTeX block (for lists of steps)
Widget latexLeft(List<String> lines, {double size = 18}) => Builder(
builder: (context) {
final responsiveSize = _responsiveLatexSize(context, size);
return Align(
alignment: Alignment.centerLeft,
child: SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: fm.Math.tex(
r'\begin{array}{l}' + lines.join(r'\\[4pt]') + r'\end{array}',
textStyle: TextStyle(fontSize: responsiveSize, height: 1.35),
),
),
);
},
);