library zengen_generator.example.default_constructor;

import 'package:zengen/zengen.dart';

part 'default_constructor.g.dart';

class _A {
  var a;
  final b;
  @DefaultConstructor() external _A();
  @DefaultConstructor() external _A.bis();
}
