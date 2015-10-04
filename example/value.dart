library zengen.example.value;

import 'package:zengen/zengen.dart';

part 'value.g.dart';

@Value()
class _A {
  final int a;
  final b, c;
  external _A();
}

@Value(useConst: true)
class _B {
  final int a;
  final b, c;
  external _B();
}

@Value(useConst: true)
@ToString(callSuper: true)
class _C {
  final int a;
  final b, c;
  external _C();
}
