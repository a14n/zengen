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

library zengen.delegate;

import 'src/transformation.dart';

main() {
  testTransformation(
      '@Delegate() should create delagating methods',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m1() => _a.m1();
}
''');

  testTransformation(
      '@Delegate() should work when used on a getter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
class _B {
  @Delegate() A get _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A get _a;
  dynamic m1() => _a.m1();
}
''');

  testTransformation(
      '@Delegate() should work setters and getters are mixed',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  get a;
  set b(v);
}
class _B {
  @Delegate() A _a;
  set a(v) => null;
  get b => null;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  set a(v) => null;
  get b => null;
  set b(dynamic v) { _a.b = v; }
  dynamic get a => _a.a;
}
''');

  testTransformation(
      '@Delegate() should handle parameter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(a, int b);
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m1(dynamic a, int b) => _a.m1(a, b);
}
''');

  testTransformation(
      '@Delegate() should handle optional positionnal parameter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, [int b = 1, c]);
  m2([int b = 1, c]);
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m2([int b = 1, dynamic c]) => _a.m2(b, c);
  dynamic m1(String a, [int b = 1, dynamic c]) => _a.m1(a, b, c);
}
''');

  testTransformation(
      '@Delegate() should handle optional named parameter',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, {int b, c});
  m2({int b, c});
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m2({int b, dynamic c}) => _a.m2(b: b, c: c);
  dynamic m1(String a, {int b, dynamic c}) => _a.m1(a, b: b, c: c);
}
''');

  testTransformation(
      '@Delegate(exclude: const[#b]) should not create m1',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(String a, {int b, c});
  m2({int b, c});
}
class _B {
  @Delegate(exclude: const[#m1]) A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m2({int b, dynamic c}) => _a.m2(b: b, c: c);
}
''',
      skip: true);

  testTransformation(
      '@Delegate() should handle simple generics',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<E> {
  E m1(E e);
}
class _B<E> {
  @Delegate() A<E> _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B<E> implements A<E> {
  A<E> _a;
  E m1(E e) => _a.m1(e);
}
''');

  testTransformation(
      '@Delegate() should handle generics substitution',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<E> {
  E m1(E e);
}
class _B {
  @Delegate() A<String> _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A<String> {
  A<String> _a;
  String m1(String e) => _a.m1(e);
}
''');

  testTransformation(
      '@Delegate() should handle generics substitution in generic types',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<E> {
  Iterable<E> m1(E e);
  Iterable<Iterable<E>> m2(Iterable<E> e);
  Iterable<Iterable<Iterable<E>>> m3(Iterable<Iterable<E>> e);
}
class _B {
  @Delegate() A<String> _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A<String> {
  A<String> _a;
  Iterable<Iterable<Iterable<String>>> m3(Iterable<Iterable<String>> e) => _a.m3(e);
  Iterable<Iterable<String>> m2(Iterable<String> e) => _a.m2(e);
  Iterable<String> m1(String e) => _a.m1(e);
}
''');

  testTransformation(
      '@Delegate() should handle generics functions',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<E> {
  m1(Iterable<E> f(Iterable<E> p1, E p2));
}
class _B {
  @Delegate() A<String> _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A<String> {
  A<String> _a;
  dynamic m1(Iterable<String> f(Iterable<String> p1, String p2)) => _a.m1(f);
}
''');

  testTransformation(
      '@Delegate() should handle generics with type specifications',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<S,T> {
  T m1(S e);
  S m2(T e);
}
class _B<S> {
  @Delegate() A<S, int> _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B<S> implements A<S, int> {
  A<S, int> _a;
  S m2(int e) => _a.m2(e);
  int m1(S e) => _a.m1(e);
}
''');

  testTransformation(
      '@Delegate() should handle generics with bounds',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<S,T extends num> {
  T m1(S e);
  S m2(T e);
}
class _B<S> {
  @Delegate() A<S, int> _a;
}
class _C<T extends num> {
  @Delegate() A<String, T> _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B<S> implements A<S, int> {
  A<S, int> _a;
  S m2(int e) => _a.m2(e);
  int m1(S e) => _a.m1(e);
}
@GeneratedFrom(_C)
class C<T extends num> implements A<String, T> {
  A<String, T> _a;
  String m2(T e) => _a.m2(e);
  T m1(String e) => _a.m1(e);
}
''');

  testTransformation(
      '@Delegate() should handle generics not specified',
      r'''
import 'package:zengen/zengen.dart';
abstract class A<S,T extends int> {
  T m1(S e);
  S m2(T e);
}
class _B<S> {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B<S> implements A<dynamic, int> {
  A _a;
  dynamic m2(int e) => _a.m2(e);
  int m1(dynamic e) => _a.m1(e);
}
''',
      skip: true);

  testTransformation(
      '@Delegate() should handle operators',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  bool operator >(other);
  void operator []=(String key,value);
  operator [](key);
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic operator [](dynamic key) => _a[key];
  void operator []=(String key, dynamic value) { _a[key] = value; }
  bool operator >(dynamic other) => _a > other;
}
''');

  testTransformation(
      '@Delegate() should avoid setter',
      r'''
import 'package:zengen/zengen.dart';
class A {
  int a;
  get b => null;
  set c(String value) {}
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  set c(String value) { _a.c = value; }
  dynamic get b => _a.b;
  void set a(int _a) { this._a.a = _a; }
  int get a => _a.a;
}
''');

  testTransformation(
      '@Delegate() should prefix by this. when naming conflicts',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1(_a);
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m1(dynamic _a) => this._a.m1(_a);
}
''');

  testTransformation(
      '@Delegate() should add inherited members',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
}
abstract class M1 {
  m2();
}
abstract class M2 {
  m3();
}
abstract class I1 {
  m4();
}
abstract class I2<T> {
  T m5();
}
abstract class B extends A with M1, M2 implements I1, I2<int> {
  m6();
}
class _C {
  @Delegate() B b;
}
''',
      r'''
@GeneratedFrom(_C)
class C implements B {
  B b;
  dynamic m1() => b.m1();
  dynamic m3() => b.m3();
  dynamic m2() => b.m2();
  int m5() => b.m5();
  dynamic m4() => b.m4();
  dynamic m6() => b.m6();
}
''');

  testTransformation(
      '@Delegate() should not create private member',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
  _m2();
}
class _B {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m1() => _a.m1();
}
''');

  testTransformation(
      '@Delegate() should not add implements clause if already there',
      r'''
import 'package:zengen/zengen.dart';
abstract class A {
  m1();
  _m2();
}
class _B implements A {
  @Delegate() A _a;
}
''',
      r'''
@GeneratedFrom(_B)
class B implements A {
  A _a;
  dynamic m1() => _a.m1();
}
''');
}
