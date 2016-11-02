library zengen_generator.example.to_string;

import 'package:zengen/zengen.dart';

part 'to_string.g.dart';

@ToString()
class _A {
  final a;
  final int b;
  _A(this.a, this.b);
}

@ToString(/*exclude:const<Symbol>[#a]*/)
class _B {
  final a;
  final int b;
  _B(this.a, this.b);
}
