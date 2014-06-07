ZenGen
======

This project provides a [pub transformer](https://www.dartlang.org/tools/pub/glossary.html#transformer) to generate boilerplate code.

This library is inspired from the [project Lombok](http://projectlombok.org) in the Java world.

## Warning ##

Dart file modifications are not **yet** well integrated in the Dart editor.

If you run a web app use `pub serve` and launch dartium with `localhost:8080` instead of _Run in Dartium_ on your original file.

If you run a server app launch the built version of your dart file after a `pub build` instead of _Run_ on your original file.

## Features ##

### @ToString() ###

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

### @EqualsAndHashCode() ###

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

### @Delegate() ###

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

### @Lazy() ###

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

## Usage ##
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

## License ##
Apache 2.0
