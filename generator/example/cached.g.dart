// GENERATED CODE - DO NOT MODIFY BY HAND

part of zengen_generator.example.delegate;

// **************************************************************************
// Generator: ZengenGenerator
// Target: library zengen_generator.example.delegate
// **************************************************************************

@GeneratedFrom(_A)
class A {
  int fib(int n) => _caches
      .putIfAbsent(
          #fib,
          () => _createCache(
              #fib, (int n) => (n < 2) ? n : fib(n - 1) + fib(n - 2)))
      .getValue([n]) as int;
  Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
  final _caches = <Symbol, Cache>{};
}
