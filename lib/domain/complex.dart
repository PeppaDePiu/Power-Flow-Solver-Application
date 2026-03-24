// lib/domain/complex.dart
import 'dart:math' as math;

/// Complex number class for power flow calculations
class C {
final double re, im;

static final C zero = C(0, 0);

static final C one = C(1, 0);

final double mag;

final double ang;
C(this.re, this.im)
: mag = math.sqrt(re * re + im * im),
ang = math.atan2(im, re) * 180 / math.pi;

C operator +(C o) => C(re + o.re, im + o.im);
C operator -(C o) => C(re - o.re, im - o.im);
C operator *(C o) => C(re * o.re - im * o.im, re * o.im + im * o.re);
C operator /(C o) {
final d = o.re * o.re + o.im * o.im;
return C((re * o.re + im * o.im) / d, (im * o.re - re * o.im) / d);
}

C conj() => C(re, -im);
double abs() => mag;
double angDeg() => ang;

static C fromPolar(double mag, double deg) {
final a = deg * math.pi / 180;
return C(mag * math.cos(a), mag * math.sin(a));
}

@override
String toString() => '($re, $im)';
}
