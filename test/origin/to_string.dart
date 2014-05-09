import 'package:zengen/zengen.dart';

@ToString()
class A {
  static var s;
  var a;
  int b;
  A();
}

@ToString(callSuper: true)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
}

@ToString(callSuper: false)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
}

@ToString(exclude: const ['b', 'd'])
class D {
  static var s;
  var a;
  int b;
  String c, d;
  D();
}