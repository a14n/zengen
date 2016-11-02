library zengen_generator.example.delegate;

import 'package:zengen/zengen.dart';

part 'implementation.g.dart';

abstract class _A {
  m1();
  String get g;
  void set s(String s);
  @Implementation() _noSuchMethod(i) => print(i);
}
