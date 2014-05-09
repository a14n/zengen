import 'package:zengen/zengen.dart';

@EqualsAndHashCode()
class A {
  static var s;
  var a;
  int b;
  A();
}

@EqualsAndHashCode(callSuper: true)
class B extends A {
  static var s;
  final c;
  final String d;
  B(this.c, this.d);
}

@EqualsAndHashCode(callSuper: false)
class C extends A {
  static var s;
  final c;
  final String d;
  C(this.c, this.d);
}
