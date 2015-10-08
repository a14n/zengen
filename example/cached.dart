library zengen.example.delegate;

import 'package:zengen/zengen.dart';

part 'cached.g.dart';

class _A {
  @Cached() int fib(int n) => (n < 2) ? n : fib(n - 1) + fib(n - 2);
}
