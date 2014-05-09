import 'package:zengen/zengen.dart';

@EqualsAndHashCode()
class A {
  static var s;
  var a;
  int b;
  A();
  @generated @override int get hashCode => hashObjects([a, b]);
  @generated @override bool operator ==(o) => o is A && o.a == a && o.b == b;
}

@EqualsAndHashCode(callSuper: true)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
  @generated @override int get hashCode => hashObjects([super.hashCode, c, d]);
  @generated @override bool operator ==(o) => o is B && super == o && o.c == c
      && o.d == d;
}

@EqualsAndHashCode(callSuper: false)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
  @generated @override int get hashCode => hashObjects([c, d]);
  @generated @override bool operator ==(o) => o is C && o.c == c && o.d == d;
}

@EqualsAndHashCode(exclude: const ['b', 'd'])
class D {
  static var s;
  var a;
  int b;
  String c, d;
  D();
  @generated @override int get hashCode => hashObjects([a, c]);
  @generated @override bool operator ==(o) => o is D && o.a == a && o.c == c;
}