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

library zengen.lazy;

import 'src/transformation.dart';

main() {
  testTransformation(
      '@Lazy() should create a getter and a setter',
      r'''
class _A {
  @Lazy() var a = "String";
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  set a(dynamic v) => _lazyFields[#a] = v;
  dynamic get a => _lazyFields.putIfAbsent(#a, () => "String");
  final _lazyFields = <Symbol, dynamic>{};
}
''');

  testTransformation(
      '@Lazy() should create only a getter for final field',
      r'''
class _A {
  @Lazy() final a = "String";
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  dynamic get a => _lazyFields.putIfAbsent(#a, () => "String");
  final _lazyFields = <Symbol, dynamic>{};
}
''');

  testTransformation(
      '@Lazy() should handle types',
      r'''
class _A {
  @Lazy() String a = "String";
  @Lazy() List<int> l = [1, 2, 3];
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  set a(String v) => _lazyFields[#a] = v;
  String get a => _lazyFields.putIfAbsent(#a, () => "String");
  set l(List<int> v) => _lazyFields[#l] = v;
  List<int> get l => _lazyFields.putIfAbsent(#l, () => [1, 2, 3]);
  final _lazyFields = <Symbol, dynamic>{};
}
''');

  testTransformation(
      '@Lazy() should handle several variables on the same field declaration',
      r'''
class _A {
  @Lazy() String a = "1", b = "2";
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  String get a => _lazyFields.putIfAbsent(#a, () => "1");
  set a(String v) => _lazyFields[#a] = v;
  String get b => _lazyFields.putIfAbsent(#b, () => "2");
  set b(String v) => _lazyFields[#b] = v;
  final _lazyFields = <Symbol, dynamic>{};
}
''',
      skip: true);
}
