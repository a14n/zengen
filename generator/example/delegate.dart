library zengen_generator.example.delegate;

import 'dart:math';

import 'package:zengen/zengen.dart';

part 'delegate.g.dart';

abstract class A<T> {
  T m1();
}
class _B {
  @Delegate() A<int> _a;
}
class _C {
  @Delegate() List<String> _l;
}
