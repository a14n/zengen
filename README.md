# ZenGen

This project provides a [pub transformer](https://www.dartlang.org/tools/pub/glossary.html#transformer) to generate boilerplate code.

This library is inspired from the [project Lombok](http://projectlombok.org) in the Java world.

## Warning

Dart file modifications are not **yet** well integrated in the Dart editor.

If you run a web app use `pub serve` and launch dartium with `localhost:8080` instead of _Run in Dartium_ on your original file.

If you run a server app launch the built version of your dart file after a `pub build` instead of _Run_ on your original file.

## Features

### @ToString()

Annotating a class with `@ToString()` will generate an implementation of `String toString()` built by default with its public getters.

For instance :

```dart
@ToString()
class A {
  final a;
  final int b;
  A(this.a, this.b);
}
```

will be transformed to :

```dart
@ToString()
class A {
  final a;
  final int b;
  A(this.a, this.b);
  @generated @override String toString() => "A(a=$a, b=$b)";
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
class A {
  final a;
  final int b;
  A(this.a, this.b);
}
```

will be transformed to :

```dart
@EqualsAndHashCode()
class A {
  final a;
  final int b;
  A(this.a, this.b);
  @generated @override int get hashCode => hashObjects([a, b]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.b == b;
}
```

The code generated can be customize with the following optional parameters:

- `callSuper`: if set to `true` the generated code will use additionnally `super.hashCode` and `super == o`.
- `exclude`: a list of getter names can be exclude with this argument.
- `includePrivate`: if set to `true` the generation will include private getters.

### @DefaultConstructor()

Annotating a class with `@DefaultConstructor()` will generate a default constructor with uninitialized final fields as required parameters and mutable fields as optional named parameters.
You can use the `useConst` parameter to generate a _const constructor_.

For instance :

```dart
@DefaultConstructor()
class B {
  var a;
  final b;
}
```

will be transformed to :

```dart
@DefaultConstructor()
class B {
  var a;
  final b;
  @generated B(this.b, {this.a});
}
```

### @Value()

Annotating a class with `@Value()` is the same as annotating the class with `@DefaultConstructor()`, `@EqualsAndHashCode()` and `@ToString()`.

For instance :

```dart
@Value()
class A {
  final int a;
  final b, c;
  final List d;
}
```

will be transformed to :

```dart
@Value()
class A {
  final int a;
  final b, c;
  final List d;
  @generated A(this.a, this.b, this.c, this.d);
  @generated @override String toString() => "A(a=$a, b=$b, c=$c, d=$d)";
  @generated @override int get hashCode => hashObjects([a, b, c, d]);
  @generated @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c && o.d == d;
}
```

Note that you can customize `@EqualsAndHashCode()` and `@ToString()` by using the annotation with the custom parameters.
You can use the `useConst` parameter to generate a _const constructor_.

### @Delegate()

Annotating a field/getter with `@Delegate()` will add to the enclosing class all the public methods available on the type of the field/getter.

For instance :

```dart
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
class B {
  @Delegate() A _a;
}
```

will be transformed to :

```dart
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
class B {
  @Delegate() A _a;
  @generated dynamic m1() => _a.m1();
}
```

The code generated can be customize with the following optional parameters:

- `exclude`: a list of members can be exclude with this argument.

### @Lazy()

Annotating a field with `@Lazy()` will make it lazy computed.

For instance :

```dart
import 'package:zengen/zengen.dart';
class A {
  @Lazy() var a = "String";
}
```

will be transformed to :

```dart
import 'package:zengen/zengen.dart';
class A {
  @generated dynamic get a => _lazyFields.putIfAbsent(#a, () => "String");
  @generated set a(dynamic v) => _lazyFields[#a] = v;
  @generated final _lazyFields = <Symbol, dynamic>{};
}
```

The lazy fields are stored into `_lazyFields` by field names. If the field is _final_ no setter will be generated.

### @Cached()

Annotating a method with `@Cached()` will make its result managed by a cache. By default the cache used is a _forever_ cache that will compute the result once and keep it forever in memory.

For instance :

```dart
import 'package:zengen/zengen.dart';
class A {
  @Cached() int fib(int n) => (n < 2) ? n : fib(n - 1) + fib(n - 2);
}
```

will be transformed to :

```dart
import 'package:zengen/zengen.dart';
class A {
  @generated int fib(int n) => _caches.putIfAbsent(#fib, () => _createCache(#fib, (int n) => (n < 2) ? n : fib(n - 1) + fib(n - 2))).getValue([n]);
  @generated final _caches = <Symbol, Cache> {};
  @generated Cache _createCache(Symbol methodName, Function compute) => new Cache(compute);
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
import 'package:zengen/zengen.dart';
class A {
  m1();
  String get g;
  void set s(String s);
  @Implementation() _noSuchMethod(i) => print(i);
}
```

will be transformed to :

```dart
import 'package:zengen/zengen.dart';
class A {
  @generated dynamic m1() => _noSuchMethod(new StringInvocation('m1', isMethod: true));
  @generated String get g => _noSuchMethod(new StringInvocation('g', isGetter: true));
  @generated void set s(String s) { _noSuchMethod(new StringInvocation('s', isSetter: true, positionalArguments: [s])); }
  @Implementation() _noSuchMethod(i) => print(i);
}
```

## Usage
To use this library in your code :

* add a dependency in your `pubspec.yaml` :

```yaml
dependencies:
  zengen: any
```

* add the transformer in your `pubspec.yaml` :

```yaml
transformers:
- zengen
```

* add import in your `dart` code :

```dart
import 'package:zengen/zengen.dart';
```

## License
Apache 2.0
