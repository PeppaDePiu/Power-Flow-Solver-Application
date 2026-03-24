// lib/domain/powerflow_solver_gs3.dart
import 'dart:math' as math;

import 'complex.dart';
import 'powerflow_model_gs3.dart';

double _toPu({
required double value,
required bool inPu,
required double sBaseMVA,
}) {
return inPu ? value : (value / sBaseMVA);
}

C _enforceMag(C v, double magSpec) {
final angRad = math.atan2(v.im, v.re); // radians
return C.fromPolar(magSpec, angRad * 180.0 / math.pi);
}

// GS3 solver 
GS3Result solveGs3WithWorkings(GS3Inputs ip) {
final maxIterUI = ip.maxIterUI.clamp(1, 500);
final fixedItersUI = ip.fixedItersRequestedUI.clamp(1, 500);
final itersToRun = ip.iterateUntilConverge ? maxIterUI : fixedItersUI;

// Base conversion 
final zBase = (ip.vBaseKV * ip.vBaseKV) / ip.sBaseMVA;
final yBase = 1.0 / zBase;

// Ybus build
C Y11, Y12, Y13, Y21, Y22, Y23, Y31, Y32, Y33;
C y12, y13, y23;
C z12pu, z13pu, z23pu;

if (ip.useDirectYbus) {
Y11 = C(ip.y11Re, ip.y11Im);
Y12 = C(ip.y12Re, ip.y12Im);
Y13 = C(ip.y13Re, ip.y13Im);
Y22 = C(ip.y22Re, ip.y22Im);
Y23 = C(ip.y23Re, ip.y23Im);
Y33 = C(ip.y33Re, ip.y33Im);

Y21 = Y12;
Y31 = Y13;
Y32 = Y23;

y12 = -Y12;
y13 = -Y13;
y23 = -Y23;

C invY(C y) {
if (y.re == 0 && y.im == 0) return C.zero;
return C.one / y;
}

z12pu = invY(y12);
z13pu = invY(y13);
z23pu = invY(y23);
} else {
z12pu = ip.lineDataInPu ? C(ip.r12, ip.x12) : (C(ip.r12, ip.x12) / C(zBase, 0));
z13pu = ip.lineDataInPu ? C(ip.r13, ip.x13) : (C(ip.r13, ip.x13) / C(zBase, 0));
z23pu = ip.lineDataInPu ? C(ip.r23, ip.x23) : (C(ip.r23, ip.x23) / C(zBase, 0));

C invZ(C z) {
if (z.re == 0 && z.im == 0) return C.zero;
return C.one / z;
}

y12 = invZ(z12pu);
y13 = invZ(z13pu);
y23 = invZ(z23pu);

Y12 = -y12;
Y13 = -y13;
Y21 = Y12;
Y31 = Y13;

Y23 = -y23;
Y32 = Y23;

Y11 = y12 + y13;
Y22 = y12 + y23;
Y33 = y13 + y23;
}

final Ybus = <List<C>>[
[Y11, Y12, Y13],
[Y21, Y22, Y23],
[Y31, Y32, Y33],
];

// Powers to pu 
// Bus 1
final Pg1 = _toPu(value: ip.pg1, inPu: ip.bus1PowersInPu, sBaseMVA: ip.sBaseMVA);
final Qg1 = _toPu(value: ip.qg1, inPu: ip.bus1PowersInPu, sBaseMVA: ip.sBaseMVA);
final Pd1 = _toPu(value: ip.pd1, inPu: ip.bus1PowersInPu, sBaseMVA: ip.sBaseMVA);
final Qd1 = _toPu(value: ip.qd1, inPu: ip.bus1PowersInPu, sBaseMVA: ip.sBaseMVA);

// Bus 2
final Pg2 = _toPu(value: ip.pg2, inPu: ip.bus2PowersInPu, sBaseMVA: ip.sBaseMVA);
final Qg2 = _toPu(value: ip.qg2, inPu: ip.bus2PowersInPu, sBaseMVA: ip.sBaseMVA);
final Pd2 = _toPu(value: ip.pd2, inPu: ip.bus2PowersInPu, sBaseMVA: ip.sBaseMVA);
final Qd2 = _toPu(value: ip.qd2, inPu: ip.bus2PowersInPu, sBaseMVA: ip.sBaseMVA);

// Bus 3
final Pg3 = _toPu(value: ip.pg3, inPu: ip.bus3PowersInPu, sBaseMVA: ip.sBaseMVA);
final Qg3 = _toPu(value: ip.qg3, inPu: ip.bus3PowersInPu, sBaseMVA: ip.sBaseMVA);
final Pd3 = _toPu(value: ip.pd3, inPu: ip.bus3PowersInPu, sBaseMVA: ip.sBaseMVA);
final Qd3 = _toPu(value: ip.qd3, inPu: ip.bus3PowersInPu, sBaseMVA: ip.sBaseMVA);

// Loads and generator injections
final Sd1_entered = C(Pd1, Qd1);
final Sd2 = C(Pd2, Qd2);
final Sd3 = C(Pd3, Qd3);

final Sg1_entered = C(Pg1, Qg1);
final Sg2_inj = C(Pg2, Qg2);
final Sg3_inj = C(Pg3, Qg3);

// Net injections (S = Sg - Sd)
final S1_spec = Sg1_entered - Sd1_entered;
final S2_spec = Sg2_inj - Sd2;
final S3_spec = Sg3_inj - Sd3;

// Initial voltages
final V1 = C.fromPolar(ip.v1Mag, ip.d1Deg);
final V2_0_input = C.fromPolar(ip.v2Mag, ip.d2Deg);
final V3_0_input = C.fromPolar(ip.v3Mag, ip.d3Deg);

// Non-slack initial guesses 
var V2k = V2_0_input;
var V3k = V3_0_input;

final V2magSpec = ip.v2Mag;
final V3magSpec = ip.v3Mag;

// PV Q helpers
double q2_fromV(C V2, C V3) {
final sum = (Y21 * V1) + (Y22 * V2) + (Y23 * V3);
final prod = V2.conj() * sum;
return -prod.im; // NET Q2
}

double q3_fromV(C V2, C V3) {
final sum = (Y31 * V1) + (Y32 * V2) + (Y33 * V3);
final prod = V3.conj() * sum;
return -prod.im; // NET Q3
}

double clampQ(double q, double? qmin, double? qmax) {
var qc = q;
if (qmin != null && qc < qmin) qc = qmin;
if (qmax != null && qc > qmax) qc = qmax;
return qc;
}

bool violatesLow(double q, double? qmin) => qmin != null && q < qmin;
bool violatesHigh(double q, double? qmax) => qmax != null && q > qmax;

// Step 3 storage (k=0 worked examples)
final term21_0 = Y21 * V1;
final term22_0 = Y22 * V2_0_input;
final term23_0 = Y23 * V3_0_input;
final sumY2_0 = term21_0 + term22_0 + term23_0;
final prodPV2_0 = V2_0_input.conj() * sumY2_0;

final term31_0 = Y31 * V1;
final term32_0 = Y32 * V2_0_input;
final term33_0 = Y33 * V3_0_input;
final sumY3_0 = term31_0 + term32_0 + term33_0;
final prodPV3_0 = V3_0_input.conj() * sumY3_0;

// PV→PQ drop flags and fixed-Q if dropped
bool bus2DroppedToPQ = false;
bool bus3DroppedToPQ = false;
double? Q2_fixedNet;
double? Q3_fixedNet;

// S used for updates (NET)
C S2_forUpdate = S2_spec;
C S3_forUpdate = S3_spec;

// Step-3 raw net Q at k=0
final double Q2_net_raw_0 = (ip.bus2Type == BusKind.pv) ? (-prodPV2_0.im) : S2_spec.im;
final double Q3_net_raw_0 = (ip.bus3Type == BusKind.pv) ? (-prodPV3_0.im) : S3_spec.im;

// convert to generator-side for limit checking
final double Qg2_raw_0 = (ip.bus2Type == BusKind.pv) ? (Q2_net_raw_0 + Qd2) : Qg2;
final double Qg3_raw_0 = (ip.bus3Type == BusKind.pv) ? (Q3_net_raw_0 + Qd3) : Qg3;

final bool Qg2_low_viol_0 = (ip.bus2Type == BusKind.pv) && violatesLow(Qg2_raw_0, ip.q2Min);
final bool Qg2_high_viol_0 = (ip.bus2Type == BusKind.pv) && violatesHigh(Qg2_raw_0, ip.q2Max);

final bool Qg3_low_viol_0 = (ip.bus3Type == BusKind.pv) && violatesLow(Qg3_raw_0, ip.q3Min);
final bool Qg3_high_viol_0 = (ip.bus3Type == BusKind.pv) && violatesHigh(Qg3_raw_0, ip.q3Max);

final bool Qg2_viol_0 = Qg2_low_viol_0 || Qg2_high_viol_0;
final bool Qg3_viol_0 = Qg3_low_viol_0 || Qg3_high_viol_0;

final double Qg2_used_0 = (ip.bus2Type == BusKind.pv) ? clampQ(Qg2_raw_0, ip.q2Min, ip.q2Max) : Qg2;
final double Qg3_used_0 = (ip.bus3Type == BusKind.pv) ? clampQ(Qg3_raw_0, ip.q3Min, ip.q3Max) : Qg3;

final double Q2_net_used_0 = (ip.bus2Type == BusKind.pv) ? (Qg2_used_0 - Qd2) : S2_spec.im;
final double Q3_net_used_0 = (ip.bus3Type == BusKind.pv) ? (Qg3_used_0 - Qd3) : S3_spec.im;

final Vflat = C.fromPolar(1.0, 0.0);
var V2_0_forGS = V2_0_input;
var V3_0_forGS = V3_0_input;

if (ip.bus2Type == BusKind.pv) {
if ((ip.q2Min != null || ip.q2Max != null) && Qg2_viol_0) {
bus2DroppedToPQ = true;
Q2_fixedNet = Q2_net_used_0;
V2_0_forGS = Vflat;
}
S2_forUpdate = C(S2_spec.re, bus2DroppedToPQ ? Q2_fixedNet! : Q2_net_used_0);
}

if (ip.bus3Type == BusKind.pv) {
if ((ip.q3Min != null || ip.q3Max != null) && Qg3_viol_0) {
bus3DroppedToPQ = true;
Q3_fixedNet = Q3_net_used_0;
V3_0_forGS = Vflat;
}
S3_forUpdate = C(S3_spec.re, bus3DroppedToPQ ? Q3_fixedNet! : Q3_net_used_0);
}

// Snapshots for Step 3 reporting (k=0 only)
final bool bus2DroppedToPQ_0_snapshot = bus2DroppedToPQ;
final bool bus3DroppedToPQ_0_snapshot = bus3DroppedToPQ;

final double? Q2_fixedNet_0_snapshot = Q2_fixedNet;
final double? Q3_fixedNet_0_snapshot = Q3_fixedNet;

final C S2_0_snapshot = C(
S2_spec.re,
(ip.bus2Type == BusKind.pv)
? (bus2DroppedToPQ_0_snapshot
    ? (Q2_fixedNet_0_snapshot ?? Q2_net_used_0)
    : Q2_net_used_0)
: S2_spec.im,
);

final C S3_0_snapshot = C(
S3_spec.re,
(ip.bus3Type == BusKind.pv)
? (bus3DroppedToPQ_0_snapshot
    ? (Q3_fixedNet_0_snapshot ?? Q3_net_used_0)
    : Q3_net_used_0)
: S3_spec.im,
);

// Step 4: GS update k=0→1 intermediates 
final V2k_forGS = V2_0_forGS;
final V3k_forGS = V3_0_forGS;

final partS2overV2 = (S2_forUpdate.conj()) / V2k_forGS.conj();
final rhsV2 = partS2overV2 - (Y21 * V1) - (Y23 * V3k_forGS);
final V2newRaw = rhsV2 / Y22;

final bool bus2IsEffectivePV = (ip.bus2Type == BusKind.pv) && !bus2DroppedToPQ;
final V2new = bus2IsEffectivePV ? _enforceMag(V2newRaw, V2magSpec) : V2newRaw;

final partS3overV3 = (S3_forUpdate.conj()) / V3k_forGS.conj();
final rhsV3 = partS3overV3 - (Y31 * V1) - (Y32 * V2new);
final V3newRaw = rhsV3 / Y33;

final bool bus3IsEffectivePV = (ip.bus3Type == BusKind.pv) && !bus3DroppedToPQ;
final V3new = bus3IsEffectivePV ? _enforceMag(V3newRaw, V3magSpec) : V3newRaw;

// Iteration loop 
final rows = <GS3IterRow>[];
final worked = <GS3WorkedIter>[];

// reset to used initial for GS
V2k = V2_0_forGS;
V3k = V3_0_forGS;

bool converged = false;

for (var k = 1; k <= itersToRun; k++) {
// BUS 2 PV Q update & Qg-limit logic
double Q2k_net_used;
if (ip.bus2Type == BusKind.pv) {
if (!bus2DroppedToPQ) {
final Q2k_net_raw = q2_fromV(V2k, V3k);
final Qg2k_raw = Q2k_net_raw + Qd2;

final violLow = violatesLow(Qg2k_raw, ip.q2Min);
final violHigh = violatesHigh(Qg2k_raw, ip.q2Max);
final viol = (ip.q2Min != null || ip.q2Max != null) && (violLow || violHigh);

final Qg2k_used = clampQ(Qg2k_raw, ip.q2Min, ip.q2Max);
Q2k_net_used = Qg2k_used - Qd2;

if (viol) {
  bus2DroppedToPQ = true;
  Q2_fixedNet = Q2k_net_used;
  V2k = Vflat;
}

S2_forUpdate = C(S2_spec.re, bus2DroppedToPQ ? Q2_fixedNet! : Q2k_net_used);
} else {
Q2k_net_used = Q2_fixedNet!;
S2_forUpdate = C(S2_spec.re, Q2_fixedNet!);
}
} else {
Q2k_net_used = S2_spec.im;
S2_forUpdate = S2_spec;
}

// BUS 3 PV Q update & Qg-limit logic
double Q3k_net_used;
if (ip.bus3Type == BusKind.pv) {
if (!bus3DroppedToPQ) {
final Q3k_net_raw = q3_fromV(V2k, V3k);
final Qg3k_raw = Q3k_net_raw + Qd3;

final violLow = violatesLow(Qg3k_raw, ip.q3Min);
final violHigh = violatesHigh(Qg3k_raw, ip.q3Max);
final viol = (ip.q3Min != null || ip.q3Max != null) && (violLow || violHigh);

final Qg3k_used = clampQ(Qg3k_raw, ip.q3Min, ip.q3Max);
Q3k_net_used = Qg3k_used - Qd3;

if (viol) {
  bus3DroppedToPQ = true;
  Q3_fixedNet = Q3k_net_used;
  V3k = Vflat;
}

S3_forUpdate = C(S3_spec.re, bus3DroppedToPQ ? Q3_fixedNet! : Q3k_net_used);
} else {
Q3k_net_used = Q3_fixedNet!;
S3_forUpdate = C(S3_spec.re, Q3_fixedNet!);
}
} else {
Q3k_net_used = S3_spec.im;
S3_forUpdate = S3_spec;
}
// Voltage updates 
final neigh21_k = (Y21 * V1);
final neigh23_k = (Y23 * V3k);

final partS2overV2_k = (S2_forUpdate.conj()) / V2k.conj();
final rhsV2_k = partS2overV2_k - neigh21_k - neigh23_k;
final V2nextRaw = rhsV2_k / Y22;

final bool bus2PV_eff = (ip.bus2Type == BusKind.pv) && !bus2DroppedToPQ;
final V2next = bus2PV_eff ? _enforceMag(V2nextRaw, V2magSpec) : V2nextRaw;

final neigh31_k = (Y31 * V1);
final neigh32_k = (Y32 * V2next);

final partS3overV3_k = (S3_forUpdate.conj()) / V3k.conj();
final rhsV3_k = partS3overV3_k - neigh31_k - neigh32_k;
final V3nextRaw = rhsV3_k / Y33;

final bool bus3PV_eff = (ip.bus3Type == BusKind.pv) && !bus3DroppedToPQ;
final V3next = bus3PV_eff ? _enforceMag(V3nextRaw, V3magSpec) : V3nextRaw;

final dV2 = (V2next - V2k).abs();
final dV3 = (V3next - V3k).abs();

rows.add(GS3IterRow(
k: k,
Q2: Q2k_net_used,
V2: V2next,
dV2: dV2,
V3: V3next,
dV3: dV3,
));

if (ip.iterateUntilConverge && math.max(dV2, dV3) < ip.tol) {
converged = true;
break;
}

worked.add(GS3WorkedIter(
k: k,
V2k: V2k,
V3k: V3k,
S2: S2_forUpdate,
S3: S3_forUpdate,
partS2overV2: partS2overV2_k,
neigh21: neigh21_k,
neigh23: neigh23_k,
rhsV2: rhsV2_k,
V2nextRaw: V2nextRaw,
V2next: V2next,
partS3overV3: partS3overV3_k,
neigh31: neigh31_k,
neigh32: neigh32_k,
rhsV3: rhsV3_k,
V3nextRaw: V3nextRaw,
V3next: V3next,
));

V2k = V2next;
V3k = V3next;

}

final V2final = V2k;
final V3final = V3k;

// Slack bus net injection
final I1 = (Y11 * V1) + (Y12 * V2final) + (Y13 * V3final);
final S1net = V1 * I1.conj();

// Slack powers at bus 1 if given
late final C Sd1_final;
late final C Sg1_final;

if (ip.slackGiven == SlackGiven.sg1Given) {
Sd1_final = Sg1_entered - S1net;
Sg1_final = Sg1_entered;
} else {
Sd1_final = Sd1_entered;
Sg1_final = S1net + Sd1_final;
}

// Bus 2 final net power + generation
late final C S2netFinal;
if (ip.bus2Type == BusKind.pv) {
if (bus2DroppedToPQ) {
S2netFinal = C(S2_spec.re, Q2_fixedNet ?? (rows.isNotEmpty ? rows.last.Q2 : S2_spec.im));
} else {
final q2net = rows.isNotEmpty ? rows.last.Q2 : Q2_net_used_0;
S2netFinal = C(S2_spec.re, q2net);
}
} else {
S2netFinal = S2_spec;
}
final Sg2 = S2netFinal + Sd2;

// Bus 3 final net power + generation
late final C S3netFinal;
if (ip.bus3Type == BusKind.pv) {
if (bus3DroppedToPQ) {
S3netFinal = C(S3_spec.re, Q3_fixedNet ?? Q3_net_used_0);
} else {
final Q3net_raw_final = q3_fromV(V2final, V3final);
final Qg3_raw_final = Q3net_raw_final + Qd3;
final Qg3_used_final = clampQ(Qg3_raw_final, ip.q3Min, ip.q3Max);
final Q3net_used_final = Qg3_used_final - Qd3;
S3netFinal = C(S3_spec.re, Q3net_used_final);
}
} else {
S3netFinal = S3_spec;
}
final Sg3 = S3netFinal + Sd3;

// Line flows
C Iij(C y, C Vi, C Vj) => y * (Vi - Vj);

final I12 = Iij(y12, V1, V2final);
final I21 = Iij(y12, V2final, V1);
final S12 = V1 * I12.conj();
final S21 = V2final * I21.conj();
final Sloss12 = S12 + S21;

final I13 = Iij(y13, V1, V3final);
final I31 = Iij(y13, V3final, V1);
final S13 = V1 * I13.conj();
final S31 = V3final * I31.conj();
final Sloss13 = S13 + S31;

final I23 = Iij(y23, V2final, V3final);
final I32 = Iij(y23, V3final, V2final);
final S23 = V2final * I23.conj();
final S32 = V3final * I32.conj();
final Sloss23 = S23 + S32;

final SlossTotal = Sloss12 + Sloss13 + Sloss23;

return GS3Result(
sBaseMVA: ip.sBaseMVA,
vBaseKV: ip.vBaseKV,
lineDataInPu: ip.lineDataInPu,
zBase: zBase,
yBase: yBase,
r12: ip.r12,
x12: ip.x12,
r13: ip.r13,
x13: ip.x13,
r23: ip.r23,
x23: ip.x23,
z12pu: z12pu,
z13pu: z13pu,
z23pu: z23pu,
y12: y12,
y13: y13,
y23: y23,
Ybus: Ybus,
Y11: Y11,
Y12: Y12,
Y13: Y13,
Y21: Y21,
Y22: Y22,
Y23: Y23,
Y31: Y31,
Y32: Y32,
Y33: Y33,
bus1Type: ip.bus1Type,
bus2Type: ip.bus2Type,
bus3Type: ip.bus3Type,
slackGiven: ip.slackGiven,
bus1PowersInPu: ip.bus1PowersInPu,
bus2PowersInPu: ip.bus2PowersInPu,
bus3PowersInPu: ip.bus3PowersInPu,
Q1min: ip.q1Min,
Q1max: ip.q1Max,
Q2min: ip.q2Min,
Q2max: ip.q2Max,
Q3min: ip.q3Min,
Q3max: ip.q3Max,
Pg1: Pg1,
Qg1: Qg1,
Pd1: Pd1,
Qd1: Qd1,
Pg2: Pg2,
Qg2: Qg2,
Pd2: Pd2,
Qd2: Qd2,
Pg3: Pg3,
Qg3: Qg3,
Pd3: Pd3,
Qd3: Qd3,
Sd1_entered: Sd1_entered,
Sd2: Sd2,
Sd3: Sd3,
Sg1_entered: Sg1_entered,
S1spec: S1_spec,
S2spec: S2_spec,
S3spec: S3_spec,
V1: V1,
V2_0_input: V2_0_input,
V3_0_input: V3_0_input,
V2_0_forGS: V2_0_forGS,
V3_0_forGS: V3_0_forGS,
term21: term21_0,
term22: term22_0,
term23: term23_0,
sumY2: sumY2_0,
prodPV2_0: prodPV2_0,
Q2_net_raw_0: Q2_net_raw_0,
Qg2_raw_0: Qg2_raw_0,
Qg2_used_0: Qg2_used_0,
Q2_net_used_0: Q2_net_used_0,
Qg2_low_viol_0: Qg2_low_viol_0,
Qg2_high_viol_0: Qg2_high_viol_0,
bus2DroppedToPQ_0: bus2DroppedToPQ_0_snapshot,
S2_0: S2_0_snapshot,
term31: term31_0,
term32: term32_0,
term33: term33_0,
sumY3: sumY3_0,
prodPV3_0: prodPV3_0,
Q3_net_raw_0: Q3_net_raw_0,
Qg3_raw_0: Qg3_raw_0,
Qg3_used_0: Qg3_used_0,
Q3_net_used_0: Q3_net_used_0,
Qg3_low_viol_0: Qg3_low_viol_0,
Qg3_high_viol_0: Qg3_high_viol_0,
bus3DroppedToPQ_0: bus3DroppedToPQ_0_snapshot,
S3_0: S3_0_snapshot,
partS2overV2: partS2overV2,
rhsV2: rhsV2,
V2newRaw: V2newRaw,
V2new: V2new,
partS3overV3: partS3overV3,
rhsV3: rhsV3,
V3newRaw: V3newRaw,
V3new: V3new,
tol: ip.tol,
maxIter: maxIterUI,
iterate: ip.iterateUntilConverge,
fixedItersRequested: fixedItersUI,
converged: converged,
rows: rows,
worked: worked,
V2final: V2final,
V3final: V3final,
I1: I1,
S1net: S1net,
Sd1_final: Sd1_final,
Sg1_final: Sg1_final,
S2netFinal: S2netFinal,
Sg2: Sg2,
S3netFinal: S3netFinal,
Sg3: Sg3,
I12: I12,
S12: S12,
I21: I21,
S21: S21,
Sloss12: Sloss12,
I13: I13,
S13: S13,
I31: I31,
S31: S31,
Sloss13: Sloss13,
I23: I23,
S23: S23,
I32: I32,
S32: S32,
Sloss23: Sloss23,
SlossTotal: SlossTotal,
);
}