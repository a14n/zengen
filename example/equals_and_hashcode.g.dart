// GENERATED CODE - DO NOT MODIFY BY HAND
// 2015-10-02T15:54:30.067Z

part of zengen.example.equals_and_hashcode;

// **************************************************************************
// Generator: ZengenGenerator
// Target: library zengen.example.equals_and_hashcode
// **************************************************************************

@GeneratedFrom(_A)
class A {
  final a;
  final int b;
  A(this.a, this.b);
  @override bool operator ==(o) => identical(this, o) ||
      o.runtimeType == runtimeType && o.a == a && o.b == b;
  @override int get hashCode => hashObjects([a, b]);
}
