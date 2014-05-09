import 'package:zengen/zengen.dart';

@ToString()
class A {
  static var s;
  var a;
  int b;
  A();
  @generated @override String toString() => "A(a=$a, b=$b)";
}

@ToString(callSuper: true)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
  @generated @override String toString() =>
      "B(super=${super.toString()}, c=$c, d=$d)";
}

@ToString(callSuper: false)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
  @generated @override String toString() => "C(c=$c, d=$d)";
}
