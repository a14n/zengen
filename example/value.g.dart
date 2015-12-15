// GENERATED CODE - DO NOT MODIFY BY HAND

part of zengen.example.value;

// **************************************************************************
// Generator: ZengenGenerator
// Target: library zengen.example.value
// **************************************************************************

@GeneratedFrom(_A)
class A {
  final int a;
  final b, c;
  A(this.a, this.b, this.c);
  @override String toString() => "A(a=$a, b=$b, c=$c)";
  @override int get hashCode => hashObjects([a, b, c]);
  @override bool operator ==(o) =>
      identical(this, o) ||
      o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c;
}

@GeneratedFrom(_B)
class B {
  final int a;
  final b, c;
  const B(this.a, this.b, this.c);
  @override String toString() => "B(a=$a, b=$b, c=$c)";
  @override int get hashCode => hashObjects([a, b, c]);
  @override bool operator ==(o) =>
      identical(this, o) ||
      o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c;
}

@GeneratedFrom(_C)
class C {
  final int a;
  final b, c;
  const C(this.a, this.b, this.c);
  @override String toString() =>
      "C(super=${super.toString()}, a=$a, b=$b, c=$c)";
  @override int get hashCode => hashObjects([a, b, c]);
  @override bool operator ==(o) =>
      identical(this, o) ||
      o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c;
}
