// lib/domain/powerflow_model_nr2.dart
import 'dart:math' as math;
import 'complex.dart';

enum BusType { slack, pq, pv }
enum Bus1Given { none, sg1, sd1 }

// Quick Fill Preset model 
class NR2Preset {
final String name;

// toggles
final bool lineDataInPu;
final bool bus1PowerInPu;
final bool bus2PowerInPu;
final bool iterateUntilConverge;

// dropdowns
final BusType bus1Type; // slack
final BusType bus2Type; // pq or pv
final Bus1Given bus1Given;

// text fields 
final String sBase;
final String vBase;
final String r12;
final String x12;
final String yp;

// bus 1 
final String v1Mag;
final String d1;

final String pg1;
final String qg1;
final String pd1;
final String qd1;

// bus 2 (PQ/PV)
final String v2Mag;
final String d2;

final String pg2;
final String qg2;
final String pd2;
final String qd2;

// PV Qg limits (generator-side)
final String qg2Min;
final String qg2Max;

// iteration controls
final String tol;
final String maxIter;
final String kTimes;

const NR2Preset({
required this.name,
required this.lineDataInPu,
required this.bus1PowerInPu,
required this.bus2PowerInPu,
required this.iterateUntilConverge,
required this.bus1Type,
required this.bus2Type,
required this.bus1Given,
required this.sBase,
required this.vBase,
required this.r12,
required this.x12,
required this.yp,
required this.v1Mag,
required this.d1,
required this.pg1,
required this.qg1,
required this.pd1,
required this.qd1,
required this.v2Mag,
required this.d2,
required this.pg2,
required this.qg2,
required this.pd2,
required this.qd2,
required this.qg2Min,
required this.qg2Max,
required this.tol,
required this.maxIter,
required this.kTimes,
});
}

// Presets list 
final List<NR2Preset> nr2Presets = [
const NR2Preset(
name: 'Custom (Set all to Zero by Default)',
lineDataInPu: false,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: true,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '100',
vBase: '230',
r12: '20',
x12: '80',
yp: '0.00027',
v1Mag: '1.0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '1.0',
d2: '0',
pg2: '0',
qg2: '0',
pd2: '1.0',
qd2: '1.0',
qg2Min: '',
qg2Max: '',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
const NR2Preset(
name: 'Lecture Notes Page 66, 2 Bus NR with Shunt Charging Admittance',
lineDataInPu: false,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: false,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '100',
vBase: '230',
r12: '20',
x12: '80',
yp: '0.00027',
v1Mag: '1.0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '1.0',
d2: '0',
pg2: '0',
qg2: '0',
pd2: '1.0',
qd2: '1.0',
qg2Min: '',
qg2Max: '',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
const NR2Preset(
name: 'Tutorial 2 Qn 2, 2 Bus NR with Slack Bus Powers and Line Losses',
lineDataInPu: true,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: true,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '100',
vBase: '230',
r12: '0.01',
x12: '0.03',
yp: '0',
v1Mag: '1.0',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '1.0',
d2: '0',
pg2: '0',
qg2: '0',
pd2: '2.0',
qd2: '2.0',
qg2Min: '',
qg2Max: '',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
const NR2Preset(
name: 'PYP 2023-2024 Qn1, 2 Bus NR with additional Qg2 injected at Bus 2',
lineDataInPu: true,
bus1PowerInPu: true,
bus2PowerInPu: true,
iterateUntilConverge: true,
bus1Type: BusType.slack,
bus2Type: BusType.pq,
bus1Given: Bus1Given.none,
sBase: '100',
vBase: '230',
r12: '0.01',
x12: '0.03',
yp: '0',
v1Mag: '1.05',
d1: '0',
pg1: '0',
qg1: '0',
pd1: '0',
qd1: '0',
v2Mag: '1',
d2: '0',
pg2: '0',
qg2: '0.5',
pd2: '2',
qd2: '2.5',
qg2Min: '',
qg2Max: '',
tol: '1e-4',
maxIter: '50',
kTimes: '2',
),
];

// Numeric input bundle passed to the solver 
class NR2Inputs {
// config
final bool lineDataInPu;
final bool bus1PowerInPu;
final bool bus2PowerInPu;
final bool iterateUntilConverge;
final int kTimesUI;

final BusType bus2Type; // pq or pv
final Bus1Given bus1Given;

// base / line
final double sBaseMVA;
final double vBaseKV;
final double r12;
final double x12;
final double ypImag;

// bus 1 voltage
final double v1Mag;
final double d1Deg;

// bus 1 given powers (optional)
final double pg1;
final double qg1;
final double pd1;
final double qd1;

// bus 2 voltage initial/specified
final double v2Mag;
final double d2Deg;

// bus 2 powers 
final double pg2;
final double qg2;
final double pd2;
final double qd2;

// PV Qg limits (generator-side)
final double? qg2Min;
final double? qg2Max;

// iteration
final double tol;
final int maxIterUI;

const NR2Inputs({
required this.lineDataInPu,
required this.bus1PowerInPu,
required this.bus2PowerInPu,
required this.iterateUntilConverge,
required this.kTimesUI,
required this.bus2Type,
required this.bus1Given,
required this.sBaseMVA,
required this.vBaseKV,
required this.r12,
required this.x12,
required this.ypImag,
required this.v1Mag,
required this.d1Deg,
required this.pg1,
required this.qg1,
required this.pd1,
required this.qd1,
required this.v2Mag,
required this.d2Deg,
required this.pg2,
required this.qg2,
required this.pd2,
required this.qd2,
required this.qg2Min,
required this.qg2Max,
required this.tol,
required this.maxIterUI,
});
}

// Iteration row 
class NR2IterRow {
final int k;

final double d2Rad; // state angle
final double v2Mag; // state magnitude

final double p2Calc;
final double q2Calc;

final double misP;
final double misQ;

final double dDelta; // update in rad
final double dV; // update in pu

final bool pvEnforced;
final bool droppedToPQ;
final bool droppedThisIter;

const NR2IterRow({
required this.k,
required this.d2Rad,
required this.v2Mag,
required this.p2Calc,
required this.q2Calc,
required this.misP,
required this.misQ,
required this.dDelta,
required this.dV,
required this.pvEnforced,
required this.droppedToPQ,
required this.droppedThisIter,
});
}

/// Full workings result 
class NR2Result {
// configuration
final BusType bus2Type;
final Bus1Given bus1Given;
final bool iterateUntilConverge;
final int kTimes;

// inputs 
final double sBaseMVA;
final double vBaseKV;
final double r12;
final double x12;
final double ypImag;
final bool dataInPu;
final double tol;
final int maxIter;

// bases
final double zBase;
final double yBase;

// pu values
final C z12Pu;
final C ypPu;

// admittances
final C y12Series;
final C yShunt;

// Ybus
final C Y11, Y22, Y12, Y21;

// voltages
final C V1;
final C V20_user; // user/specified initial
final C V20_used; // used by solver (flat start if PV dropped at k=0)
final double V2spec;

// bus 2 powers 
final C Sg2_in;
final C Sd2;
final C S2_userPQ;
final double P2spec;
final double Q2spec_user;

// PV limits
final double? qg2min;
final double? qg2max;

// PV worked example k=0 
final C term21_0, term22_0, sumY2_0, prodPV2_0;
final double q2Raw_0;
final double qg2Raw_0;
final bool qg2LowViol_0;
final bool qg2HighViol_0;
final double qg2Used_0;
final double q2Used_0;
final bool pvDroppedToPQ_at0;

// NR iteration
final List<NR2IterRow> rows;
final bool converged;

final bool droppedToPQ; // includes drop at 0 or later
final double? Q2fixedFromLimit;

final C V2final;

// slack power
final C I1;
final C S1;

// flows
final C I12, S12, I21, S21, Sloss;

// bus 1 Given + Derived
final C Sg1_given;
final C Sd1_given;
final C Sg1_required_from_Sd1;
final C Sd1_required_from_Sg1;

const NR2Result({
required this.bus2Type,
required this.bus1Given,
required this.iterateUntilConverge,
required this.kTimes,
required this.sBaseMVA,
required this.vBaseKV,
required this.r12,
required this.x12,
required this.ypImag,
required this.dataInPu,
required this.tol,
required this.maxIter,
required this.zBase,
required this.yBase,
required this.z12Pu,
required this.ypPu,
required this.y12Series,
required this.yShunt,
required this.Y11,
required this.Y22,
required this.Y12,
required this.Y21,
required this.V1,
required this.V20_user,
required this.V20_used,
required this.V2spec,
required this.Sg2_in,
required this.Sd2,
required this.S2_userPQ,
required this.P2spec,
required this.Q2spec_user,
required this.qg2min,
required this.qg2max,
required this.term21_0,
required this.term22_0,
required this.sumY2_0,
required this.prodPV2_0,
required this.q2Raw_0,
required this.qg2Raw_0,
required this.qg2LowViol_0,
required this.qg2HighViol_0,
required this.qg2Used_0,
required this.q2Used_0,
required this.pvDroppedToPQ_at0,
required this.rows,
required this.converged,
required this.droppedToPQ,
required this.Q2fixedFromLimit,
required this.V2final,
required this.I1,
required this.S1,
required this.I12,
required this.S12,
required this.I21,
required this.S21,
required this.Sloss,
required this.Sg1_given,
required this.Sd1_given,
required this.Sg1_required_from_Sd1,
required this.Sd1_required_from_Sg1,
});
}

// Helper extension for complex-number operations 
extension CMathCompatNR on C {
double abs() => math.sqrt(re * re + im * im);
double angDeg() => math.atan2(im, re) * 180.0 / math.pi;
}