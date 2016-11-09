// Copyright (c) 2014, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library zengen.value;

import 'src/transformation.dart';

main() {
  testTransformation(
      '@Value() should create a constructor and hash/equals + toString',
      r'''
@Value()
class _A {
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  A();
  @override String toString() => "A()";
  @override int get hashCode => hashObjects([]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType;
}
''');

  testTransformation(
      '@Value() should create a const constructor and hash/equals + toString',
      r'''
@Value(useConst: true)
class _A {
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  const A();
  @override String toString() => "A()";
  @override int get hashCode => hashObjects([]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType;
}
''');

  testTransformation(
      '@Value() should create a constructor with named optional parameters',
      r'''
@Value()
class _A {
  final int a;
  final b, c;
  final List d;
  external _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  final int a;
  final b, c;
  final List d;
  A(this.a, this.b, this.c, this.d);
  @override String toString() => "A(a=$a, b=$b, c=$c, d=$d)";
  @override int get hashCode => hashObjects([a, b, c, d]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.a == a && o.b == b && o.c == c && o.d == d;
}
''');

  testTransformation(
      '@Value() should be customized with @EqualsAndHashCode',
      r'''
@EqualsAndHashCode(exclude: const[#a])
@Value()
class _A {
  final int a, b;
  external _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  final int a, b;
  @override int get hashCode => hashObjects([b]);
  @override bool operator ==(o) => identical(this, o) || o.runtimeType == runtimeType && o.b == b;
  A(this.a, this.b);
  @override String toString() => "A(a=$a, b=$b)";
}
''', skip: true);
}
