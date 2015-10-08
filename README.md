# ZenGen

This project provides a _source_gen_ generator to generate boilerplate code.

This library is inspired from the [project Lombok](http://projectlombok.org) in the Java world.

## Features

### @ToString()

Annotating a class with `@ToString()` will generate an implementation of `String toString()` built by default with its public getters.

For instance :

```dart
@ToString()
class _A {
  final a;
  final int b;
  _A(this.a, this.b);
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  final a;
  final int b;
  A(this.a, this.b);
  @override String toString() => "A(a=$a, b=$b)";
}
```

The code generated can be customized with the following optional parameters:

- `callSuper`: if set to `true` the result of `toString` will contains the result of `super.toString()`.
- `exclude`: a list of getter names can be exclude with this argument.
- `includePrivate`: if set to `true` the generation will include private getters.

### @EqualsAndHashCode()

Annotating a class with `@EqualsAndHashCode()` will generate an implementation of `bool operator ==(o)` and `int get hashCode` built by default with its public getters.

For instance :

```dart
@EqualsAndHashCode()
class _A {
  final a;
  final int b;
  _A(this.a, this.b);
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  final a;
  final int b;
  A(this.a, this.b);
  @override bool operator ==(o) => identical(this, o) ||
      o.runtimeType == runtimeType && o.a == a && o.b == b;
  @override int get hashCode => hashObjects([a, b]);
}
```

The code generated can be customize with the following optional parameters:

- `callSuper`: if set to `true` the generated code will use additionnally `super.hashCode` and `super == o`.
- `exclude`: a list of getter names can be exclude with this argument.
- `includePrivate`: if set to `true` the generation will include private getters.

### @DefaultConstructor()

Annotating an external constructor with `@DefaultConstructor()` will generate a default constructor with uninitialized final fields as required parameters and mutable fields as optional named parameters.
You can use the `useConst` parameter to generate a _const constructor_.

For instance :

```dart
class _A {
  var a;
  final b;
  @DefaultConstructor() external _A();
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  var a;
  final b;
  A(this.b, {this.a});
}
```

The `external _A();` is used to make the analyzer happy and will be removed in the generated `A`.

### @Value()

Annotating a class with `@Value()` is the same as annotating the class with `@DefaultConstructor()`, `@EqualsAndHashCode()` and `@ToString()`.

For instance :

```dart
@Value()
class _A {
  final int a;
  final b, c;
  external _A();
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  final int a;
  final b, c;
  A(this.a, this.b, this.c);
  @override bool operator ==(o) => identical(this, o) ||
      o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c;
  @override int get hashCode => hashObjects([a, b, c]);
  @override String toString() => "A(a=$a, b=$b, c=$c)";
}
```

Note that you can customize `@EqualsAndHashCode()` and `@ToString()` by using the annotation with the custom parameters.
You can use the `useConst` parameter to generate a _const constructor_.

### @Delegate()

Annotating a field/getter with `@Delegate()` will add to the enclosing class all the public methods available on the type of the field/getter.

For instance :

```dart
abstract class A {
  m1();
}
class _B {
  @Delegate() A _a;
}
```

will generate :

```dart
@GeneratedFrom(_B)
class B {
  @Delegate() A _a;
  m1() => _a.m1();
}
```

The code generated can be customize with the following optional parameters:

- `exclude`: a list of members can be exclude with this argument.

### @Lazy()

Annotating a field with `@Lazy()` will make it lazy computed.

For instance :

```dart
class _A {
  @Lazy() var a = "String";
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  dynamic get a => _lazyFields.putIfAbsent(#a, () => "String");
  set a(dynamic v) => _lazyFields[#a] = v;
  final _lazyFields = <Symbol, dynamic>{};
}
```

The lazy fields are stored into `_lazyFields` by field names. If the field is _final_ no setter will be generated.

### @Cached()

Annotating a method with `@Cached()` will make its result managed by a cache. By default the cache used is a _forever_ cache that will compute the result once and keep it forever in memory.

For instance :

```dart
class _A {
  @Cached() int fib(int n) => (n < 2) ? n : fib(n - 1) + fib(n - 2);
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  int fib(int n) => _caches
      .putIfAbsent(
          #fib,
          () => _createCache(
              #fib, (int n) => (n < 2) ? n : fib(n - 1) + fib(n - 2)))
      .getValue([n]);
  final _caches = <Symbol, Cache>{};
  Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
}
```

The caches for each method are stored into `_caches`. You can implement your own `Cache _createCache(Symbol methodName, Function compute)` to customize the cache policy.

### @Implementation()

Annotating a method with `@Implementation()` will make it the method called by all abstract members.
The method annotated must have exactly one parameter of type `StringInvocation`.
This type is the same as `Invocation` from _dart:core_ except that the `Symbol` are replaced by `String`.
This allows to avoid _dart:mirrors_.

For instance :

```dart
abstract class _A {
  m1();
  String get g;
  void set s(String s);
  @Implementation() _noSuchMethod(i) => print(i);
}
```

will generate :

```dart
@GeneratedFrom(_A)
class A {
  m1() => _noSuchMethod(new StringInvocation('m1', isMethod: true));
  String get g => _noSuchMethod(new StringInvocation('g', isGetter: true));
  void set s(String s) {
    _noSuchMethod(
        new StringInvocation('s', isSetter: true, positionalArguments: [s]));
  }

  _noSuchMethod(i) => print(i);
}
```

## Usage
To use this library in your code :

* add a dependency in your `pubspec.yaml` :

```yaml
dependencies:
  zengen: any
```

* add import in your `dart` code :

```dart
import 'package:zengen/zengen.dart';
```

* create a script `build.dart` that run the generator

```dart
import 'package:zengen/generator.dart';
import 'package:source_gen/source_gen.dart' show build;

main(List<String> args) async {
  print(await build(args, [new ZengenGenerator()],
      librarySearchPaths: ['example/', 'lib/', 'web/', 'test/']));
}
```

You can use the [build_system package](https://pub.dartlang.org/packages/build_system) to
allow the generator to be run on every file changes.

## License
Apache 2.0
