import 'dart:math' as math;
import '/domain/complex.dart';

/// Format a number with significant figures
String sig(num x, [int s = 4]) {
  if (x == 0) return '0';
  final ax = x.abs();
  final k = (math.log(ax) / math.ln10).floor();
  final digits = (s - 1 - k).clamp(0, 12).toInt();
  final factor = math.pow(10, digits).toDouble();
  final rounded = (x * factor).round() / factor;
  var str = rounded.toStringAsFixed(digits);
  if (str.contains('.')) {
    str = str.replaceFirst(RegExp(r'0+$'), '');
    str = str.replaceFirst(RegExp(r'\.$'), '');
  }
  return str;
}

/// Rectangular form a + j b
String rectPretty(C z) {
  const eps = 1e-12;
  final ar = z.re.abs() < eps ? 0.0 : z.re;
  final ai = z.im.abs() < eps ? 0.0 : z.im;

  if (ar == 0.0 && ai == 0.0) return '0';
  if (ar == 0.0) return ai > 0 ? 'j${sig(ai)}' : '-j${sig(-ai)}';
  if (ai == 0.0) return sig(ar);

  final op = ai > 0 ? '+' : '-';
  return '${sig(ar)} $op j${sig(ai.abs())}';
}

/// Polar form 
String polarPretty(C z) => '${sig(z.abs())}\\angle ${sig(z.angDeg())}^{\\circ}';

/// Ybus matrix in rect form (for LaTeX)
String matRect(List<List<C>> m) {
  final rows =
      m.map((row) => row.map(rectPretty).join(r' & ')).join(r' \\ ');
  return r'\begin{bmatrix}' + rows + r'\end{bmatrix}';
}

/// Ybus matrix in polar form (for LaTeX)
String matPolar(List<List<C>> m) {
  final rows = m
      .map((row) => row
          .map((z) => '${sig(z.abs())}\\angle ${sig(z.angDeg())}^{\\circ}')
          .join(r' & '))
      .join(r' \\ ');
  return r'\begin{bmatrix}' + rows + r'\end{bmatrix}';
}
