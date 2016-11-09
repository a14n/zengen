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

library zengen.default_constructor;

import 'src/transformation.dart';

main() {
  testTransformation('@DefaultConstructor() should create a constructor',
      r'''
class _A {
  @DefaultConstructor() external _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  A();
}
'''
      );

  testTransformation('@DefaultConstructor() should create a const constructor',
      r'''
class _A {
  @DefaultConstructor(useConst: true) external _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  const A();
}
'''
      );

  testTransformation(
      '@DefaultConstructor() should create a constructor if only final fields',
      r'''
class _A {
  final a, b;
  @DefaultConstructor() external _A();
}
class _B {
  var a;
  final b;
  @DefaultConstructor() external _B();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  final a, b;
  A(this.a, this.b);
}
@GeneratedFrom(_B)
class B {
  var a;
  final b;
  B(this.b, {this.a});
}
'''
      );

  testTransformation(
      '@DefaultConstructor() should not use final initialized fields',
      r'''
class _A {
  final a, b = 1;
  @DefaultConstructor() external _A();
}
''',
      r'''
@GeneratedFrom(_A)
class A {
  final a, b = 1;
  A(this.a);
}
'''
      );
}
