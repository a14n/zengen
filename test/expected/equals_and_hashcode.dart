import 'package:zengen/zengen.dart';

@EqualsAndHashCode()
class A {
  static var s;
  final a;
  final int b;
  A(this.a, this.b);
  @generated @override int get hashCode => hashObjects([a, b]);
  @generated @override bool operator ==(o) => o is A && o.a == a && o.b == b;
}