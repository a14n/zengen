library zengen.example.equals_and_hashcode;

import 'package:zengen/zengen.dart';

part 'equals_and_hashcode.g.dart';

@EqualsAndHashCode()
class _A {
  final a;
  final int b;
  _A(this.a, this.b);
}
