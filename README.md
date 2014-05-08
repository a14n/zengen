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

Annotating a class with `@ToString()` will generate an implementation of `String toString()`.

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

### @EqualsAndHashCode() ###

Annotating a class with `@EqualsAndHashCode()` will generate an implementation of `bool operator ==(o)` and `int get hashCode`.

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
  @generated @override bool operator ==(o) => o is A && o.a == a && o.b == b;
}
```

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
