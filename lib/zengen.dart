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

library zengen;

export 'package:quiver/core.dart' show hashObjects;

const generated = null;

class ToString {
  final bool callSuper;
  final List<Symbol> exclude;
  final bool includePrivate;
  const ToString({this.callSuper, this.exclude, this.includePrivate});
}

class EqualsAndHashCode {
  final bool callSuper;
  final List<Symbol> exclude;
  final bool includePrivate;
  const EqualsAndHashCode({this.callSuper, this.exclude, this.includePrivate});
}

class Delegate {
  final List<Symbol> exclude;
  const Delegate({this.exclude});
}