import 'package:zengen/zengen.dart';

@ToString()
class A {
  static var s;
  final a;
  final int b;
  A(this.a, this.b);
  @generated @override String toString() => "A(a=$a, b=$b)";
}